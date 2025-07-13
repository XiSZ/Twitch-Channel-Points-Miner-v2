#!/bin/sh

# FreeBSD/Serv00 compatible deployment script
# Uses POSIX shell features for maximum compatibility

# Configuration defaults - can be overridden by .env file
REPO_PATH="repo/git/pub/TTV/"
LOG_FILE="repo/git/pub/TTV/deploy.log"
LOCK_FILE="$HOME/tmp/deploy.lock"
BRANCH="master"

# Load environment variables from .env file if it exists
load_env_file() {
    # Use first parameter if provided, otherwise default to .env
    if [ "$#" -gt 0 ]; then
        env_file="$1"
    else
        env_file=".env"
    fi
    
    if [ -f "$env_file" ]; then
        echo "Loading environment variables from $env_file"
        # Read .env file and export variables (skip comments and empty lines)
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            case "$key" in
                '#'*|'') continue ;;
            esac
            
            # Remove quotes from value if present
            value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
            
            # Export the variable
            export "$key=$value"
        done < "$env_file"
    else
        echo "No .env file found at $env_file"
    fi
}

# Load .env file from script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
load_env_file "$SCRIPT_DIR/.env"

# Get webhook URL from environment variable (now potentially loaded from .env)
WEBHOOK_URL="${WEBHOOK:-}"

# Telegram configuration (can be overridden in .env)
TELEGRAM_TOKEN="${TELEGRAMTOKEN:-}"
TELEGRAM_CHAT_ID="${CHATID:-}"

# Email configuration (can be overridden in .env)
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-your-email@example.com}"
SEND_EMAIL_ON_ERROR="${SEND_EMAIL_ON_ERROR:-true}"
SEND_EMAIL_ON_SUCCESS="${SEND_EMAIL_ON_SUCCESS:-false}"

# Notification configuration (can be overridden in .env)
SEND_WEBHOOK_NOTIFICATIONS="${SEND_WEBHOOK_NOTIFICATIONS:-true}"
SEND_TELEGRAM_NOTIFICATIONS="${SEND_TELEGRAM_NOTIFICATIONS:-true}"

# Allow overriding paths from .env
REPO_PATH="${REPO_PATH:-repo/git/pub/TTV/}"
LOG_FILE="${LOG_FILE:-repo/git/pub/TTV/deploy.log}"
BRANCH="${BRANCH:-master}"

# Convert relative paths to absolute paths to avoid issues
if [ "${REPO_PATH#/}" = "$REPO_PATH" ]; then
    REPO_PATH="$HOME/$REPO_PATH"
fi
if [ "${LOG_FILE#/}" = "$LOG_FILE" ]; then
    LOG_FILE="$HOME/$LOG_FILE"
fi

echo "Using REPO_PATH: $REPO_PATH"
echo "Using LOG_FILE: $LOG_FILE"

# Create directories if they don't exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$LOCK_FILE")"

