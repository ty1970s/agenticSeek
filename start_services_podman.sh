#!/bin/bash

# Podman specific startup script for AgenticSeek
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Load environment variables first
if [ -f ".env" ]; then
    print_info "Loading environment variables from .env"
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
fi

# Get workspace directory size for mounting info
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    # Use different du options for macOS and Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        dir_size_bytes=$(du -sk "$WORK_DIR" | cut -f1)
        dir_size_bytes=$((dir_size_bytes * 1024))
    else
        dir_size_bytes=$(du -sb "$WORK_DIR" | cut -f1)
    fi
    print_info "Mounting $WORK_DIR ($dir_size_bytes bytes) to container."
else
    print_warning "WORK_DIR not set or directory doesn't exist, using current directory"
    WORK_DIR="$(pwd)"
fi

# Display deployment mode
if [ "$1" = "full" ]; then
    print_info "Starting full deployment with backend service in container..."
else
    print_info "Starting core deployment with frontend and search services only..."
    print_info "Use './start_services_podman.sh full' to start backend as well"
fi

# Check if Podman is installed
if ! command_exists podman; then
    print_error "Podman is not installed. Please install Podman first."
    echo "On macOS: brew install podman"
    echo "On Ubuntu: sudo apt install podman"
    echo "On RHEL/CentOS: sudo dnf install podman"
    exit 1
fi

# Check if Podman machine is running (macOS specific)
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_info "Checking Podman machine status..."
    if ! podman machine list 2>/dev/null | grep -q "Currently running"; then
        print_info "Starting Podman machine..."
        podman machine start || {
            print_error "Failed to start Podman machine"
            exit 1
        }
    else
        print_info "Podman machine is already running"
    fi
else
    # Check if Podman is accessible
    print_info "Checking Podman accessibility..."
    if ! podman info &> /dev/null; then
        print_error "Podman is not accessible or not running properly"
        print_info "Try running: podman system service --time=0 &"
        exit 1
    else
        print_info "Podman is accessible"
    fi
fi

# Check if podman-compose is available
if command_exists podman-compose; then
    COMPOSE_CMD="podman-compose"
    print_info "Using podman-compose"
elif command_exists docker-compose; then
    # Use docker-compose with podman backend
    # Try to use Podman machine socket on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Check if Podman machine is running and get socket path
        if podman machine list | grep -q "Currently running"; then
            PODMAN_SOCKET=$(podman machine inspect podman-machine-default --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)
            if [ -S "$PODMAN_SOCKET" ]; then
                export DOCKER_HOST="unix://$PODMAN_SOCKET"
                print_info "Using docker-compose with Podman backend via socket: $PODMAN_SOCKET"
            else
                print_warning "Podman socket not found at $PODMAN_SOCKET, trying alternative paths"
                # Try common socket locations
                for socket_path in "/tmp/podman-run-$(id -u)/podman/podman.sock" "/var/run/podman/podman.sock" "/run/podman/podman.sock"; do
                    if [ -S "$socket_path" ]; then
                        export DOCKER_HOST="unix://$socket_path"
                        print_info "Found Podman socket at: $socket_path"
                        break
                    fi
                done
                
                if [ -z "$DOCKER_HOST" ]; then
                    print_error "Could not find accessible Podman socket"
                    print_info "Available sockets:"
                    find /tmp /var/run /run -name "*podman*.sock" 2>/dev/null || true
                    exit 1
                fi
            fi
        else
            print_error "Podman machine is not running"
            exit 1
        fi
    else
        # Linux: use user socket
        export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
        print_info "Using docker-compose with Podman backend via user socket"
    fi
    COMPOSE_CMD="docker-compose"
else
    print_error "Neither podman-compose nor docker-compose is available"
    echo "Please install podman-compose or docker-compose"
    echo "On Ubuntu: sudo apt install podman-compose"
    echo "On macOS: brew install podman-compose"
    exit 1
fi

# Check if compose file exists
COMPOSE_FILE="podman-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    print_warning "$COMPOSE_FILE not found, using docker-compose.yml"
    COMPOSE_FILE="docker-compose.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "No compose file found"
        exit 1
    fi
fi

# Stop only the backend container if it's running to ensure a clean state
if podman ps --format '{{.Names}}' | grep -q '^backend$'; then
    print_info "New start: (re)starting backend container..."
    podman stop backend || true
    print_info "Backend container stopped"
fi

# Create network if it doesn't exist
if ! podman network exists agentic-seek-net 2>/dev/null; then
    print_info "Creating Podman network: agentic-seek-net"
    podman network create agentic-seek-net
fi

# Start services based on profile
if [ "$1" = "full" ]; then
    print_info "Starting full deployment with all services..."
    
    # Start with full profile
    if ! $COMPOSE_CMD -f "$COMPOSE_FILE" --profile full up -d; then
        print_error "Failed to start containers"
        exit 1
    fi
    
    # Wait for backend to be ready
    print_info "Waiting for backend to be ready..."
    for i in {1..30}; do
        if [ "$(podman inspect -f '{{.State.Running}}' backend 2>/dev/null)" = "true" ] && \
           [ "$(podman inspect -f '{{.State.Restarting}}' backend 2>/dev/null)" = "false" ]; then
            print_info "Backend container is running"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Backend container failed to start properly"
            $COMPOSE_CMD -f "$COMPOSE_FILE" logs backend
            exit 1
        fi
        sleep 2
    done
else
    print_info "Starting core services (frontend and search only)..."
    
    # Start with core profile
    if ! $COMPOSE_CMD -f "$COMPOSE_FILE" --profile core up -d; then
        print_error "Failed to start containers. Check logs with '$COMPOSE_CMD -f $COMPOSE_FILE logs'"
        exit 1
    fi
fi

# Wait for services to be ready
print_info "Waiting for services to be ready..."
sleep 5

# Check service status
print_info "Service status:"
$COMPOSE_CMD -f "$COMPOSE_FILE" ps

# Display access URLs
print_info "Services started successfully!"
echo ""
echo "Access URLs:"
echo "  Frontend: http://localhost:3000"
echo "  SearXNG: http://localhost:8081"
if [ "$1" = "full" ]; then
    echo "  Backend API: http://localhost:7777"
    echo "  API Health: http://localhost:7777/api/health"
fi
echo ""
echo "To view logs: $COMPOSE_CMD -f $COMPOSE_FILE logs -f [service_name]"
echo "To stop services: $COMPOSE_CMD -f $COMPOSE_FILE down"
