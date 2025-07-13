#!/bin/sh

# FreeBSD/Serv00 compatible deployment script

# Configuration defaults - can be overridden by .env file
REPO_PATH="repo/git/pub/TTV/"
LOG_FILE="repo/git/pub/TTV/deploy.log"
LOCK_FILE="$HOME/tmp/deploy.lock"
BRANCH="master"

# Load environment variables from .env file if it exists
load_env_file() {
    local env_file="${1:-.env}"
    
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
                \"username\": \"$(hostname) Deploy Bot\",
                \"avatar_url\": \"https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png\",
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

# Send update notification
COMMIT_MESSAGE_SHORT=$(git log --oneline -1 "origin/$BRANCH" 2>/dev/null)
send_notification "Updates found! Starting deployment...\n**From:** \`${LOCAL_COMMIT:0:8}\`\n**To:** \`${REMOTE_COMMIT:0:8}\`\n**Latest commit:** $COMMIT_MESSAGE_SHORT" "info"

# Get commit message for notification
COMMIT_MESSAGE=$(git log --oneline -1 "origin/$BRANCH" 2>/dev/null | cut -d' ' -f2-)

# Stash any local changes (optional)
if [ -n "$(git status --porcelain)" ]; then
    log_message "Local changes detected, stashing..."
    STASH_OUTPUT=$(git stash 2>&1)
    log_message "Stash output: $STASH_OUTPUT"
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
        
        # Find the best Python version to use
        PYTHON_TO_USE=""
        for PYTHON_CMD in python3.11 python3.10 python3.9 python3.8 python3 python; do
            if command -v "$PYTHON_CMD" >/dev/null 2>&1; then
                PYTHON_TO_USE="$PYTHON_CMD"
                break
            fi
        done
        
        if [ -n "$PYTHON_TO_USE" ]; then
            # Start the process in the background with nohup
            log_message "Starting localRunner.py with $PYTHON_TO_USE..."
            
            # Send Discord notification about process startup attempt
            send_notification "🚀 **Starting New Process**\n\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• Action: Starting in background with nohup" "info"
            
            nohup "$PYTHON_TO_USE" localRunner.py > "$HOME/localRunner.log" 2>&1 &
            NEW_PID=$!
            
            # Verify the process started successfully
            sleep 1
            if kill -0 "$NEW_PID" 2>/dev/null; then
                log_message "✓ Successfully started new process:"
                log_message "  PID: $NEW_PID - Script: localRunner.py"
                log_message "  Python interpreter: $PYTHON_TO_USE"
                log_message "  Output log: $HOME/localRunner.log"
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
                
                # Send successful startup notification to Discord
                send_notification "✅ **Process Started Successfully**\n\n• PID: \`$NEW_PID\`\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• Log: \`$HOME/localRunner.log\`\n• Status: **Running**$PROCESS_DETAILS" "success"
                
                # Enhanced success message with process info
                SUCCESS_MSG="$SUCCESS_MSG\n\n🐍 **Process Started:**\n• PID: \`$NEW_PID\`\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• Log: \`$HOME/localRunner.log\`\n• Status: Running"
            else
                log_message "✗ Failed to start localRunner.py - process died immediately"
                log_message "  PID was: $NEW_PID - Script: localRunner.py (failed)"
                
                # Send failure notification to Discord
                send_notification "❌ **Process Startup Failed**\n\n• Script: \`localRunner.py\`\n• Python: \`$PYTHON_TO_USE\`\n• PID was: \`$NEW_PID\`\n• Issue: Process died immediately after startup\n• Check log: \`$HOME/localRunner.log\`" "error"
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