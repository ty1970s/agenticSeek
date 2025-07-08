#!/bin/bash

# Stop AgenticSeek services running with Podman
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Function to get Podman socket path
get_podman_socket() {
    # Check if podman machine is running
    if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
        print_warning "Podman machine is not running. Starting it..."
        podman machine start
        sleep 5
    fi
    
    # Try to find the correct socket path
    local socket_paths=(
        "/run/user/$(id -u)/podman/podman.sock"
        "$HOME/.local/share/containers/podman/machine/podman.sock"
        "/var/folders/*/T/podman/podman-machine-default-api.sock"
    )
    
    for socket_path in "${socket_paths[@]}"; do
        # Handle wildcard expansion for /var/folders
        if [[ "$socket_path" == *"*"* ]]; then
            for expanded_path in $socket_path; do
                if [ -S "$expanded_path" ]; then
                    echo "$expanded_path"
                    return 0
                fi
            done
        elif [ -S "$socket_path" ]; then
            echo "$socket_path"
            return 0
        fi
    done
    
    # If no socket found, try to get it from podman system connection
    local connection_socket=$(podman system connection list --format "{{.URI}}" | head -1 | sed 's/unix://')
    if [ -S "$connection_socket" ]; then
        echo "$connection_socket"
        return 0
    fi
    
    print_error "Could not find Podman socket"
    return 1
}

# Check if podman-compose is available
if command_exists podman-compose; then
    COMPOSE_CMD="podman-compose"
elif command_exists docker-compose; then
    PODMAN_SOCKET=$(get_podman_socket)
    if [ $? -eq 0 ]; then
        export DOCKER_HOST="unix://$PODMAN_SOCKET"
        print_info "Using Docker-compose with Podman socket: $PODMAN_SOCKET"
        COMPOSE_CMD="docker-compose"
    else
        print_error "Could not configure Docker-compose with Podman"
        exit 1
    fi
else
    print_error "Neither podman-compose nor docker-compose is available"
    exit 1
fi

# Check if compose file exists
COMPOSE_FILE="podman-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    print_warning "$COMPOSE_FILE not found, using docker-compose.yml"
    COMPOSE_FILE="docker-compose.yml"
fi

# Stop services
print_info "Stopping AgenticSeek services..."
$COMPOSE_CMD -f "$COMPOSE_FILE" down

# Clean up containers
print_info "Cleaning up stopped containers..."
podman container prune -f

# Clean up images if requested
if [ "$1" = "--clean-images" ]; then
    print_info "Removing unused images..."
    podman image prune -f
fi

# Clean up volumes if requested
if [ "$1" = "--clean-all" ]; then
    print_warning "Removing all volumes and data..."
    podman volume prune -f
fi

print_info "Services stopped successfully!"

# Show remaining containers
if [ "$(podman ps -q)" ]; then
    print_info "Remaining running containers:"
    podman ps
else
    print_info "No containers are running"
fi