# Function to log with timestamp
log_message() {
    # Ensure log directory exists before writing
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send email notification (FreeBSD compatible)
send_email() {
    local subject="$1"
    local message="$2"
    
    if [ "$SEND_EMAIL_ON_ERROR" = "true" ] || [ "$SEND_EMAIL_ON_SUCCESS" = "true" ]; then
        # Use printf instead of echo for better compatibility
        printf "%s\n" "$message" | mail -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "Email notification sent: $subject"
        else
            log_message "Failed to send email notification"
        fi
    fi
}

# Function to send webhook notification
send_webhook() {
    local message="$1"
    local status="$2"
    
    if [ "$SEND_WEBHOOK_NOTIFICATIONS" = "true" ] && [ -n "$WEBHOOK_URL" ]; then
        local color="#36a64f"  # Green for success
        local title="✅ Deployment Success"
        
        case "$status" in
            "error")
                color="#ff0000"  # Red for error
                title="❌ Deployment Error"
                ;;
            "warning")
                color="#ffaa00"  # Orange for warning
                title="⚠️ Deployment Warning"
                ;;
            "info")
                color="#0099ff"  # Blue for info
                title="ℹ️ Deployment Info"
                ;;
            "start")
                color="#0099ff"  # Blue for start
                title="🚀 Deployment Started"
                ;;
            *)
                title="✅ Deployment Success"
                ;;
        esac
        
        # Use curl if available, otherwise use fetch
        if command -v curl >/dev/null 2>&1; then
            # Discord webhook payload with embeds for better formatting
            local payload="{
                \"username\": \"Deploy Bot\",
                \"avatar_url\": \"https://avatars.githubusercontent.com/u/40718990\",
                \"embeds\": [{
                    \"title\": \"$title\",
                    \"description\": \"$message\",
                    \"color\": \"$(printf '%d' 0x${color#\#})\",
                    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
                    \"footer\": {
                        \"text\": \"Twitch Channel Points Miner\",
                        \"icon_url\": \"https://static-cdn.jtvnw.net/ttv-boxart/509658-285x380.jpg\"
                    },
                    \"fields\": [
                        {
                            \"name\": \"Server\",
                            \"value\": \"$(hostname)\",
                            \"inline\": true
                        },
                        {
                            \"name\": \"Repository\",
                            \"value\": \"$REPO_PATH\",
                            \"inline\": true
                        }
                    ]
                }]
            }"
            
            curl -X POST -H 'Content-type: application/json' \
                -d "$payload" \
                "$WEBHOOK_URL" \
                --connect-timeout 10 \
                --max-time 30 \
                --silent --output /dev/null
        elif command -v fetch >/dev/null 2>&1; then
            # FreeBSD's native fetch command with simpler payload
            local temp_file="$HOME/tmp/webhook_payload_$$"
            mkdir -p "$HOME/tmp" 2>/dev/null
            
            local simple_payload="{
                \"username\": \"$(hostname) Deploy Bot\",
                \"content\": \"$title\\n**$message**\\n\\nServer: \`$(hostname)\`\\nRepo: \`$REPO_PATH\`\"
            }"
            
            printf '%s\n' "$simple_payload" > "$temp_file"
            fetch -q -o /dev/null -T 30 \
                --method=POST \
                --header="Content-Type: application/json" \
                --upload-file="$temp_file" \
                "$WEBHOOK_URL" 2>/dev/null
            rm -f "$temp_file"
        fi
        
        if [ $? -eq 0 ]; then
            log_message "Discord notification sent: $title"
        else
            log_message "Failed to send Discord notification"
        fi
    fi
}

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    local status="$2"
    
    if [ "$SEND_TELEGRAM_NOTIFICATIONS" = "true" ] && [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        local emoji="✅"
        local status_text="Success"
        
        case "$status" in
            "error")
                emoji="❌"
                status_text="Error"
                ;;
            "warning")
                emoji="⚠️"
                status_text="Warning"
                ;;
            "info")
                emoji="ℹ️"
                status_text="Info"
                ;;
            "start")
                emoji="🚀"
                status_text="Started"
                ;;
            "success")
                emoji="✅"
                status_text="Success"
                ;;
            *)
                emoji="ℹ️"
                status_text="Update"
                ;;
        esac
        
        # Format message for Telegram with proper escaping
        local telegram_message="$emoji *Deployment $status_text*

$message

