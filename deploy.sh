#!/bin/sh
# Unified Clean Deployment Script for Twitch Channel Points Miner
# Combines functionality from all deployment scripts with forced clean pull
# This script performs a HARD RESET and clean pull from remote repository

# Configuration defaults - can be overridden by .env file or environment
# If REPO_PATH is set in environment it will be used; otherwise use script dir
if [ -n "$REPO_PATH" ]; then
    : # use provided REPO_PATH
else
    REPO_PATH="$(cd "$(dirname "$0")" && pwd)"
fi
LOG_FILE="$HOME/logs/unified_clean_deploy.log"
LOCK_FILE="$HOME/tmp/clean_deploy.lock"
BRANCH="master"

# CLI flags
DRY_RUN=0
for _arg in "$@"; do
    case "$_arg" in
        --dry-run|-n)
            DRY_RUN=1
            ;;
    esac
done

# Set environment for compatibility (FreeBSD/Serv00/Linux)
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send webhook notification
send_webhook() {
    local message="$1"
    local status="$2"
    
    if [ -n "$WEBHOOK_URL" ]; then
        local color="#36a64f"  # Green for success
        local title="✅ Clean Deploy Success"
        
        case "$status" in
            "error")
                color="#ff0000"
                title="❌ Clean Deploy Error"
                ;;
            "warning")
                color="#ffaa00"
                title="⚠️ Clean Deploy Warning"
                ;;
            "info")
                color="#0099ff"
                title="ℹ️ Clean Deploy Info"
                ;;
            "start")
                color="#0099ff"
                title="🧹 Clean Deploy Started"
                ;;
            "reset")
                color="#ff6600"
                title="🔄 Hard Reset Performed"
                ;;
        esac
        
        if command -v curl >/dev/null 2>&1; then
            local payload="{
                \"username\": \"Clean Deploy Bot\",
                \"embeds\": [{
                    \"title\": \"$title\",
                    \"description\": \"$message\",
                    \"color\": $(printf '%d' 0x${color#\#}),
                    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
                    \"footer\": {
                        \"text\": \"Unified Clean Deploy\",
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
                            \"value\": \"$(basename "$REPO_PATH")\",
                            \"inline\": true
                        }
                    ]
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
            "start") emoji="🧹" ;;
            "reset") emoji="🔄" ;;
        esac
        
        local formatted_message="$emoji *Clean Deploy Update*\n\n$message\n\n🖥️ *Server:* \`$(hostname)\`\n📁 *Repository:* \`$(basename "$REPO_PATH")\`"
        
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
    
    TOTAL_PROCESSES_KILLED=0
    
    for py in python3.11 python3.10 python3.9 python3.8 python3 python; do
        if command -v killall >/dev/null 2>&1; then
            if killall "$py" 2>/dev/null; then
                KILLED_COUNT=$(pgrep -c "$py" 2>/dev/null || echo 0)
                TOTAL_PROCESSES_KILLED=$((TOTAL_PROCESSES_KILLED + KILLED_COUNT))
            fi
        elif command -v pkill >/dev/null 2>&1; then
            KILLED_COUNT=$(pgrep -c "$py" 2>/dev/null || echo 0)
            pkill -f "$py" 2>/dev/null
            TOTAL_PROCESSES_KILLED=$((TOTAL_PROCESSES_KILLED + KILLED_COUNT))
        fi
        
        # Also try pgrep/kill combination
        if command -v pgrep >/dev/null 2>&1; then
            PIDS=$(pgrep -f "$py" 2>/dev/null)
            if [ -n "$PIDS" ]; then
                for pid in $PIDS; do
                    if kill "$pid" 2>/dev/null; then
                        TOTAL_PROCESSES_KILLED=$((TOTAL_PROCESSES_KILLED + 1))
                        log_message "Killed Python process: $pid"
                    fi
                done
            fi
        fi
    done
    
    sleep 2
    
    if [ $TOTAL_PROCESSES_KILLED -gt 0 ]; then
        log_message "Python process cleanup completed - $TOTAL_PROCESSES_KILLED processes stopped"
        send_notification "Stopped $TOTAL_PROCESSES_KILLED Python processes to prepare for clean deployment" "info"
    else
        log_message "Python process cleanup completed - no processes found"
    fi
}

