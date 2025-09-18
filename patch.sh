#!/usr/bin/env bash
set -euo pipefail

# DockGuard Patch Script
# This script automates building, updating, and deploying the DockGuard application.
#
# Usage:
#   chmod +x patch.sh
#   ./patch.sh                    # Basic patch (build + icon generation)
#   ./patch.sh --clean            # Clean build
#   ./patch.sh --sign             # Include code signing
#   ./patch.sh --full             # Full patch (clean + build + icon + signing)
#   ./patch.sh --backup           # Backup existing app before patch
#   ./patch.sh --install          # Install to Applications folder after patch
#   ./patch.sh --debug            # Run in debug mode
#   ./patch.sh --help             # Show help

APP_NAME="DockGuard"
BUNDLE="$APP_NAME.app"
BACKUP_DIR="backups"
INSTALL_DIR="/Applications"
VERSION=$(date +"%Y%m%d_%H%M%S")

# Color output functions
print_header() {
    echo ""
    echo "🔧 =================================="
    echo "🔧 DockGuard Patch Script"
    echo "🔧 =================================="
    echo ""
}

print_step() {
    echo "📋 $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_warning() {
    echo "⚠️  $1"
}

# Show help
show_help() {
    cat << EOF
DockGuard Patch Script Usage:

Basic Commands:
  ./patch.sh                 Basic patch (build only)
  ./patch.sh --help          Show this help

Options:
  --clean                    Clean build after deleting previous build files
  --sign                     Apply temporary code signing to application
  --full                     Full patch (clean + build + signing)
  --backup                   Backup existing app before patch
  --install                  Install to /Applications after patch completion
  --restart                  Kill existing process and restart with new version
  --debug                    Run app in debug mode
  --test                     Run simple tests after build

Combination Examples:
  ./patch.sh --clean --sign --install --restart
  ./patch.sh --backup --full --install --restart
  ./patch.sh --clean --debug
  ./patch.sh --restart                        # Restart existing process only

EOF
}

# Create backup
create_backup() {
    if [ -d "$BUNDLE" ]; then
        print_step "Backing up existing app..."
        mkdir -p "$BACKUP_DIR"
        backup_name="${APP_NAME}_backup_${VERSION}.app"
        cp -r "$BUNDLE" "$BACKUP_DIR/$backup_name"
        print_success "Backup completed: $BACKUP_DIR/$backup_name"
    else
        print_warning "No app to backup."
    fi
}

# Kill running DockGuard processes
kill_existing_processes() {
    print_step "Checking for existing DockGuard processes..."
    
    # Use pkill to terminate DockGuard processes
    if pgrep -f "DockGuard" > /dev/null 2>&1; then
        print_warning "Terminating running DockGuard processes."
        pkill -f "DockGuard" || true
        sleep 2
        
        # Force kill if necessary
        if pgrep -f "DockGuard" > /dev/null 2>&1; then
            print_warning "Process did not terminate, forcing kill."
            pkill -9 -f "DockGuard" || true
            sleep 1
        fi
        
        print_success "Existing processes terminated"
    else
        print_success "No running DockGuard processes found."
    fi
}

# Prepare clean build
clean_build() {
    print_step "Cleaning previous build files..."
    rm -rf "$BUNDLE"
    rm -f *.o
    print_success "Cleanup completed"
}


# Main build
build_app() {
    print_step "Building application..."
    if [ -f "build.sh" ]; then
        chmod +x build.sh
        ./build.sh
        print_success "Build completed"
    else
        print_error "Cannot find build.sh script."
        exit 1
    fi
}

# Code signing
sign_app() {
    if command -v codesign >/dev/null 2>&1; then
        print_step "Signing application..."
        codesign --force --deep --sign - "$BUNDLE" || {
            print_warning "Code signing failed, continuing."
        }
        print_success "Signing completed"
    else
        print_warning "Cannot find codesign tool."
    fi
}

# Install application
install_app() {
    if [ -d "$BUNDLE" ]; then
        print_step "Installing application to $INSTALL_DIR..."
        if [ -d "$INSTALL_DIR/$BUNDLE" ]; then
            print_warning "Removing existing installed app."
            rm -rf "$INSTALL_DIR/$BUNDLE"
        fi
        cp -r "$BUNDLE" "$INSTALL_DIR/"
        print_success "Installation completed: $INSTALL_DIR/$BUNDLE"
    else
        print_error "Cannot find application to install."
        exit 1
    fi
}

