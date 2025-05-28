#!/bin/bash

# Wiggly Speech-to-Text Script for Wayland
# Uses whisper.cpp for transcription and wl-clipboard for clipboard integration

set -e

# Detect installation type and set paths accordingly
detect_installation_paths() {
    local script_path="$(readlink -f "$0")"
    local script_dir="$(dirname "$script_path")"
    
    # Check if we're running from a development/local directory
    if [ -f "$script_dir/wiggly-stt.conf" ] && [ -f "$script_dir/wiggly-stt-shared" ]; then
        # Local/development installation
        SCRIPT_DIR="$script_dir"
        INSTALL_TYPE="local"
    elif [ -f "/usr/share/wiggly-stt/wiggly-stt.conf" ]; then
        # System-wide installation
        SCRIPT_DIR="/usr/share/wiggly-stt"
        INSTALL_TYPE="system"
    elif [ -f "$HOME/.local/share/wiggly-stt/wiggly-stt.conf" ]; then
        # User-local installation
        SCRIPT_DIR="$HOME/.local/share/wiggly-stt"
        INSTALL_TYPE="user"
    else
        echo "Error: Cannot find Wiggly STT installation files"
        echo "Searched in:"
        echo "  - $script_dir (local)"
        echo "  - /usr/share/wiggly-stt (system)"
        echo "  - $HOME/.local/share/wiggly-stt (user)"
        exit 1
    fi
}

# Initialize paths
detect_installation_paths

# Set file paths
CONFIG_FILE="$SCRIPT_DIR/wiggly-stt.conf"
SHARED_FILE="$SCRIPT_DIR/wiggly-stt-shared"
DAEMON_FILE="$SCRIPT_DIR/wiggly-stt-daemon"

# Source configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Source shared functions
if [ -f "$SHARED_FILE" ]; then
    source "$SHARED_FILE"
else
    echo "Error: Shared functions file not found: $SHARED_FILE"
    exit 1
fi

# Function to check if server is running
is_server_running() {
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # Stale PID file
            rm -f "$SERVER_PID_FILE"
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

# Function to check if recording is active
is_recording_active() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Recording
        else
            # Stale PID file
            rm -f "$PID_FILE"
            return 1  # Not recording
        fi
    fi
    return 1  # Not recording
}

# Function to start recording
start_record() {
    local auto_paste="${1:-false}"
    
    if is_recording_active; then
        print_error "Recording already active (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    # Check if server is running and use appropriate method
    if is_server_running; then
        print_status "Starting recording with server mode..."
        print_status "Server available - transcription will be fast"
    else
        print_status "Starting recording with CLI mode..."
        print_status "No server running - will use whisper-cli for transcription"
    fi
    
    # Delegate to daemon script for recording
    if [ -f "$DAEMON_FILE" ]; then
        export WIGGLY_STT_INTERNAL=1
        export WIGGLY_STT_SCRIPT_DIR="$SCRIPT_DIR"  # Pass the script directory
        if [ "$auto_paste" = "true" ]; then
            exec "$DAEMON_FILE" --start -p
        else
            exec "$DAEMON_FILE" --start
        fi
    else
        print_error "Recording script not found: $DAEMON_FILE"
        exit 1
    fi
}

# Function to stop recording
stop_record() {
    local auto_paste="${1:-false}"
    
    if ! is_recording_active; then
        print_error "No recording active"
        return 1
    fi
    
    # Check if server is running to inform user about transcription method
    if is_server_running; then
        print_status "Stopping recording and transcribing via server..."
    else
        print_status "Stopping recording and transcribing via CLI..."
    fi
    
    # Delegate to daemon script for stopping
    if [ -f "$DAEMON_FILE" ]; then
        export WIGGLY_STT_INTERNAL=1
        export WIGGLY_STT_SCRIPT_DIR="$SCRIPT_DIR"  # Pass the script directory
        if [ "$auto_paste" = "true" ]; then
            exec "$DAEMON_FILE" --stop -p
        else
            exec "$DAEMON_FILE" --stop
        fi
    else
        print_error "Recording script not found: $DAEMON_FILE"
        exit 1
    fi
}