# Respect dry-run: do not actually kill processes when in dry-run mode
kill_python_processes_wrapper() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log_message "Dry-run: skipping killing Python processes"
        return 0
    fi
    kill_python_processes
}

# Function to perform hard reset and clean pull
clean_pull_repository() {
    log_message "Performing clean repository update with hard reset..."
    
    # Change to repository directory
    cd "$REPO_PATH" || {
        log_message "ERROR: Failed to change to repository directory: $REPO_PATH"
        return 1
    }
    
    # Check if this is a git repository
    if [ ! -d ".git" ]; then
        log_message "ERROR: Not a git repository: $REPO_PATH"
        return 1
    fi

    # If dry-run requested, show what would happen and exit early
    if [ "$DRY_RUN" -eq 1 ]; then
        log_message "DRY RUN: Showing planned repository changes (no modifications will be made)"
        log_message "DRY RUN: Untracked files that would be removed (git clean -nd):"
        git clean -nd 2>/dev/null | sed -n '1,200p' | while read -r line; do log_message "  $line"; done
        log_message "DRY RUN: Fetching remote info for origin/$BRANCH (no pull will be performed)"
        git fetch origin "$BRANCH" 2>/dev/null || true
        log_message "DRY RUN: Commits that would be pulled (HEAD..origin/$BRANCH):"
        git log --oneline HEAD..origin/"$BRANCH" 2>/dev/null | sed -n '1,50p' | while read -r line; do log_message "  $line"; done
        return 2
    fi
    
    # Configure git settings for better compatibility
    git config --global http.sslverify true 2>/dev/null || true
    
    # Show current status before cleanup
    log_message "Current repository status:"
    CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    DIRTY_FILES=$(git status --porcelain 2>/dev/null | wc -l)
    
    log_message "  Current branch: $CURRENT_BRANCH"
    log_message "  Current commit: $CURRENT_COMMIT"
    log_message "  Dirty files: $DIRTY_FILES"
    
    if [ "$DIRTY_FILES" -gt 0 ]; then
        log_message "  Uncommitted changes detected - will be discarded!"
        git status --short 2>/dev/null | while read -r line; do
            log_message "    $line"
        done
        
        send_notification "⚠️ **Uncommitted Changes Detected**\n\nThe following changes will be **PERMANENTLY LOST**:\n\n$(git status --short 2>/dev/null | head -10 | sed 's/^/• /')\n\n**Continuing with hard reset in 5 seconds...**" "warning"
        sleep 5
    fi
    
    # STEP 1: Clean working directory (remove untracked files)
    log_message "STEP 1: Cleaning untracked files and directories..."
    CLEAN_OUTPUT=$(git clean -fd 2>&1)
    CLEAN_EXIT_CODE=$?
    
    if [ $CLEAN_EXIT_CODE -eq 0 ]; then
        log_message "✅ Working directory cleaned successfully"
        if [ -n "$CLEAN_OUTPUT" ]; then
            log_message "Removed files/directories: $CLEAN_OUTPUT"
        fi
    else
        log_message "⚠️ Warning: Git clean failed: $CLEAN_OUTPUT"
    fi
    
    # STEP 2: Hard reset local changes
    log_message "STEP 2: Performing HARD RESET to discard all local changes..."
    RESET_OUTPUT=$(git reset --hard HEAD 2>&1)
    RESET_EXIT_CODE=$?
    
    if [ $RESET_EXIT_CODE -eq 0 ]; then
        log_message "✅ Hard reset completed successfully"
        send_notification "🔄 **Hard Reset Completed**\n\nAll local changes have been discarded\nRepository is now in clean state" "reset"
    else
        log_message "❌ Hard reset failed: $RESET_OUTPUT"
        send_notification "❌ **Hard Reset Failed**\n\nError: $RESET_OUTPUT" "error"
        return 1
    fi
    
    # STEP 3: Fetch latest changes from remote
    log_message "STEP 3: Fetching latest changes from origin/$BRANCH..."
    FETCH_OUTPUT=$(git fetch origin "$BRANCH" 2>&1)
    FETCH_EXIT_CODE=$?
    
    if [ $FETCH_EXIT_CODE -ne 0 ]; then
        log_message "❌ Git fetch failed: $FETCH_OUTPUT"
        send_notification "❌ **Fetch Failed**\n\nError: $FETCH_OUTPUT" "error"
        return 1
    fi
    
    log_message "✅ Fetch completed successfully"
    
    # STEP 4: Check if there are updates available
    REMOTE_COMMIT=$(git rev-parse "origin/$BRANCH" 2>/dev/null)
    
    if [ -z "$REMOTE_COMMIT" ]; then
        log_message "❌ Could not get remote commit hash"
        return 1
    fi
    
    if [ "$CURRENT_COMMIT" = "$REMOTE_COMMIT" ]; then
        log_message "ℹ️ No updates available. Repository is already up to date"
        log_message "Current commit: $CURRENT_COMMIT"
        send_notification "ℹ️ **No Updates Available**\n\nRepository is already up to date\nCommit: \`$(echo "$CURRENT_COMMIT" | cut -c1-8)\`" "info"
        return 2  # Special return code for "no updates"
    fi
    
    # STEP 5: Show what will be updated
    log_message "STEP 4: Updates found! Preparing to pull changes..."
    log_message "  From: $CURRENT_COMMIT"
    log_message "  To:   $REMOTE_COMMIT"
    
    # Get commit message and file changes
    COMMIT_COUNT=$(git rev-list --count "$CURRENT_COMMIT..$REMOTE_COMMIT" 2>/dev/null || echo "unknown")
    LATEST_COMMIT_MSG=$(git log --oneline -1 "origin/$BRANCH" 2>/dev/null || echo "Unable to get commit message")
    
    log_message "  Commits to pull: $COMMIT_COUNT"
    log_message "  Latest commit: $LATEST_COMMIT_MSG"
    
    # Show files that will be changed
    FILES_CHANGED=$(git diff --name-only "$CURRENT_COMMIT" "origin/$BRANCH" 2>/dev/null | wc -l)
    log_message "  Files to be updated: $FILES_CHANGED"
    
    if [ "$FILES_CHANGED" -gt 0 ] && [ "$FILES_CHANGED" -lt 20 ]; then
        log_message "  Changed files:"
        git diff --name-only "$CURRENT_COMMIT" "origin/$BRANCH" 2>/dev/null | while read -r file; do
            log_message "    - $file"
        done
    fi
    
    send_notification "🔄 **Updates Found - Starting Pull**\n\n• Commits: $COMMIT_COUNT\n• Files: $FILES_CHANGED\n• Latest: $LATEST_COMMIT_MSG\n• From: \`$(echo "$CURRENT_COMMIT" | cut -c1-8)\`\n• To: \`$(echo "$REMOTE_COMMIT" | cut -c1-8)\`" "info"
    
    # STEP 6: Force pull from remote (this will always succeed after hard reset)
    log_message "STEP 5: Pulling changes from origin/$BRANCH..."
    PULL_OUTPUT=$(git pull origin "$BRANCH" 2>&1)
    PULL_EXIT_CODE=$?
    
    if [ $PULL_EXIT_CODE -eq 0 ]; then
        NEW_COMMIT=$(git rev-parse HEAD 2>/dev/null)
        log_message "✅ Pull completed successfully!"
        log_message "New commit: $NEW_COMMIT"
        
        # Verify we got the expected commit
        if [ "$NEW_COMMIT" = "$REMOTE_COMMIT" ]; then
            log_message "✅ Repository successfully updated to latest remote commit"
            send_notification "✅ **Repository Updated Successfully**\n\n• New commit: \`$(echo "$NEW_COMMIT" | cut -c1-8)\`\n• Files updated: $FILES_CHANGED\n• Commits pulled: $COMMIT_COUNT" "info"
            return 0
        else
            log_message "⚠️ Warning: Unexpected commit after pull"
            log_message "Expected: $REMOTE_COMMIT"
            log_message "Got: $NEW_COMMIT"
            return 1
        fi
    else
        log_message "❌ Pull failed: $PULL_OUTPUT"
        send_notification "❌ **Pull Failed**\n\nError: $PULL_OUTPUT" "error"
        return 1
    fi
}

