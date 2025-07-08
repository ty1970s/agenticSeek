#!/bin/bash

# Monitoring script for AgenticSeek Podman deployment
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_title() {
    echo -e "${BLUE}[MONITOR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Show system resources
show_system_resources() {
    print_title "System Resources"
    echo "CPU Usage:"
    if command_exists htop; then
        htop -n 1 | head -5
    else
        top -n 1 | head -5
    fi
    
    echo ""
    echo "Memory Usage:"
    free -h
    
    echo ""
    echo "Disk Usage:"
    df -h /
}

# Show Podman system info
show_podman_info() {
    print_title "Podman System Information"
    podman info | grep -E "(Version|OCI Runtime|Cgroup|Storage Driver|Root Dir)"
}

# Show container statistics
show_container_stats() {
    print_title "Container Statistics"
    if podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "backend\|frontend\|searxng\|redis"; then
        podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    else
        print_warning "No AgenticSeek containers are running"
    fi
}

# Show network information
show_network_info() {
    print_title "Network Information"
    podman network ls
    
    if podman network exists agentic-seek-net; then
        echo ""
        echo "Network Details:"
        podman network inspect agentic-seek-net | jq -r '.[] | {name: .name, driver: .driver, subnets: .subnets}'
    fi
}

# Show volume information
show_volume_info() {
    print_title "Volume Information"
    podman volume ls
    
    if podman volume exists redis-data; then
        echo ""
        echo "Redis Data Volume:"
        podman volume inspect redis-data | jq -r '.[] | {name: .Name, mountpoint: .Mountpoint, driver: .Driver}'
    fi
}

# Show service logs
show_service_logs() {
    local service=$1
    local lines=${2:-20}
    
    print_title "Last $lines lines of $service logs"
    if podman ps | grep -q "$service"; then
        podman logs --tail $lines "$service"
    else
        print_warning "Container $service is not running"
    fi
}

# Show all container logs
show_all_logs() {
    local lines=${1:-20}
    
    for container in backend frontend searxng redis; do
        if podman ps | grep -q "$container"; then
            show_service_logs "$container" "$lines"
            echo ""
        fi
    done
}

# Monitor in real-time
monitor_realtime() {
    print_title "Real-time monitoring (Press Ctrl+C to exit)"
    
    while true; do
        clear
        echo "$(date)"
        echo "========================================"
        
        show_container_stats
        echo ""
        
        # Show recent logs
        print_title "Recent Activity"
        podman logs --tail 5 --since 1m backend 2>/dev/null || true
        
        sleep 5
    done
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  info        Show system and Podman information"
    echo "  stats       Show container statistics"
    echo "  network     Show network information"
    echo "  volumes     Show volume information"
    echo "  logs        Show service logs"
    echo "  monitor     Start real-time monitoring"
    echo "  all         Show all information (default)"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -l, --lines N   Number of log lines to show (default: 20)"
    echo "  -s, --service   Specific service to monitor"
}

# Parse command line arguments
LINES=20
SERVICE=""
COMMAND="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -l|--lines)
            LINES="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        info|stats|network|volumes|logs|monitor|all)
            COMMAND="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main function
main() {
    # Check if Podman is available
    if ! command_exists podman; then
        print_error "Podman is not installed or not in PATH"
        exit 1
    fi
    
    case $COMMAND in
        info)
            show_system_resources
            echo ""
            show_podman_info
            ;;
        stats)
            show_container_stats
            ;;
        network)
            show_network_info
            ;;
        volumes)
            show_volume_info
            ;;
        logs)
            if [ -n "$SERVICE" ]; then
                show_service_logs "$SERVICE" "$LINES"
            else
                show_all_logs "$LINES"
            fi
            ;;
        monitor)
            monitor_realtime
            ;;
        all)
            show_system_resources
            echo ""
            show_podman_info
            echo ""
            show_container_stats
            echo ""
            show_network_info
            echo ""
            show_volume_info
            echo ""
            show_all_logs "$LINES"
            ;;
    esac
}

# Run main function
main "$@"