# Function to start whisper server
start_server() {
    if is_server_running; then
        print_warning "Server already running (PID: $(cat "$SERVER_PID_FILE"))"
        return 0
    fi
    
    # Send immediate notification and capture ID for replacement
    local server_notification_id
    send_notification_with_id server_notification_id "🎤 Wiggly STT Server" "Starting whisper server..." \
        "audio-input-microphone" "low" "30000"
    
    print_status "Starting whisper-server..."
    print_status "Loading model: $DEFAULT_MODEL"
    print_status "Server will be available on $SERVER_HOST:$SERVER_PORT"
    
    # Create server directory
    mkdir -p "$SERVER_DIR"
    
    # Start server in background
    whisper-server \
        -m "$MODEL_PATH/$DEFAULT_MODEL" \
        --host "$SERVER_HOST" \
        --port "$SERVER_PORT" \
        --no-timestamps \
        --threads "$SERVER_THREADS" \
        --convert > "$SERVER_LOG_FILE" 2>&1 &
    
    local server_pid=$!
    echo "$server_pid" > "$SERVER_PID_FILE"
    
    print_status "Server process started (PID: $server_pid), verifying startup..."
    
    # Wait a moment and check if server started
    sleep 2
    if is_server_running; then
        print_success "Server started successfully on $SERVER_HOST:$SERVER_PORT"
        print_status "Log file: $SERVER_LOG_FILE"
        
        # Replace the initial notification with completion notification
        replace_notification "$server_notification_id" "🎤 Wiggly STT Server" "Server ready on port $SERVER_PORT\nReady for fast transcription!" \
            "audio-input-microphone" "normal" "4000"
    else
        print_error "Failed to start server - check log file: $SERVER_LOG_FILE"
        
        # Replace the initial notification with failure notification
        replace_notification "$server_notification_id" "🎤 Wiggly STT Server" "Failed to start server\nCheck log: $SERVER_LOG_FILE" \
            "dialog-error" "critical" "5000"
        
        rm -f "$SERVER_PID_FILE"
        return 1
    fi
}

# Function to stop whisper server
stop_server() {
    if ! is_server_running; then
        print_warning "Server not running"
        return 0
    fi
    
    # Send immediate notification and capture ID for replacement
    local server_notification_id
    send_notification_with_id server_notification_id "🎤 Wiggly STT Server" "Stopping whisper server..." \
        "media-playback-stop" "low" "30000"
    
    local pid=$(cat "$SERVER_PID_FILE")
    print_status "Stopping whisper-server (PID: $pid)..."
    
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait for server to stop
    local count=0
    while is_server_running && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done
    
    if is_server_running; then
        print_warning "Server didn't stop gracefully, forcing termination..."
        kill -KILL "$pid" 2>/dev/null || true
        rm -f "$SERVER_PID_FILE"
    fi
    
    print_success "Server stopped"
    
    # Replace the initial notification with completion notification
    replace_notification "$server_notification_id" "🎤 Wiggly STT Server" "Server stopped successfully\nFast transcription disabled" \
        "media-playback-stop" "normal" "3000"
}