# Function to install/update Python dependencies
update_dependencies() {
    log_message "Checking and updating Python dependencies..."
    
    if [ ! -f "requirements.txt" ]; then
        log_message "No requirements.txt found, skipping dependency installation"
        return 0
    fi
    
    # Find Python interpreter
    PYTHON_CMD=$(find_python)
    if [ -z "$PYTHON_CMD" ]; then
        log_message "ERROR: No Python interpreter found for dependency installation"
        return 1
    fi
    
    log_message "Using Python interpreter: $PYTHON_CMD"
    
    # Check if virtual environment exists
    if [ -f ".venv/bin/python" ]; then
        log_message "Using virtual environment: .venv/bin/python"
        PYTHON_CMD=".venv/bin/python"
    elif [ -f ".venv/Scripts/python.exe" ]; then
        log_message "Using virtual environment: .venv/Scripts/python.exe"
        PYTHON_CMD=".venv/Scripts/python.exe"
    else
        log_message "No virtual environment found, using system Python with --user flag"
    fi
    
    # Install/update dependencies
    log_message "Installing/updating Python dependencies..."
    if echo "$PYTHON_CMD" | grep -q "\.venv"; then
        # Virtual environment - no --user flag needed
        INSTALL_OUTPUT=$("$PYTHON_CMD" -m pip install --upgrade -r requirements.txt 2>&1)
    else
        # System Python - use --user flag
        INSTALL_OUTPUT=$("$PYTHON_CMD" -m pip install --user --upgrade -r requirements.txt 2>&1)
    fi
    INSTALL_EXIT_CODE=$?
    
    if [ $INSTALL_EXIT_CODE -eq 0 ]; then
        log_message "✅ Python dependencies updated successfully"
        # Count how many packages were processed
        PACKAGES_COUNT=$(echo "$INSTALL_OUTPUT" | grep -c "Requirement already satisfied\|Successfully installed\|Collecting" 2>/dev/null || echo "unknown")
        send_notification "✅ **Dependencies Updated**\n\nPackages processed: $PACKAGES_COUNT\nPython: \`$PYTHON_CMD\`" "info"
        return 0
    else
        log_message "❌ Failed to update Python dependencies"
        log_message "Error: $INSTALL_OUTPUT"
        send_notification "❌ **Dependency Update Failed**\n\nError: \`$(echo "$INSTALL_OUTPUT" | head -3 | tr '\n' ' ')\`" "error"
        return 1
    fi
}