# Restart application
restart_app() {
    local app_path=""
    
    # Check if installed app exists
    if [ -d "$INSTALL_DIR/$BUNDLE" ]; then
        app_path="$INSTALL_DIR/$BUNDLE"
    elif [ -d "$BUNDLE" ]; then
        app_path="$BUNDLE"
    else
        print_error "Cannot find application to restart."
        return 1
    fi
    
    print_step "Restarting DockGuard application..."
    
    # Run app in background
    nohup open "$app_path" > /dev/null 2>&1 &
    
    # Wait briefly and check execution
    sleep 3
    if pgrep -f "DockGuard" > /dev/null 2>&1; then
        print_success "DockGuard started successfully."
    else
        print_warning "Cannot verify DockGuard startup. Please check manually."
    fi
}

# Simple test
run_test() {
    if [ -d "$BUNDLE" ]; then
        print_step "Testing application..."
        
        # Check bundle structure
        if [ -f "$BUNDLE/Contents/MacOS/$APP_NAME" ]; then
            print_success "Executable file verified"
        else
            print_error "Cannot find executable file."
            return 1
        fi
        
        # Check Info.plist
        if [ -f "$BUNDLE/Contents/Info.plist" ]; then
            print_success "Info.plist verified"
        else
            print_error "Cannot find Info.plist."
            return 1
        fi
        
        # Check icon
        if [ -f "$BUNDLE/Contents/Resources/DockGuard.icns" ]; then
            print_success "Icon file verified"
        else
            print_warning "Icon file not found."
        fi
        
        print_success "All tests passed"
    else
        print_error "Cannot find application to test."
        exit 1
    fi
}

# Run in debug mode
debug_run() {
    if [ -d "$BUNDLE" ]; then
        print_step "Running application in debug mode..."
        print_warning "Press Ctrl+C to exit the application."
        "$BUNDLE/Contents/MacOS/$APP_NAME"
    else
        print_error "Cannot find application to run."
        exit 1
    fi
}

# Patch completion message
show_completion() {
    print_success "Patch completed!"
    echo ""
    echo "📱 How to run:"
    echo "   open '$BUNDLE'"
    echo ""
    if [ -f "display_debug.sh" ]; then
        echo "🔍 Debug tools:"
        echo "   ./display_debug.sh"
        echo ""
    fi
    echo "📂 Generated files:"
    echo "   $BUNDLE"
    if [ -d "$BACKUP_DIR" ]; then
        echo "   $BACKUP_DIR/ (backup)"
    fi
    echo ""
}

# Main execution logic
main() {
    print_header
    
    # Parse command line arguments
    CLEAN=false
    SIGN=false
    BACKUP=false
    INSTALL=false
    RESTART=false
    DEBUG=false
    FULL=false
    TEST=false
    
    # Apply build + restart by default if no arguments
    DEFAULT_RUN=false
    if [[ $# -eq 0 ]]; then
        RESTART=true
        DEFAULT_RUN=true
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN=true
                shift
                ;;
            --sign)
                SIGN=true
                shift
                ;;
            --backup)
                BACKUP=true
                shift
                ;;
            --install)
                INSTALL=true
                shift
                ;;
            --restart)
                RESTART=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --full)
                FULL=true
                CLEAN=true
                SIGN=true
                shift
                ;;
            --test)
                TEST=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    
    # Restart only case (explicitly using --restart only, excluding default run)
    if [ "$RESTART" = true ] && [ "$DEFAULT_RUN" = false ] && [ "$CLEAN" = false ] && [ "$SIGN" = false ] && [ "$INSTALL" = false ] && [ "$TEST" = false ] && [ "$BACKUP" = false ]; then
        kill_existing_processes
        restart_app
        exit 0
    fi
    
    # Debug mode case
    if [ "$DEBUG" = true ]; then
        debug_run
        exit 0
    fi
    
    # Kill existing processes (if restart requested)
    if [ "$RESTART" = true ]; then
        kill_existing_processes
    fi
    
    # Create backup
    if [ "$BACKUP" = true ]; then
        create_backup
    fi
    
    # Clean build
    if [ "$CLEAN" = true ]; then
        clean_build
    fi
    
    
    # Build application
    build_app
    
    # Code signing
    if [ "$SIGN" = true ]; then
        sign_app
    fi
    
    # Run tests
    if [ "$TEST" = true ]; then
        run_test
    fi
    
    # Install application
    if [ "$INSTALL" = true ]; then
        install_app
    fi
    
    # Restart application
    if [ "$RESTART" = true ]; then
        restart_app
    fi
    
    # Completion message
    show_completion
}

# Execute script
main "$@"