# Function to get unified status
get_status() {
    local recording_active=false
    local server_active=false
    
    # Check recording status
    if is_recording_active; then
        recording_active=true
    fi
    
    # Check server status
    if is_server_running; then
        server_active=true
    fi
    
    echo "=== Wiggly STT Status ==="
    echo
    
    # Determine and display current state
    if [ "$recording_active" = true ] && [ "$server_active" = true ]; then
        print_success "Status: Recording (using server mode)"
        local pid=$(cat "$PID_FILE")
        print_status "Recording PID: $pid"
        local server_pid=$(cat "$SERVER_PID_FILE")
        print_status "Server PID: $server_pid on $SERVER_HOST:$SERVER_PORT"
        print_status "Transcription will be fast (server keeps model loaded)"
        
    elif [ "$recording_active" = true ] && [ "$server_active" = false ]; then
        print_success "Status: Recording (using CLI mode)"
        local pid=$(cat "$PID_FILE")
        print_status "Recording PID: $pid"
        print_status "Transcription will use whisper-cli (slower)"
        
    elif [ "$recording_active" = false ] && [ "$server_active" = true ]; then
        print_status "Status: Stopped (server ready)"
        local server_pid=$(cat "$SERVER_PID_FILE")
        print_status "Server PID: $server_pid on $SERVER_HOST:$SERVER_PORT"
        print_status "Ready for fast recording sessions"
        
    else
        print_status "Status: Stopped"
        print_status "No recording or server active"
    fi
    
    echo
    
    # Show last transcription if available
    if [ -f "$DAEMON_DIR/last_transcription.txt" ]; then
        local transcription=$(cat "$DAEMON_DIR/last_transcription.txt")
        if [ -n "$transcription" ]; then
            print_status "Last transcription:"
            echo "  $transcription"
        fi
    fi
    
    # Show recent activity
    if [ "$recording_active" = true ] && [ -f "$LOG_FILE" ]; then
        echo
        print_status "Recent activity:"
        tail -3 "$LOG_FILE" | sed 's/^/  /'
    fi
}

# Function to show usage
usage() {
    cat << EOF
Wiggly Speech-to-Text Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    start-record             Start recording audio
    stop-record              Stop recording and transcribe
    start-server             Start whisper server for fast transcription
    stop-server              Stop whisper server
    status                   Show current status

Options:
    -m, --model MODEL        Whisper model to use (default: $DEFAULT_MODEL)
    -p, --auto-paste         Auto-paste transcribed text (with stop-record)
    -h, --help               Show this help message

Recording Modes:
    • If server is running: Uses server for fast transcription
    • If no server: Uses whisper-cli for transcription

Examples:
    # Basic recording
    $0 start-record          # Start recording
    $0 stop-record           # Stop and transcribe
    $0 stop-record -p        # Stop and auto-paste transcription
    
    # Server mode for faster transcription
    $0 start-server          # Start server (keeps model loaded)
    $0 start-record          # Record (will use server automatically)
    $0 stop-record -p        # Stop and auto-paste (fast transcription)
    $0 stop-server           # Stop server when done
    
    # Status checking
    $0 status                # Check current status

Dependencies:
    - whisper.cpp (https://github.com/ggerganov/whisper.cpp)
    - wl-clipboard (for Wayland clipboard)
    - ffmpeg (for audio recording)
    - curl (for server communication)
    - libnotify (for notifications)
    - ydotool (optional, for auto-paste functionality)

EOF
}

# Main function
main() {
    local model=$DEFAULT_MODEL
    local action=""
    local auto_paste_flag=false
    
    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--model)
                model="$2"
                DEFAULT_MODEL="$2"
                shift 2
                ;;
            -p|--auto-paste)
                auto_paste_flag=true
                AUTO_PASTE_FLAG=true
                shift
                ;;
            start-record)
                action="start-record"
                shift
                ;;
            stop-record)
                action="stop-record"
                shift
                ;;
            start-server)
                action="start-server"
                shift
                ;;
            stop-server)
                action="stop-server"
                shift
                ;;
            status)
                action="status"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate auto-paste flag usage
    if [ "$auto_paste_flag" = true ] && [ "$action" != "stop-record" ]; then
        print_error "Auto-paste (-p) can only be used with stop-record"
        usage
        exit 1
    fi
    
    # Require an action
    if [ -z "$action" ]; then
        print_error "No command specified"
        usage
        exit 1
    fi
    
    # Handle actions
    case $action in
        start-record)
            check_dependencies
            setup_model
            start_record "$auto_paste_flag"
            ;;
        stop-record)
            stop_record "$auto_paste_flag"
            ;;
        start-server)
            check_dependencies
            setup_model
            start_server
            ;;
        stop-server)
            stop_server
            ;;
        status)
            get_status
            ;;
        *)
            print_error "Unknown command: $action"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 