# Function to start localRunner.py with enhanced error handling
start_localrunner() {
    log_message "Starting localRunner.py..."
    
    # Check if localRunner.py exists
    if [ ! -f "localRunner.py" ]; then
        log_message "ERROR: localRunner.py not found in $REPO_PATH"
        send_notification "❌ **Startup Failed**\n\nlocalRunner.py not found" "error"
        return 1
    fi
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        log_message "ERROR: .env file not found"
        send_notification "❌ **Startup Failed**\n\n.env file not found" "error"
        return 1
    fi
    
    # Find Python interpreter
    PYTHON_CMD=$(find_python)
    if [ -z "$PYTHON_CMD" ]; then
        log_message "ERROR: No Python interpreter found"
        send_notification "❌ **Startup Failed**\n\nNo Python interpreter found" "error"
        return 1
    fi
    
    log_message "Using Python interpreter: $PYTHON_CMD"
    
    # Try to install python-dotenv if missing
    if ! "$PYTHON_CMD" -c "import dotenv" 2>/dev/null; then
        log_message "Installing python-dotenv..."
        if echo "$PYTHON_CMD" | grep -q "\.venv"; then
            "$PYTHON_CMD" -m pip install python-dotenv >> "$LOG_FILE" 2>&1
        else
            "$PYTHON_CMD" -m pip install --user python-dotenv >> "$LOG_FILE" 2>&1
        fi
    fi
    
    # Set up log file for localRunner
    LOCAL_LOG="$HOME/logs/localRunner.log"
    
    # Enhanced startup with multiple methods and better error handling
    START_SUCCESS=0
    
    # Method 1: nohup (most reliable for long-running processes)
    log_message "Attempting to start with nohup..."
    nohup "$PYTHON_CMD" localRunner.py > "$LOCAL_LOG" 2>&1 &
    PID1=$!
    sleep 3
    
    if kill -0 "$PID1" 2>/dev/null; then
        log_message "✅ SUCCESS: Process started with nohup (PID: $PID1)"
        START_SUCCESS=1
        
        # Verify it's actually running properly by checking log
        if [ -f "$LOCAL_LOG" ]; then
            sleep 2  # Give it a moment to write to log
            LOG_SIZE=$(wc -c < "$LOCAL_LOG" 2>/dev/null || echo "0")
            if [ "$LOG_SIZE" -gt 0 ]; then
                log_message "Process is generating output (log size: $LOG_SIZE bytes)"
                log_message "First few lines of log:"
                head -5 "$LOCAL_LOG" 2>/dev/null | while read -r line; do
                    log_message "  $line"
                done
            fi
        fi
        
        send_notification "✅ **Process Started Successfully**\n\n• PID: \`$PID1\`\n• Method: nohup\n• Script: localRunner.py\n• Log: $LOCAL_LOG\n• Python: \`$PYTHON_CMD\`" "success"
        return 0
    else
        log_message "Method 1 (nohup) failed"
        
        # Method 2: Direct background
        log_message "Attempting direct background startup..."
        "$PYTHON_CMD" localRunner.py > "$LOCAL_LOG" 2>&1 &
        PID2=$!
        sleep 3
        
        if kill -0 "$PID2" 2>/dev/null; then
            log_message "✅ SUCCESS: Process started directly (PID: $PID2)"
            START_SUCCESS=1
            send_notification "✅ **Process Started Successfully**\n\n• PID: \`$PID2\`\n• Method: direct background\n• Script: localRunner.py" "success"
            return 0
        else
            log_message "Method 2 (direct) failed"
            
            # Method 3: Screen (if available)
            if command -v screen >/dev/null 2>&1; then
                log_message "Attempting screen session startup..."
                screen -dmS miner_session "$PYTHON_CMD" localRunner.py
                sleep 3
                
                if screen -list | grep -q miner_session; then
                    log_message "✅ SUCCESS: Process started with screen"
                    START_SUCCESS=1
                    send_notification "✅ **Process Started Successfully**\n\n• Method: screen session\n• Session: miner_session\n• Script: localRunner.py" "success"
                    return 0
                else
                    log_message "Method 3 (screen) failed"
                fi
            fi
        fi
    fi
    
    # If all methods failed, show diagnostic information
    if [ $START_SUCCESS -eq 0 ]; then
        log_message "❌ All startup methods failed"
        
        # Show error details from log file
        if [ -f "$LOCAL_LOG" ]; then
            log_message "Error log contents (last 10 lines):"
            tail -10 "$LOCAL_LOG" 2>/dev/null | while read -r line; do
                log_message "  $line"
            done
            
            # Try to identify common issues
            if grep -q "ModuleNotFoundError\|ImportError" "$LOCAL_LOG" 2>/dev/null; then
                ERROR_TYPE="Missing Python modules"
            elif grep -q "environment variable" "$LOCAL_LOG" 2>/dev/null; then
                ERROR_TYPE="Missing environment variables"
            elif grep -q "FileNotFoundError" "$LOCAL_LOG" 2>/dev/null; then
                ERROR_TYPE="Missing files"
            else
                ERROR_TYPE="Unknown error"
            fi
            
            send_notification "❌ **Process Startup Failed**\n\n• Error type: $ERROR_TYPE\n• Check log: $LOCAL_LOG\n• All startup methods failed" "error"
        else
            send_notification "❌ **Process Startup Failed**\n\n• No log file created\n• All startup methods failed\n• Check Python installation and permissions" "error"
        fi
        
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
    log_message "=== Unified Clean Deployment Script Started ==="
    log_message "Working directory: $REPO_PATH"
    log_message "Log file: $LOG_FILE"
    log_message "Operation: HARD RESET + CLEAN PULL + RESTART"
    
    # Check for running instance
    check_lock
    
    # Send start notification
    send_notification "🧹 **Clean Deployment Started**\n\nServer: $(hostname)\nRepository: $(basename "$REPO_PATH")\nOperation: Hard reset + Clean pull + Restart" "start"
    
    # Step 1: Kill existing Python processes (respects --dry-run)
    kill_python_processes_wrapper
    
    # Step 2: Perform clean repository update with hard reset
    log_message "Starting clean repository update process..."
    clean_pull_repository
    REPO_UPDATE_STATUS=$?
    
    case $REPO_UPDATE_STATUS in
        0)
            log_message "✅ Repository updated successfully"
            REPO_STATUS="Updated successfully"
            ;;
        2)
            log_message "ℹ️ Repository was already up to date"
            REPO_STATUS="Already up to date"
            ;;
        *)
            log_message "❌ Repository update failed"
            REPO_STATUS="Update failed"
            
            ERROR_MSG="❌ **Clean Deployment Failed**\n\n• Stage: Repository update\n• Action: Hard reset and pull\n• Status: Failed\n• Check logs for details"
            send_notification "$ERROR_MSG" "error"
            log_message "=== Script completed with errors ==="
            exit 1
            ;;
    esac
    
    # Step 3: Update dependencies (only if repo was updated or forced)
    DEPENDENCY_STATUS="Skipped"
    if [ $REPO_UPDATE_STATUS -eq 0 ] || [ "$1" = "--force-deps" ]; then
        log_message "Updating Python dependencies..."
        if update_dependencies; then
            DEPENDENCY_STATUS="Updated successfully"
        else
            DEPENDENCY_STATUS="Update failed (continuing anyway)"
        fi
    else
        log_message "Skipping dependency update (no repository changes)"
    fi
    
    # Step 4: Start localRunner.py
    log_message "Starting localRunner.py process..."
    STARTUP_STATUS="Failed"
    if start_localrunner; then
        STARTUP_STATUS="Started successfully"
    else
        STARTUP_STATUS="Failed to start"
    fi
    
    # Final summary and notifications
    if [ "$STARTUP_STATUS" = "Started successfully" ]; then
        SUCCESS_MSG="✅ **Clean Deployment Completed Successfully**\n\n• Repository: $REPO_STATUS\n• Dependencies: $DEPENDENCY_STATUS\n• Process: $STARTUP_STATUS\n• Server: $(hostname)\n• Working Directory: $REPO_PATH\n• Log: $LOG_FILE"
        
        log_message "✅ Clean deployment completed successfully"
        log_message "Repository: $REPO_STATUS"
        log_message "Dependencies: $DEPENDENCY_STATUS"
        log_message "Process: $STARTUP_STATUS"
        
        send_notification "$SUCCESS_MSG" "success"
        log_message "=== Script completed successfully ==="
        exit 0
    else
        ERROR_MSG="⚠️ **Clean Deployment Partially Completed**\n\n• Repository: $REPO_STATUS\n• Dependencies: $DEPENDENCY_STATUS\n• Process: $STARTUP_STATUS\n• Issue: Failed to start localRunner.py\n• Check logs: $LOG_FILE"
        
        log_message "⚠️ Clean deployment partially completed - process startup failed"
        send_notification "$ERROR_MSG" "warning"
        log_message "=== Script completed with warnings ==="
        exit 1
    fi
}

# Show usage information if help requested
case "$1" in
    -h|--help|help)
        echo "Unified Clean Deployment Script for Twitch Channel Points Miner"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
    echo "Options:"
    echo "  --dry-run, -n   Show what would be done without making changes"
    echo "  --force-deps    Force dependency update even if repository unchanged"
    echo "  -h, --help      Show this help message"
        echo ""
        echo "This script performs:"
        echo "  1. Kills all running Python processes"
        echo "  2. Performs git clean -fd to remove untracked files"
        echo "  3. Performs git reset --hard HEAD to discard local changes"
        echo "  4. Fetches and pulls latest changes from remote repository"
        echo "  5. Updates Python dependencies (if repository changed)"
        echo "  6. Starts localRunner.py process"
        echo ""
        echo "WARNING: This script will PERMANENTLY DELETE all local changes!"
        echo "Make sure you have committed or backed up any important changes."
    echo ""
    echo "Environment variables:" 
    echo "  REPO_PATH=/path/to/repo   Override default repository path (script directory)"
        exit 0
        ;;
esac

# Run main function with all arguments
main "$@"