🖥️ *Server:* \`$(hostname)\`
📁 *Repository:* \`$REPO_PATH\`
⏰ *Time:* $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Telegram API URL
        local telegram_url="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"
        
        # Use curl if available, otherwise use fetch
        if command -v curl >/dev/null 2>&1; then
            local telegram_payload="{
                \"chat_id\": \"$TELEGRAM_CHAT_ID\",
                \"text\": \"$(echo "$telegram_message" | sed 's/"/\\"/g')\",
                \"parse_mode\": \"Markdown\",
                \"disable_web_page_preview\": true
            }"
            
            curl -X POST -H 'Content-type: application/json' \
                -d "$telegram_payload" \
                "$telegram_url" \
                --connect-timeout 10 \
                --max-time 30 \
                --silent --output /dev/null
        elif command -v fetch >/dev/null 2>&1; then
            # FreeBSD's native fetch command
            local temp_file="$HOME/tmp/telegram_payload_$$"
            mkdir -p "$HOME/tmp" 2>/dev/null
            
            local telegram_payload="{
                \"chat_id\": \"$TELEGRAM_CHAT_ID\",
                \"text\": \"$(echo "$telegram_message" | sed 's/"/\\"/g')\",
                \"parse_mode\": \"Markdown\",
                \"disable_web_page_preview\": true
            }"
            
            printf '%s\n' "$telegram_payload" > "$temp_file"
            fetch -q -o /dev/null -T 30 \
                --method=POST \
                --header="Content-Type: application/json" \
                --upload-file="$temp_file" \
                "$telegram_url" 2>/dev/null
            rm -f "$temp_file"
        fi
        
        if [ $? -eq 0 ]; then
            log_message "Telegram notification sent: $emoji Deployment $status_text"
        else
            log_message "Failed to send Telegram notification"
        fi
    fi
}

# Unified notification function - sends to both Discord and Telegram
send_notification() {
    local message="$1"
    local status="$2"
    
    # Send to Discord
    send_webhook "$message" "$status"
    
    # Send to Telegram
    send_telegram "$message" "$status"
}

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
    log_message "Cleanup completed"
}
trap cleanup EXIT INT TERM

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    log_message "ERROR: Deployment already in progress (lock file exists)"
    exit 1
fi

# Create lock file with PID
echo $$ > "$LOCK_FILE"
log_message "Starting smart deployment (PID: $$)"

# Send start notification
send_notification "Deployment process started on $(hostname)" "start"

# Kill any running Python processes before deployment
log_message "Stopping any running Python processes..."

# Count total processes found for summary
TOTAL_PROCESSES_FOUND=0
PROCESSES_KILLED_LIST=""

# First, list all Python processes that will be killed
for PYTHON_CMD in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v "$PYTHON_CMD" >/dev/null 2>&1; then
        # Find and log processes with their command lines before killing them
        if command -v pgrep >/dev/null 2>&1; then
            PYTHON_PIDS=$(pgrep -f "$PYTHON_CMD" 2>/dev/null)
        else
            PYTHON_PIDS=$(ps aux | grep "$PYTHON_CMD" | grep -v grep | awk '{print $2}' 2>/dev/null)
        fi
        
        if [ -n "$PYTHON_PIDS" ]; then
            log_message "Found $PYTHON_CMD processes:"
            
            # Show detailed process information with PID and script name
            for pid in $PYTHON_PIDS; do
                TOTAL_PROCESSES_FOUND=$((TOTAL_PROCESSES_FOUND + 1))
                if command -v ps >/dev/null 2>&1; then
                    # Get the command line for this PID
                    PROCESS_CMD=$(ps -p "$pid" -o args= 2>/dev/null | head -1)
                    if [ -n "$PROCESS_CMD" ]; then
                        # Extract just the script name from the command line
                        SCRIPT_NAME=$(echo "$PROCESS_CMD" | awk '{for(i=1;i<=NF;i++) if($i ~ /\.py$/) print $i}' | head -1)
                        if [ -n "$SCRIPT_NAME" ]; then
                            log_message "  PID: $pid - Script: $SCRIPT_NAME"
                            PROCESSES_KILLED_LIST="$PROCESSES_KILLED_LIST\n• PID: \`$pid\` - Script: \`$SCRIPT_NAME\`"
                        else
                            # Fallback: show the Python command if no .py file found
                            PYTHON_ONLY=$(echo "$PROCESS_CMD" | awk '{print $1}')
                            log_message "  PID: $pid - Command: $PYTHON_ONLY"
                            PROCESSES_KILLED_LIST="$PROCESSES_KILLED_LIST\n• PID: \`$pid\` - Command: \`$PYTHON_ONLY\`"
                        fi
                    else
                        log_message "  PID: $pid - Command: $PYTHON_CMD (details unavailable)"
                        PROCESSES_KILLED_LIST="$PROCESSES_KILLED_LIST\n• PID: \`$pid\` - Command: \`$PYTHON_CMD\`"
                    fi
                else
                    log_message "  PID: $pid - Command: $PYTHON_CMD"
                    PROCESSES_KILLED_LIST="$PROCESSES_KILLED_LIST\n• PID: \`$pid\` - Command: \`$PYTHON_CMD\`"
                fi
            done
            
            # Use killall with SIGTERM (-15) first, then SIGKILL (-9) if needed
            if command -v killall >/dev/null 2>&1; then
                if killall -15 "$PYTHON_CMD" 2>/dev/null; then
                    log_message "Sent SIGTERM to $PYTHON_CMD processes (PIDs: $PYTHON_PIDS)"
                fi
                sleep 2
                # Check what's still running after SIGTERM
                if command -v pgrep >/dev/null 2>&1; then
                    REMAINING_PIDS=$(pgrep -f "$PYTHON_CMD" 2>/dev/null)
                else
                    REMAINING_PIDS=$(ps aux | grep "$PYTHON_CMD" | grep -v grep | awk '{print $2}' 2>/dev/null)
                fi
                
                if [ -n "$REMAINING_PIDS" ]; then
                    log_message "Stubborn processes still running, showing details before force kill:"
                    for pid in $REMAINING_PIDS; do
                        if command -v ps >/dev/null 2>&1; then
                            PROCESS_CMD=$(ps -p "$pid" -o args= 2>/dev/null | head -1)
                            SCRIPT_NAME=$(echo "$PROCESS_CMD" | awk '{for(i=1;i<=NF;i++) if($i ~ /\.py$/) print $i}' | head -1)
                            if [ -n "$SCRIPT_NAME" ]; then
                                log_message "  PID: $pid - Script: $SCRIPT_NAME (force killing)"
                            else
                                log_message "  PID: $pid - Command: $PYTHON_CMD (force killing)"
                            fi
                        fi
                    done
                    
                    if killall -9 "$PYTHON_CMD" 2>/dev/null; then
                        log_message "Force killed $PYTHON_CMD processes with SIGKILL (PIDs: $REMAINING_PIDS)"
                    fi
                else
                    log_message "All $PYTHON_CMD processes terminated gracefully"
                fi
            else
                # Fallback for systems without killall
                if pkill -15 -f "$PYTHON_CMD" 2>/dev/null; then
                    log_message "Sent SIGTERM to $PYTHON_CMD processes with pkill (PIDs: $PYTHON_PIDS)"
                fi
                sleep 2
                # Check what's still running after SIGTERM
                if command -v pgrep >/dev/null 2>&1; then
                    REMAINING_PIDS=$(pgrep -f "$PYTHON_CMD" 2>/dev/null)
                else
                    REMAINING_PIDS=$(ps aux | grep "$PYTHON_CMD" | grep -v grep | awk '{print $2}' 2>/dev/null)
                fi
                
                if [ -n "$REMAINING_PIDS" ]; then
                    log_message "Stubborn processes still running, showing details before force kill:"
                    for pid in $REMAINING_PIDS; do
                        if command -v ps >/dev/null 2>&1; then
                            PROCESS_CMD=$(ps -p "$pid" -o args= 2>/dev/null | head -1)
                            SCRIPT_NAME=$(echo "$PROCESS_CMD" | awk '{for(i=1;i<=NF;i++) if($i ~ /\.py$/) print $i}' | head -1)
                            if [ -n "$SCRIPT_NAME" ]; then
                                log_message "  PID: $pid - Script: $SCRIPT_NAME (force killing)"
                            else
                                log_message "  PID: $pid - Command: $PYTHON_CMD (force killing)"
                            fi
                        fi
                    done
                    
                    if pkill -9 -f "$PYTHON_CMD" 2>/dev/null; then
                        log_message "Force killed $PYTHON_CMD processes with pkill SIGKILL (PIDs: $REMAINING_PIDS)"
                    fi
                else
                    log_message "All $PYTHON_CMD processes terminated gracefully"
                fi
            fi
        else
            log_message "No $PYTHON_CMD processes found to kill"
        fi
    fi
done

# Send Discord notification about process cleanup
if [ $TOTAL_PROCESSES_FOUND -gt 0 ]; then
    send_notification "🔄 **Process Cleanup Completed**\n\n**Stopped $TOTAL_PROCESSES_FOUND Python processes:**$PROCESSES_KILLED_LIST\n\n✅ All processes terminated successfully" "info"
    log_message "Python process cleanup completed - $TOTAL_PROCESSES_FOUND processes stopped"
else
    send_notification "ℹ️ **Process Cleanup**\n\nNo Python processes were running - clean environment detected" "info"
    log_message "Python process cleanup completed - no processes found"
fi

# Set PATH for FreeBSD/Serv00 - include common locations
export PATH="$HOME/.local/bin:$HOME/usr/local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Set Python path for user-installed packages
export PYTHONPATH="$HOME/.local/lib/python3.9/site-packages:$HOME/.local/lib/python3.8/site-packages:$PYTHONPATH"

# Validate repository path
if [ ! -d "$REPO_PATH" ]; then
    ERROR_MSG="ERROR: Repository path does not exist: $REPO_PATH"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Invalid Path" "$ERROR_MSG"
    send_notification "$ERROR_MSG" "error"
    exit 1
fi

cd "$REPO_PATH" || {
    ERROR_MSG="ERROR: Failed to change to repository directory"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Directory Access" "$ERROR_MSG"
    send_notification "$ERROR_MSG" "error"
    exit 1
}

# Check if it's a git repository
if [ ! -d ".git" ]; then
    ERROR_MSG="ERROR: Not a git repository: $REPO_PATH"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Not Git Repo" "$ERROR_MSG"
    send_notification "$ERROR_MSG" "error"
    exit 1
fi

# Configure git to use system certificates if needed
git config --global http.sslCAinfo /etc/ssl/cert.pem 2>/dev/null || true
git config --global http.sslverify true 2>/dev/null || true

# Fetch latest changes
log_message "Fetching latest changes from origin/$BRANCH"
FETCH_OUTPUT=$(git fetch origin "$BRANCH" 2>&1)
FETCH_EXIT_CODE=$?

if [ $FETCH_EXIT_CODE -ne 0 ]; then
    ERROR_MSG="ERROR: Failed to fetch from remote repository. Output: $FETCH_OUTPUT"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Fetch Failed" "$ERROR_MSG"
    send_notification "Failed to fetch from remote repository" "error"
    exit 1
fi

log_message "Fetch completed successfully"

# Check if there are updates
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "origin/$BRANCH" 2>/dev/null)

if [ -z "$REMOTE_COMMIT" ]; then
    ERROR_MSG="ERROR: Could not get remote commit hash"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Remote Commit" "$ERROR_MSG"
    send_notification "$ERROR_MSG" "error"
    exit 1
fi

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    log_message "No updates available. Current commit: $LOCAL_COMMIT"
    log_message "Smart deployment finished - no changes"
    send_notification "No updates found. Repository is up to date.\nCommit: \`$LOCAL_COMMIT\`" "info"
    exit 0
fi

log_message "Updates found. Proceeding with deployment..."
log_message "Local commit:  $LOCAL_COMMIT"
log_message "Remote commit: $REMOTE_COMMIT"

# Create short commit hashes for notifications (POSIX compatible)
LOCAL_COMMIT_SHORT=$(echo "$LOCAL_COMMIT" | cut -c1-8)
REMOTE_COMMIT_SHORT=$(echo "$REMOTE_COMMIT" | cut -c1-8)

# Send update notification
COMMIT_MESSAGE_SHORT=$(git log --oneline -1 "origin/$BRANCH" 2>/dev/null)
send_notification "Updates found! Starting deployment...\n**From:** \`$LOCAL_COMMIT_SHORT\`\n**To:** \`$REMOTE_COMMIT_SHORT\`\n**Latest commit:** $COMMIT_MESSAGE_SHORT" "info"

# Get commit message for notification
COMMIT_MESSAGE=$(git log --oneline -1 "origin/$BRANCH" 2>/dev/null | cut -d' ' -f2-)

# Reset to clean state before pulling (removes any local changes)
log_message "Resetting repository to clean state..."
RESET_OUTPUT=$(git reset --hard HEAD 2>&1)
RESET_EXIT_CODE=$?

if [ $RESET_EXIT_CODE -eq 0 ]; then
    log_message "Repository reset completed successfully"
else
    log_message "WARNING: Git reset failed. Output: $RESET_OUTPUT"
    send_notification "⚠️ **Git Reset Warning**\n\nFailed to reset repository to clean state\nOutput: \`$RESET_OUTPUT\`\nContinuing with deployment..." "warning"
fi

# Pull changes
log_message "Pulling changes from origin/$BRANCH"
PULL_OUTPUT=$(git pull origin "$BRANCH" 2>&1)
PULL_EXIT_CODE=$?

if [ $PULL_EXIT_CODE -eq 0 ]; then
    SUCCESS_MSG="Deployment completed successfully. Latest commit: $REMOTE_COMMIT"
    if [ -n "$COMMIT_MESSAGE" ]; then
        SUCCESS_MSG="$SUCCESS_MSG - $COMMIT_MESSAGE"
    fi
    
    log_message "$SUCCESS_MSG"
    
    # Optional: Install Python dependencies if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        log_message "Installing Python dependencies..."
        
        # Check if virtual environment exists and use it
        if [ -f ".venv/bin/python" ]; then
            log_message "Using virtual environment"
            .venv/bin/python -m pip install --upgrade -r requirements.txt >> "$LOG_FILE" 2>&1
            PIP_EXIT_CODE=$?
        else
            # Try different Python versions available on Serv00
            PIP_EXIT_CODE=1
            for PYTHON_CMD in python3.11 python3.10 python3.9 python3.8 python3 python; do
                if command -v "$PYTHON_CMD" >/dev/null 2>&1; then
                    log_message "Trying to install dependencies with $PYTHON_CMD"
                    "$PYTHON_CMD" -m pip install --user --upgrade -r requirements.txt >> "$LOG_FILE" 2>&1
                    PIP_EXIT_CODE=$?
                    if [ $PIP_EXIT_CODE -eq 0 ]; then
                        log_message "Successfully installed dependencies with $PYTHON_CMD"
                        break
                    fi
                fi
            done
        fi
        
        if [ $PIP_EXIT_CODE -ne 0 ]; then
            log_message "WARNING: Failed to install Python dependencies"
            send_notification "⚠️ Failed to install Python dependencies, but deployment continues" "warning"
        else
            log_message "Python dependencies installed successfully"
        fi
    fi
    
    # Optional: Set executable permissions if needed
    if [ -f "run.py" ]; then
        chmod +x run.py
        log_message "Set executable permissions for run.py"
    fi
    
    # Start the new Python process after successful deployment
    if [ -f "localRunner.py" ]; then
        log_message "Starting new Python process with localRunner.py"
        
        # Serv00-specific: Ensure we're in the correct directory
        CURRENT_DIR=$(pwd)
        log_message "Current working directory: $CURRENT_DIR"
        
        # Serv00-specific: Check for common issues
        log_message "Performing Serv00-specific checks..."
        
        # Check if we have enough disk space
        if command -v df >/dev/null 2>&1; then
            DISK_USAGE=$(df -h "$HOME" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
            if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 95 ]; then
                log_message "WARNING: Disk usage is ${DISK_USAGE}% - this may cause issues"
                send_notification "⚠️ **High Disk Usage Warning**\n\nDisk usage: ${DISK_USAGE}%\nThis may prevent process startup" "warning"
            else
                log_message "Disk usage check: OK (${DISK_USAGE}%)"
            fi
        fi
        
        # Check memory usage
        if command -v free >/dev/null 2>&1; then
            MEMORY_INFO=$(free -h 2>/dev/null | grep "Mem:" | awk '{print "Used: " $3 "/" $2}')
            log_message "Memory usage: $MEMORY_INFO"
        elif command -v top >/dev/null 2>&1; then
            # FreeBSD/Serv00 alternative
            MEMORY_INFO=$(top -n 1 2>/dev/null | grep "Mem:" | head -1)
            log_message "Memory info: $MEMORY_INFO"
        fi
        
        # Check if localRunner.py has correct permissions
        if [ -r "localRunner.py" ]; then
            log_message "localRunner.py permissions: OK (readable)"
        else
            log_message "ERROR: localRunner.py is not readable"
            send_notification "❌ **Permission Error**\n\nlocalRunner.py is not readable\nCheck file permissions" "error"
            exit 1
        fi
        
        # Find the best Python version to use (Serv00 specific order)
        PYTHON_TO_USE=""
        for PYTHON_CMD in python3.11 python3.10 python3.9 python3.8 python3 python; do
            if command -v "$PYTHON_CMD" >/dev/null 2>&1; then
                PYTHON_VERSION=$("$PYTHON_CMD" --version 2>&1)
                log_message "Found Python: $PYTHON_CMD ($PYTHON_VERSION)"
                PYTHON_TO_USE="$PYTHON_CMD"
                break
            fi
        done
        
        if [ -n "$PYTHON_TO_USE" ]; then
            # Serv00-specific: Set up environment variables
            export PYTHONUNBUFFERED=1
            export PYTHONPATH="$CURRENT_DIR:$PYTHONPATH"
            
            # Create logs directory if it doesn't exist
            mkdir -p "$HOME/logs" 2>/dev/null
            
            # Use absolute paths for better reliability on Serv00
            LOG_PATH="$HOME/logs/localRunner.log"
            SCRIPT_PATH="$CURRENT_DIR/localRunner.py"
            
            log_message "Starting localRunner.py with $PYTHON_TO_USE..."
            log_message "Script path: $SCRIPT_PATH"
            log_message "Log path: $LOG_PATH"
            log_message "Python path: $PYTHONPATH"
            
            # Send Discord notification about process startup attempt
            send_notification "🚀 **Starting New Process**\n\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• Working Dir: \`$CURRENT_DIR\`\n• Log: \`$LOG_PATH\`\n• Action: Starting in background with nohup" "info"
            
            # Start with explicit paths and better error handling
            cd "$CURRENT_DIR" && nohup "$PYTHON_TO_USE" "$SCRIPT_PATH" > "$LOG_PATH" 2>&1 &
            NEW_PID=$!
            
            log_message "Process started with PID: $NEW_PID"
            
            # Enhanced verification with multiple checks
            sleep 3  # Give more time for process to start
            
            # Check if process is still running
            if kill -0 "$NEW_PID" 2>/dev/null; then
                log_message "✓ Successfully started new process:"
                log_message "  PID: $NEW_PID - Script: localRunner.py"
                log_message "  Python interpreter: $PYTHON_TO_USE"
                log_message "  Output log: $LOG_PATH"
                log_message "  Working directory: $CURRENT_DIR"
                log_message "  Process status: Running"
                
                # Get additional process info if possible
                PROCESS_DETAILS=""
                if command -v ps >/dev/null 2>&1; then
                    PROCESS_INFO=$(ps -p "$NEW_PID" -o pid,ppid,cmd 2>/dev/null | tail -1)
                    if [ -n "$PROCESS_INFO" ]; then
                        log_message "  Full process info: $PROCESS_INFO"
                        PROCESS_DETAILS="\n• Full command: \`$PROCESS_INFO\`"
                    fi
                    
                    # Also show the working directory if possible
                    if [ -d "/proc/$NEW_PID" ] && [ -r "/proc/$NEW_PID/cwd" ]; then
                        PROCESS_CWD=$(readlink "/proc/$NEW_PID/cwd" 2>/dev/null)
                        if [ -n "$PROCESS_CWD" ]; then
                            log_message "  Working directory: $PROCESS_CWD"
                            PROCESS_DETAILS="$PROCESS_DETAILS\n• Working dir: \`$PROCESS_CWD\`"
                        fi
                    fi
                fi
                
                # Check if log file is being written to
                if [ -f "$LOG_PATH" ]; then
                    LOG_SIZE=$(wc -c < "$LOG_PATH" 2>/dev/null || echo "0")
                    log_message "  Log file size: $LOG_SIZE bytes"
                    
                    # Show first few lines of log for debugging
                    if [ "$LOG_SIZE" -gt 0 ]; then
                        log_message "  First lines of log:"
                        head -5 "$LOG_PATH" 2>/dev/null | while read -r line; do
                            log_message "    $line"
                        done
                    fi
                else
                    log_message "  WARNING: Log file not created yet"
                fi
                
                # Send successful startup notification to Discord
                send_notification "✅ **Process Started Successfully**\n\n• PID: \`$NEW_PID\`\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• Log: \`$LOG_PATH\`\n• Working Dir: \`$CURRENT_DIR\`\n• Status: **Running**$PROCESS_DETAILS" "success"
                
                # Enhanced success message with process info
                SUCCESS_MSG="$SUCCESS_MSG\n\n🐍 **Process Started:**\n• PID: \`$NEW_PID\`\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• Log: \`$LOG_PATH\`\n• Status: Running"
            else
                log_message "✗ Failed to start localRunner.py - process died immediately"
                log_message "  PID was: $NEW_PID - Script: localRunner.py (failed)"
                
                # Check for common issues and provide debugging info
                log_message "Debugging information:"
                log_message "  Python executable: $PYTHON_TO_USE"
                log_message "  Script path: $SCRIPT_PATH"
                log_message "  Current directory: $CURRENT_DIR"
                log_message "  Log path: $LOG_PATH"
                
                # Check if Python executable works
                if "$PYTHON_TO_USE" --version >/dev/null 2>&1; then
                    log_message "  Python executable test: PASSED"
                else
                    log_message "  Python executable test: FAILED"
                fi
                
                # Check if script exists and is readable
                if [ -r "$SCRIPT_PATH" ]; then
                    log_message "  Script file test: PASSED (readable)"
                else
                    log_message "  Script file test: FAILED (not readable or missing)"
                fi
                
                # Show log file content if it exists
                if [ -f "$LOG_PATH" ]; then
                    LOG_SIZE=$(wc -c < "$LOG_PATH" 2>/dev/null || echo "0")
                    log_message "  Log file created, size: $LOG_SIZE bytes"
                    if [ "$LOG_SIZE" -gt 0 ]; then
                        log_message "  Log file contents:"
                        cat "$LOG_PATH" 2>/dev/null | while read -r line; do
                            log_message "    $line"
                        done
                    fi
                else
                    log_message "  Log file not created"
                fi
                
                # Try a simple test run to see what happens
                log_message "  Attempting test run..."
                TEST_OUTPUT=$("$PYTHON_TO_USE" -c "print('Python test successful'); import sys; print('Python version:', sys.version)" 2>&1)
                log_message "  Python test output: $TEST_OUTPUT"
                
                # Send failure notification to Discord
                send_notification "❌ **Process Startup Failed**\n\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• PID was: \`$NEW_PID\`\n• Issue: Process died immediately after startup\n• Check log: \`$LOG_PATH\`\n• Working Dir: \`$CURRENT_DIR\`" "error"
                
                # Try alternative startup methods for Serv00
                log_message "Attempting alternative startup methods..."
                
                # Method 1: Try without nohup
                log_message "Trying without nohup..."
                "$PYTHON_TO_USE" "$SCRIPT_PATH" > "$LOG_PATH" 2>&1 &
                ALT_PID=$!
                sleep 2
                if kill -0 "$ALT_PID" 2>/dev/null; then
                    log_message "✓ Alternative method 1 successful (PID: $ALT_PID)"
                    send_notification "✅ **Process Started with Alternative Method**\n\n• PID: \`$ALT_PID\`\n• Method: Without nohup\n• Script: \`localRunner.py\`" "success"
                else
                    log_message "✗ Alternative method 1 failed"
                    
                    # Method 2: Try with explicit shell
                    log_message "Trying with explicit shell..."
                    /bin/sh -c "cd '$CURRENT_DIR' && '$PYTHON_TO_USE' '$SCRIPT_PATH' > '$LOG_PATH' 2>&1 &"
                    sleep 2
                    
                    # Find the new process by checking for localRunner.py
                    if command -v pgrep >/dev/null 2>&1; then
                        SHELL_PID=$(pgrep -f "localRunner.py" 2>/dev/null | tail -1)
                    else
                        SHELL_PID=$(ps aux | grep "localRunner.py" | grep -v grep | awk '{print $2}' | tail -1)
                    fi
                    
                    if [ -n "$SHELL_PID" ] && kill -0 "$SHELL_PID" 2>/dev/null; then
                        log_message "✓ Alternative method 2 successful (PID: $SHELL_PID)"
                        send_notification "✅ **Process Started with Shell Method**\n\n• PID: \`$SHELL_PID\`\n• Method: Explicit shell\n• Script: \`localRunner.py\`" "success"
                    else
                        log_message "✗ Alternative method 2 failed"
                        
                        # Method 3: Check if we need to install dependencies first
                        log_message "Checking if dependencies are missing..."
                        DEP_CHECK=$("$PYTHON_TO_USE" -c "
import sys
try:
    import requests
    print('requests: OK')
except ImportError:
    print('requests: MISSING')
    sys.exit(1)
try:
    import websocket
    print('websocket: OK')
except ImportError:
    print('websocket: MISSING')
    sys.exit(1)
print('Dependencies check: PASSED')
" 2>&1)
                        
                        log_message "Dependency check result: $DEP_CHECK"
                        
                        if echo "$DEP_CHECK" | grep -q "MISSING"; then
                            log_message "Missing dependencies detected, deployment may need dependency installation"
                            send_notification "⚠️ **Process Startup Failed - Missing Dependencies**\n\n• Issue: Python dependencies missing\n• Check: \`$DEP_CHECK\`\n• Action: May need to install requirements.txt" "warning"
                        else
                            log_message "All alternative startup methods failed"
                            send_notification "❌ **All Startup Methods Failed**\n\n• Script: \`localRunner.py\`\n• Tried: nohup, direct, shell methods\n• Check log: \`$LOG_PATH\`" "error"
                        fi
                    fi
                fi
            fi
        else
            log_message "WARNING: No Python interpreter found to start localRunner.py"
            send_notification "⚠️ **Process Startup Skipped**\n\n• Script: \`localRunner.py\`\n• Issue: No Python interpreter found\n• Available versions checked: python3.11, python3.10, python3.9, python3.8, python3, python" "warning"
        fi
    else
        log_message "WARNING: localRunner.py not found, skipping process startup"
        send_notification "⚠️ localRunner.py not found - skipping process startup" "warning"
    fi
    
    # Send success notifications
    if [ "$SEND_EMAIL_ON_SUCCESS" = "true" ]; then
        send_email "Deployment Success" "$SUCCESS_MSG"
    fi
    send_notification "$SUCCESS_MSG" "success"
    
    log_message "Smart deployment finished successfully"
else
    ERROR_MSG="ERROR: Deployment failed. Pull output: $PULL_OUTPUT"
    log_message "$ERROR_MSG"
    
    # Try to recover by resetting to last known good state
    log_message "Attempting recovery by resetting to HEAD"
    git reset --hard HEAD >> "$LOG_FILE" 2>&1
    
    # Send error notifications
    send_email "Deployment Failed" "$ERROR_MSG"
    send_notification "Deployment failed - check logs for details" "error"
    
    exit 1
fi