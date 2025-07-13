#!/bin/sh

# Configuration
REPO_PATH="repo/git/pub/TTV/"
LOG_FILE="repo/git/pub/TTV//deploy.log"
LOCK_FILE="/tmp/deploy.lock"
BRANCH="main"

webhook = os.setenv("WEBHOOK", "")

# Email configuration
EMAIL_RECIPIENT="your-email@example.com"
SEND_EMAIL_ON_ERROR=true
SEND_EMAIL_ON_SUCCESS=false

# Webhook configuration
WEBHOOK_URL=webhook
SEND_WEBHOOK_NOTIFICATIONS=true

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send email notification (FreeBSD compatible)
send_email() {
    local subject="$1"
    local message="$2"
    
    if [ "$SEND_EMAIL_ON_ERROR" = "true" ] || [ "$SEND_EMAIL_ON_SUCCESS" = "true" ]; then
        # FreeBSD uses different mail command syntax
        echo "$message" | /usr/bin/mail -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null
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
        if [ "$status" = "error" ]; then
            color="#ff0000"  # Red for error
        fi
        
        # Use FreeBSD's fetch command or curl if available
        if command -v curl >/dev/null 2>&1; then
            # Slack format with curl
            local payload="{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"fields\": [{
                        \"title\": \"Auto-Deploy Status\",
                        \"value\": \"$message\",
                        \"short\": false
                    }],
                    \"footer\": \"$(hostname)\",
                    \"ts\": $(date +%s)
                }]
            }"
            
            curl -X POST -H 'Content-type: application/json' \
                --data "$payload" \
                "$WEBHOOK_URL" \
                --silent --output /dev/null
        elif command -v fetch >/dev/null 2>&1; then
            # FreeBSD's native fetch command
            local temp_file="/tmp/webhook_payload_$$"
            echo "{\"text\":\"$message\"}" > "$temp_file"
            fetch -q -o /dev/null --method=POST \
                --header="Content-Type: application/json" \
                --upload-file="$temp_file" \
                "$WEBHOOK_URL"
            rm -f "$temp_file"
        fi
        
        if [ $? -eq 0 ]; then
            log_message "Webhook notification sent"
        else
            log_message "Failed to send webhook notification"
        fi
    fi
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

# Set PATH for FreeBSD
export PATH="/usr/local/bin:/usr/bin:/bin"

# Validate repository path
if [ ! -d "$REPO_PATH" ]; then
    ERROR_MSG="ERROR: Repository path does not exist: $REPO_PATH"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Invalid Path" "$ERROR_MSG"
    send_webhook "$ERROR_MSG" "error"
    exit 1
fi

cd "$REPO_PATH" || {
    ERROR_MSG="ERROR: Failed to change to repository directory"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Directory Access" "$ERROR_MSG"
    send_webhook "$ERROR_MSG" "error"
    exit 1
}

# Check if it's a git repository
if [ ! -d ".git" ]; then
    ERROR_MSG="ERROR: Not a git repository: $REPO_PATH"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Not Git Repo" "$ERROR_MSG"
    send_webhook "$ERROR_MSG" "error"
    exit 1
fi

# Fetch latest changes
log_message "Fetching latest changes from origin/$BRANCH"
FETCH_OUTPUT=$(git fetch origin "$BRANCH" 2>&1)
FETCH_EXIT_CODE=$?

if [ $FETCH_EXIT_CODE -ne 0 ]; then
    ERROR_MSG="ERROR: Failed to fetch from remote repository. Output: $FETCH_OUTPUT"
    log_message "$ERROR_MSG"
    send_email "Deployment Error - Fetch Failed" "$ERROR_MSG"
    send_webhook "Failed to fetch from remote repository" "error"
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
    send_webhook "$ERROR_MSG" "error"
    exit 1
fi

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    log_message "No updates available. Current commit: $LOCAL_COMMIT"
    log_message "Smart deployment finished - no changes"
    exit 0
fi

log_message "Updates found. Proceeding with deployment..."
log_message "Local commit:  $LOCAL_COMMIT"
log_message "Remote commit: $REMOTE_COMMIT"

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
        if command -v python3 >/dev/null 2>&1; then
            python3 -m pip install --user -r requirements.txt >> "$LOG_FILE" 2>&1
        elif command -v python >/dev/null 2>&1; then
            python -m pip install --user -r requirements.txt >> "$LOG_FILE" 2>&1
        fi
    fi
    
    # Optional: Set executable permissions if needed
    if [ -f "run.py" ]; then
        chmod +x run.py
        log_message "Set executable permissions for run.py"
    fi
    
    # Send success notifications
    if [ "$SEND_EMAIL_ON_SUCCESS" = "true" ]; then
        send_email "Deployment Success" "$SUCCESS_MSG"
    fi
    send_webhook "$SUCCESS_MSG" "success"
    
    log_message "Smart deployment finished successfully"
else
    ERROR_MSG="ERROR: Deployment failed. Pull output: $PULL_OUTPUT"
    log_message "$ERROR_MSG"
    
    # Try to recover by resetting to last known good state
    log_message "Attempting recovery by resetting to HEAD"
    git reset --hard HEAD >> "$LOG_FILE" 2>&1
    
    # Send error notifications
    send_email "Deployment Failed" "$ERROR_MSG"
    send_webhook "Deployment failed - check logs for details" "error"
    
    exit 1
fi