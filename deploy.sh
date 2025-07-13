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

# Email configuration (can be overridden in .env)
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-your-email@example.com}"
SEND_EMAIL_ON_ERROR="${SEND_EMAIL_ON_ERROR:-true}"
SEND_EMAIL_ON_SUCCESS="${SEND_EMAIL_ON_SUCCESS:-false}"

# Webhook configuration (can be overridden in .env)
SEND_WEBHOOK_NOTIFICATIONS="${SEND_WEBHOOK_NOTIFICATIONS:-true}"

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
        if [ "$status" = "error" ]; then
            color="#ff0000"  # Red for error
        fi
        
        # Use curl if available, otherwise use fetch
        if command -v curl >/dev/null 2>&1; then
            # Simple JSON payload for better compatibility
            local payload="{\"text\":\"Auto-Deploy: $message\",\"username\":\"$(hostname)\"}"
            
            curl -X POST -H 'Content-type: application/json' \
                -d "$payload" \
                "$WEBHOOK_URL" \
                --connect-timeout 10 \
                --max-time 30 \
                --silent --output /dev/null
        elif command -v fetch >/dev/null 2>&1; then
            # FreeBSD's native fetch command
            local temp_file="$HOME/tmp/webhook_payload_$$"
            mkdir -p "$HOME/tmp" 2>/dev/null
            printf '{"text":"Auto-Deploy: %s","username":"%s"}\n' "$message" "$(hostname)" > "$temp_file"
            fetch -q -o /dev/null -T 30 \
                --method=POST \
                --header="Content-Type: application/json" \
                --upload-file="$temp_file" \
                "$WEBHOOK_URL" 2>/dev/null
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

# Set PATH for FreeBSD/Serv00 - include common locations
export PATH="$HOME/.local/bin:$HOME/usr/local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Set Python path for user-installed packages
export PYTHONPATH="$HOME/.local/lib/python3.9/site-packages:$HOME/.local/lib/python3.8/site-packages:$PYTHONPATH"

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