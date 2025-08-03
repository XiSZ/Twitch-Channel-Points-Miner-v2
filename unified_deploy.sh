#!/bin/sh
# Unified deployment and startup script for Twitch Channel Points Miner
# Combines functionality from deploy.sh and start_simple.sh
# This script pulls from repo and restarts the Python process

# Configuration defaults - can be overridden by .env file
REPO_PATH="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$HOME/logs/unified_deploy.log"
LOCK_FILE="$HOME/tmp/deploy.lock"
BRANCH="master"
SIMPLE_LOG="$HOME/logs/simple_startup.log"

# Set environment for compatibility
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PYTHONPATH="$HOME/.local/lib/python3.11/site-packages:$HOME/.local/lib/python3.10/site-packages:$HOME/.local/lib/python3.9/site-packages:$HOME/.local/lib/python3.8/site-packages:$PYTHONPATH"
export PYTHONUNBUFFERED=1

# Create directories if they don't exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "$(dirname "$LOCK_FILE")" 2>/dev/null
mkdir -p "$HOME/logs" 2>/dev/null

# Load environment variables from .env file if it exists
load_env_file() {
    if [ "$#" -gt 0 ]; then
        env_file="$1"
    else
        env_file=".env"
    fi
    
    if [ -f "$env_file" ]; then
        echo "Loading environment variables from $env_file"
        while IFS='=' read -r key value; do
            case "$key" in
                '#'*|'') continue ;;
            esac
            
            value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
            export "$key=$value"
        done < "$env_file"
    else
        echo "No .env file found at $env_file"
    fi
}

# Load .env file from script directory
load_env_file "$REPO_PATH/.env"

# Get configuration from environment variables
WEBHOOK_URL="${WEBHOOK:-}"
TELEGRAM_TOKEN="${TELEGRAMTOKEN:-}"
TELEGRAM_CHAT_ID="${CHATID:-}"

# Function to log with timestamp
log_message() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" | tee -a "$SIMPLE_LOG"
}

# Function to send webhook notification
send_webhook() {
    local message="$1"
    local status="$2"
    
    if [ -n "$WEBHOOK_URL" ]; then
        local color="#36a64f"  # Green for success
        local title="✅ Deployment Success"
        
        case "$status" in
            "error")
                color="#ff0000"
                title="❌ Deployment Error"
                ;;
            "warning")
                color="#ffaa00"
                title="⚠️ Deployment Warning"
                ;;
            "info")
                color="#0099ff"
                title="ℹ️ Deployment Info"
                ;;
            "start")
                color="#0099ff"
                title="🚀 Deployment Started"
                ;;
        esac
        
        if command -v curl >/dev/null 2>&1; then
            local payload="{
                \"username\": \"Deploy Bot\",
                \"embeds\": [{
                    \"title\": \"$title\",
                    \"description\": \"$message\",
                    \"color\": $(printf '%d' 0x${color#\#}),
                    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"
                }]
            }"
            
            curl -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_message "Webhook notification sent: $title"
            else
                log_message "Failed to send webhook notification"
            fi
        fi
    fi
}

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    local status="$2"
    
    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        local emoji="✅"
        case "$status" in
            "error") emoji="❌" ;;
            "warning") emoji="⚠️" ;;
            "info") emoji="ℹ️" ;;
            "start") emoji="🚀" ;;
        esac
        
        local formatted_message="$emoji *Twitch Miner Deploy*\n\n$message"
        
        if command -v curl >/dev/null 2>&1; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                -d "chat_id=$TELEGRAM_CHAT_ID" \
                -d "text=$formatted_message" \
                -d "parse_mode=Markdown" >/dev/null 2>&1
        fi
    fi
}

# Combined notification function
send_notification() {
    local message="$1"
    local status="$2"
    
    send_webhook "$message" "$status"
    send_telegram "$message" "$status"
}

# Function to find Python interpreter
find_python() {
    for py in python3.11 python3.10 python3.9 python3.8 python3 python; do
        if command -v "$py" >/dev/null 2>&1; then
            echo "$py"
            return 0
        fi
    done
    return 1
}

