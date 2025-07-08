#!/bin/bash

# Podman installation script for AgenticSeek
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

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    print_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

print_info "Detected OS: $OS"

# Install Podman based on OS
install_podman() {
    case $OS in
        "macos")
            if command_exists brew; then
                print_info "Installing Podman using Homebrew..."
                brew install podman podman-compose
            else
                print_error "Homebrew not found. Please install Homebrew first."
                exit 1
            fi
            ;;
        "linux")
            if command_exists apt-get; then
                print_info "Installing Podman using apt..."
                sudo apt-get update
                sudo apt-get install -y podman podman-compose
            elif command_exists dnf; then
                print_info "Installing Podman using dnf..."
                sudo dnf install -y podman podman-compose
            elif command_exists yum; then
                print_info "Installing Podman using yum..."
                sudo yum install -y podman podman-compose
            else
                print_error "No supported package manager found"
                exit 1
            fi
            ;;
    esac
}

# Configure Podman
configure_podman() {
    print_info "Configuring Podman..."
    
    # Create config directory
    mkdir -p ~/.config/containers
    
    # Copy configuration file
    if [ -f "podman/containers.conf" ]; then
        cp podman/containers.conf ~/.config/containers/
        print_info "Copied Podman configuration"
    fi
    
    # For macOS, initialize and start Podman machine
    if [[ "$OS" == "macos" ]]; then
        print_info "Initializing Podman machine..."
        podman machine init --cpus 2 --memory 2048 --disk-size 10 || print_warning "Podman machine may already exist"
        podman machine start || print_warning "Podman machine may already be running"
    fi
    
    # For Linux, configure user namespaces
    if [[ "$OS" == "linux" ]]; then
        print_info "Configuring user namespaces..."
        
        # Check if user namespaces are configured
        if ! grep -q "^$(whoami):" /etc/subuid; then
            print_info "Adding user namespace mapping..."
            echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid
            echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid
        fi
        
        # Enable lingering for user services
        sudo loginctl enable-linger $(whoami)
    fi
}

# Install Python dependencies
install_python_deps() {
    print_info "Installing Python dependencies..."
    
    if [ -f "requirements.txt" ]; then
        if command_exists uv; then
            print_info "Using uv to install dependencies..."
            uv sync --python 3.10
        elif command_exists pip; then
            print_info "Using pip to install dependencies..."
            pip install -r requirements.txt
        else
            print_error "Neither uv nor pip found"
            exit 1
        fi
    else
        print_warning "requirements.txt not found"
    fi
}

# Setup environment file
setup_environment() {
    print_info "Setting up environment file..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.podman.example" ]; then
            cp .env.podman.example .env
            print_info "Created .env from .env.podman.example"
        elif [ -f ".env.example" ]; then
            cp .env.example .env
            print_info "Created .env from .env.example"
        else
            print_warning "No environment example file found"
        fi
    else
        print_info ".env file already exists"
    fi
}

# Main installation process
main() {
    print_info "Starting AgenticSeek Podman installation..."
    
    # Check if Podman is already installed
    if ! command_exists podman; then
        install_podman
    else
        print_info "Podman is already installed"
    fi
    
    # Configure Podman
    configure_podman
    
    # Install Python dependencies
    install_python_deps
    
    # Setup environment
    setup_environment
    
    # Verify installation
    print_info "Verifying installation..."
    podman --version
    
    if command_exists podman-compose; then
        podman-compose --version
    else
        print_warning "podman-compose not found, using docker-compose"
    fi
    
    print_info "Installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Edit .env file with your configuration"
    echo "2. Run: ./start_services_podman.sh"
    echo "3. Access frontend at: http://localhost:3000"
    echo ""
    echo "For full deployment: ./start_services_podman.sh full"
}

# Run main function
main "$@"
