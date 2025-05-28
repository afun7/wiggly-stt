#!/bin/bash

# Wiggly STT Installation Script
# Supports local, user, and system-wide installations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Wiggly STT Installation Script

Usage: $0 [OPTIONS]

Installation Types:
  --local         Install in current directory (development mode)
  --user          Install for current user (~/.local/)
  --system        Install system-wide (requires sudo)
  --uninstall     Remove installation

Options:
  -h, --help      Show this help message
  --dry-run       Show what would be installed without doing it

Examples:
  $0 --user       # Install for current user
  $0 --system     # Install system-wide
  $0 --local      # Keep in current directory
  $0 --uninstall --user  # Remove user installation
EOF
}

check_dependencies() {
    local missing_deps=()
    
    # Required dependencies
    for dep in ffmpeg wl-copy wl-paste notify-send curl; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install them using your package manager:"
        print_info "  Arch: sudo pacman -S ffmpeg wl-clipboard libnotify curl"
        print_info "  Ubuntu: sudo apt install ffmpeg wl-clipboard libnotify-bin curl"
        exit 1
    fi
    
    # Optional dependencies
    local missing_optional=()
    for dep in ydotool whisper-cli whisper-server; do
        if ! command -v "$dep" &> /dev/null; then
            missing_optional+=("$dep")
        fi
    done
    
    if [ ${#missing_optional[@]} -gt 0 ]; then
        print_warning "Optional dependencies not found: ${missing_optional[*]}"
        print_info "For full functionality, consider installing:"
        print_info "  - ydotool: for auto-paste functionality"
        print_info "  - whisper.cpp: for local AI transcription"
    fi
}

install_local() {
    print_info "Setting up local installation..."
    
    # Make scripts executable
    chmod +x wiggly-stt.sh wiggly-stt-daemon
    
    # Create symlink for easier access (optional)
    if [ ! -L "wiggly-stt" ]; then
        ln -s wiggly-stt.sh wiggly-stt
        print_success "Created symlink: wiggly-stt -> wiggly-stt.sh"
    fi
    
    print_success "Local installation complete!"
    print_info "You can now run: ./wiggly-stt.sh or ./wiggly-stt"
}

install_user() {
    print_info "Installing for current user..."
    
    local bin_dir="$HOME/.local/bin"
    local share_dir="$HOME/.local/share/wiggly-stt"
    
    # Create directories
    mkdir -p "$bin_dir" "$share_dir"
    
    # Install files
    cp wiggly-stt.sh "$bin_dir/wiggly-stt"
    cp wiggly-stt-daemon "$share_dir/"
    cp wiggly-stt-shared "$share_dir/"
    cp wiggly-stt.conf "$share_dir/"
    
    # Make executable
    chmod +x "$bin_dir/wiggly-stt" "$share_dir/wiggly-stt-daemon"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        print_warning "~/.local/bin is not in your PATH"
        print_info "Add this to your ~/.bashrc or ~/.zshrc:"
        print_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    print_success "User installation complete!"
    print_info "You can now run: wiggly-stt"
}

install_system() {
    print_info "Installing system-wide (requires sudo)..."
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        print_error "System installation requires sudo privileges"
        print_info "Run: sudo $0 --system"
        exit 1
    fi
    
    local bin_dir="/usr/bin"
    local share_dir="/usr/share/wiggly-stt"
    
    # Create directories
    mkdir -p "$share_dir"
    
    # Install files
    cp wiggly-stt.sh "$bin_dir/wiggly-stt"
    cp wiggly-stt-daemon "$share_dir/"
    cp wiggly-stt-shared "$share_dir/"
    cp wiggly-stt.conf "$share_dir/"
    
    # Make executable
    chmod +x "$bin_dir/wiggly-stt" "$share_dir/wiggly-stt-daemon"
    
    # Install documentation
    mkdir -p "/usr/share/doc/wiggly-stt"
    cp README.md "/usr/share/doc/wiggly-stt/"
    
    print_success "System installation complete!"
    print_info "You can now run: wiggly-stt"
}

uninstall() {
    local install_type="$1"
    
    case "$install_type" in
        "local")
            print_info "Removing local installation..."
            rm -f wiggly-stt
            print_success "Local installation removed"
            ;;
        "user")
            print_info "Removing user installation..."
            rm -f "$HOME/.local/bin/wiggly-stt"
            rm -rf "$HOME/.local/share/wiggly-stt"
            print_success "User installation removed"
            ;;
        "system")
            if [ "$EUID" -ne 0 ]; then
                print_error "System uninstall requires sudo privileges"
                print_info "Run: sudo $0 --uninstall --system"
                exit 1
            fi
            print_info "Removing system installation..."
            rm -f "/usr/bin/wiggly-stt"
            rm -rf "/usr/share/wiggly-stt"
            rm -rf "/usr/share/doc/wiggly-stt"
            print_success "System installation removed"
            ;;
        *)
            print_error "Please specify installation type: --local, --user, or --system"
            exit 1
            ;;
    esac
}

# Parse command line arguments
INSTALL_TYPE=""
UNINSTALL=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            INSTALL_TYPE="local"
            shift
            ;;
        --user)
            INSTALL_TYPE="user"
            shift
            ;;
        --system)
            INSTALL_TYPE="system"
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main installation logic
if [ "$UNINSTALL" = true ]; then
    if [ -z "$INSTALL_TYPE" ]; then
        print_error "Please specify installation type to uninstall"
        show_usage
        exit 1
    fi
    uninstall "$INSTALL_TYPE"
    exit 0
fi

if [ -z "$INSTALL_TYPE" ]; then
    print_error "Please specify installation type"
    show_usage
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN - would perform $INSTALL_TYPE installation"
    exit 0
fi

# Check dependencies before installation
check_dependencies

# Perform installation
case "$INSTALL_TYPE" in
    "local")
        install_local
        ;;
    "user")
        install_user
        ;;
    "system")
        install_system
        ;;
    *)
        print_error "Invalid installation type: $INSTALL_TYPE"
        exit 1
        ;;
esac 