# Function to kill existing Python processes
kill_python_processes() {
    log_message "Stopping any existing Python processes..."
    
    for py in python3.11 python3.10 python3.9 python3.8 python3 python; do
        if command -v killall >/dev/null 2>&1; then
            killall "$py" 2>/dev/null
        elif command -v pkill >/dev/null 2>&1; then
            pkill -f "$py" 2>/dev/null
        fi
        
        # Also try pgrep/kill combination
        if command -v pgrep >/dev/null 2>&1; then
            PIDS=$(pgrep -f "$py" 2>/dev/null)
            if [ -n "$PIDS" ]; then
                for pid in $PIDS; do
                    kill "$pid" 2>/dev/null
                    log_message "Killed Python process: $pid"
                done
            fi
        fi
    done
    
    sleep 2
    log_message "Python process cleanup completed"
}

# Function to check if we're in a git repository and pull updates
update_repository() {
    log_message "Checking for repository updates..."
    
    # Change to repository directory
    cd "$REPO_PATH" || {
        log_message "ERROR: Failed to change to repository directory: $REPO_PATH"
        return 1
    }
    
    # Check if this is a git repository
    if [ ! -d ".git" ]; then
        log_message "INFO: Not a git repository, skipping update"
        return 0
    fi
    
    # Fetch latest changes
    log_message "Fetching latest changes from origin/$BRANCH..."
    FETCH_OUTPUT=$(git fetch origin "$BRANCH" 2>&1)
    FETCH_EXIT_CODE=$?
    
    if [ $FETCH_EXIT_CODE -ne 0 ]; then
        log_message "WARNING: Git fetch failed: $FETCH_OUTPUT"
        return 1
    fi
    
    # Check if there are updates available
    LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null)
    REMOTE_COMMIT=$(git rev-parse "origin/$BRANCH" 2>/dev/null)
    
    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
        log_message "Repository is already up to date"
        return 0
    fi
    
    log_message "Updates available. Pulling changes..."
    PULL_OUTPUT=$(git pull origin "$BRANCH" 2>&1)
    PULL_EXIT_CODE=$?
    
    if [ $PULL_EXIT_CODE -eq 0 ]; then
        log_message "✅ Successfully updated repository"
        log_message "Changes: $PULL_OUTPUT"
        send_notification "Repository updated successfully\n\nChanges: $PULL_OUTPUT" "info"
        return 0
    else
        log_message "❌ Failed to update repository: $PULL_OUTPUT"
        send_notification "Failed to update repository\n\nError: $PULL_OUTPUT" "error"
        return 1
    fi
}

