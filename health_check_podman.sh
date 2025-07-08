#!/bin/bash

# Health check script for AgenticSeek Podman deployment
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

# Check if URL is accessible
check_url() {
    local url=$1
    local service=$2
    if curl -s -f "$url" > /dev/null 2>&1; then
        print_info "$service is healthy at $url"
        return 0
    else
        print_error "$service is not accessible at $url"
        return 1
    fi
}

# Check container status
check_container() {
    local container=$1
    if podman ps | grep -q "$container"; then
        print_info "Container $container is running"
        return 0
    else
        print_error "Container $container is not running"
        return 1
    fi
}

# Main health check
main() {
    print_info "Starting AgenticSeek health check..."
    
    # Check if Podman is accessible
    if ! command_exists podman; then
        print_error "Podman is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Podman is running
    if ! podman info > /dev/null 2>&1; then
        print_error "Podman is not running or accessible"
        exit 1
    fi
    
    # Check container status
    local all_healthy=true
    
    # Check core containers
    if ! check_container "redis"; then
        all_healthy=false
    fi
    
    if ! check_container "searxng"; then
        all_healthy=false
    fi
    
    if ! check_container "frontend"; then
        all_healthy=false
    fi
    
    # Check backend container if running in full mode
    if podman ps | grep -q "backend"; then
        if ! check_container "backend"; then
            all_healthy=false
        fi
    fi
    
    # Check service endpoints
    print_info "Checking service endpoints..."
    
    # Check frontend
    if ! check_url "http://localhost:3080" "Frontend"; then
        all_healthy=false
    fi
    
    # Check SearXNG
    if ! check_url "http://localhost:8081" "SearXNG"; then
        all_healthy=false
    fi
    
    # Check backend if running
    if podman ps | grep -q "backend"; then
        if ! check_url "http://localhost:7777/api/health" "Backend API"; then
            all_healthy=false
        fi
    fi
    
    # Check network connectivity
    print_info "Checking network connectivity..."
    if podman network exists agentic-seek-net; then
        print_info "Network agentic-seek-net exists"
    else
        print_error "Network agentic-seek-net does not exist"
        all_healthy=false
    fi
    
    # Check volumes
    print_info "Checking volumes..."
    if podman volume exists redis-data; then
        print_info "Volume redis-data exists"
    else
        print_warning "Volume redis-data does not exist"
    fi
    
    # Final status
    if [ "$all_healthy" = true ]; then
        print_info "All services are healthy!"
        exit 0
    else
        print_error "Some services are not healthy"
        exit 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Verbose output"
    echo "  -q, --quiet    Quiet output (only errors)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -q|--quiet)
            exec 2>/dev/null
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