# Function to start localRunner.py with multiple methods
start_localrunner() {
    log_message "Starting localRunner.py..."
    
    # Check if localRunner.py exists
    if [ ! -f "localRunner.py" ]; then
        log_message "ERROR: localRunner.py not found in $REPO_PATH"
        return 1
    fi
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        log_message "ERROR: .env file not found"
        return 1
    fi
    
    # Find Python interpreter
    PYTHON_CMD=$(find_python)
    if [ -z "$PYTHON_CMD" ]; then
        log_message "ERROR: No Python interpreter found"
        return 1
    fi
    
    log_message "Using Python interpreter: $PYTHON_CMD"
    
    # Try to install python-dotenv if missing
    if ! "$PYTHON_CMD" -c "import dotenv" 2>/dev/null; then
        log_message "Installing python-dotenv..."
        "$PYTHON_CMD" -m pip install --user python-dotenv >> "$LOG_FILE" 2>&1
    fi
    
    # Set up log file for localRunner
    LOCAL_LOG="$HOME/logs/localRunner.log"
    
    # Try different startup methods
    START_SUCCESS=0
    
    # Method 1: nohup
    log_message "Method 1: Trying with nohup..."
    nohup "$PYTHON_CMD" localRunner.py > "$LOCAL_LOG" 2>&1 &
    PID1=$!
    sleep 3
    
    if kill -0 "$PID1" 2>/dev/null; then
        log_message "✓ SUCCESS: Process started with nohup (PID: $PID1)"
        START_SUCCESS=1
        
        # Show first few lines of log for verification
        if [ -f "$LOCAL_LOG" ]; then
            log_message "First few lines of localRunner log:"
            head -5 "$LOCAL_LOG" 2>/dev/null | while read -r line; do
                log_message "  $line"
            done
        fi
        
        send_notification "localRunner.py started successfully\n\nPID: $PID1\nMethod: nohup\nLog: $LOCAL_LOG" "success"
        return 0
    else
        log_message "✗ Method 1 failed"
        
        # Method 2: Direct background
        log_message "Method 2: Trying direct background..."
        "$PYTHON_CMD" localRunner.py > "$LOCAL_LOG" 2>&1 &
        PID2=$!
        sleep 3
        
        if kill -0 "$PID2" 2>/dev/null; then
            log_message "✓ SUCCESS: Process started directly (PID: $PID2)"
            START_SUCCESS=1
            send_notification "localRunner.py started successfully\n\nPID: $PID2\nMethod: direct background\nLog: $LOCAL_LOG" "success"
            return 0
        else
            log_message "✗ Method 2 failed"
            
            # Method 3: Screen (if available)
            if command -v screen >/dev/null 2>&1; then
                log_message "Method 3: Trying with screen..."
                screen -dmS miner_session "$PYTHON_CMD" localRunner.py
                sleep 3
                
                if screen -list | grep -q miner_session; then
                    log_message "✓ SUCCESS: Process started with screen"
                    START_SUCCESS=1
                    send_notification "localRunner.py started successfully\n\nMethod: screen session 'miner_session'\nLog: Check screen session" "success"
                    return 0
                else
                    log_message "✗ Method 3 failed"
                fi
            fi
        fi
    fi
    
    if [ $START_SUCCESS -eq 0 ]; then
        log_message "ERROR: All startup methods failed"
        
        # Show error details
        if [ -f "$LOCAL_LOG" ]; then
            log_message "Error log contents:"
            tail -10 "$LOCAL_LOG" 2>/dev/null | while read -r line; do
                log_message "  $line"
            done
        fi
        
        send_notification "Failed to start localRunner.py\n\nAll startup methods failed\nCheck logs for details" "error"
        return 1
    fi
}

# Function to check if script is already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
            log_message "Script is already running (PID: $LOCK_PID)"
            exit 1
        else
            log_message "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    # Create lock file
    echo $$ > "$LOCK_FILE"
}

# Function to cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    log_message "=== Unified Deploy & Restart Script Started ==="
    log_message "Working directory: $REPO_PATH"
    log_message "Log file: $LOG_FILE"
    
    # Check for running instance
    check_lock
    
    # Send start notification
    send_notification "Deployment and restart process started on $(hostname)" "start"
    
    # Kill existing Python processes
    kill_python_processes
    
    # Update repository if it's a git repo
    UPDATE_SUCCESS=1
    if update_repository; then
        log_message "Repository update completed successfully"
    else
        log_message "Repository update failed or skipped"
        UPDATE_SUCCESS=0
    fi
    
    # Always try to start localRunner regardless of update status
    log_message "Proceeding to start localRunner.py..."
    
    if start_localrunner; then
        SUCCESS_MSG="✅ **Deployment & Restart Completed Successfully**

• Repository: $(basename "$REPO_PATH")
• Update Status: $([ $UPDATE_SUCCESS -eq 1 ] && echo "Success" || echo "Skipped/Failed")
• Process: localRunner.py started
• Working Directory: $REPO_PATH
• Logs: $LOG_FILE"

        log_message "$SUCCESS_MSG"
        send_notification "$SUCCESS_MSG" "success"
        log_message "=== Script completed successfully ==="
        exit 0
    else
        ERROR_MSG="❌ **Deployment Failed**

• Repository: $(basename "$REPO_PATH") 
• Update Status: $([ $UPDATE_SUCCESS -eq 1 ] && echo "Success" || echo "Failed")
• Process: Failed to start localRunner.py
• Check logs for details: $LOG_FILE"

        log_message "$ERROR_MSG"
        send_notification "$ERROR_MSG" "error"
        log_message "=== Script completed with errors ==="
        exit 1
    fi
}

# Run main function
main "$@"
