#!/bin/sh
# Deployment script for Twitch Channel Points Miner
# Pulls latest changes, installs dependencies, and starts the miner

set -e

# ─── Configuration ───────────────────────────────────────────────────────────

REPO_PATH="$(cd "$(dirname "$0")" && /bin/pwd -P)"
BRANCH="${BRANCH:-master}"
LOG_FILE="$REPO_PATH/logs/deploy.log"
LOCK_FILE="$REPO_PATH/tmp/deploy.lock"
MINER_LOG="$REPO_PATH/logs/localRunner.log"

# CLI flags
FORCE_RESET=0
FORCE_DEPS=0
DRY_RUN=0
for _arg in "$@"; do
    case "$_arg" in
        --force)     FORCE_RESET=1 ;;
        --force-deps) FORCE_DEPS=1 ;;
        --dry-run|-n) DRY_RUN=1 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force         Hard reset and clean before pulling (discards local changes)"
            echo "  --force-deps    Force dependency update even if no repo changes"
            echo "  --dry-run, -n   Show what would happen without making changes"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
    esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$LOCK_FILE")" 2>/dev/null || true

log() {
    timestamp="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$timestamp"
    echo "$timestamp" >> "$LOG_FILE" 2>/dev/null || true
}

# Load .env file (exports variables for notification config)
load_env() {
    env_file="$REPO_PATH/.env"
    if [ -f "$env_file" ]; then
        while IFS='=' read -r key value; do
            case "$key" in '#'*|'') continue ;; esac
            value=$(echo "$value" | sed "s/^[\"']//;s/[\"']$//")
            export "$key=$value"
        done < "$env_file"
    fi
}

# Send notifications to Discord and/or Telegram if configured
notify() {
    message="$1"
    status="$2"

    # Discord webhook
    if [ -n "${WEBHOOK:-}" ]; then
        case "$status" in
            error)   color=16711680; title="Deploy Error" ;;
            warning) color=16755200; title="Deploy Warning" ;;
            *)       color=3580415;  title="Deploy Update" ;;
        esac
        payload="{\"username\":\"Deploy Bot\",\"embeds\":[{\"title\":\"$title\",\"description\":\"$message\",\"color\":$color,\"footer\":{\"text\":\"$(hostname)\"}}]}"
        curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK" >/dev/null 2>&1 || true
    fi

    # Telegram
    if [ -n "${TELEGRAMTOKEN:-}" ] && [ -n "${CHATID:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAMTOKEN/sendMessage" \
            -d "chat_id=$CHATID" -d "text=$message" -d "parse_mode=Markdown" >/dev/null 2>&1 || true
    fi
}

# Find best available Python interpreter
find_python() {
    if [ -f "$REPO_PATH/.venv/bin/python" ]; then
        echo "$REPO_PATH/.venv/bin/python"
    elif [ -f "$REPO_PATH/.venv/Scripts/python.exe" ]; then
        echo "$REPO_PATH/.venv/Scripts/python.exe"
    else
        for py in python3.11 python3.10 python3.9 python3 python; do
            if command -v "$py" >/dev/null 2>&1; then
                echo "$py"
                return
            fi
        done
        return 1
    fi
}

# ─── Lock ────────────────────────────────────────────────────────────────────

if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        log "Deploy already running (PID: $LOCK_PID), exiting."
        exit 1
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# ─── Main ────────────────────────────────────────────────────────────────────

load_env

log "=== Deploy started ==="
log "Repo: $REPO_PATH | Branch: $BRANCH"
notify "Deploy started on \`$(hostname)\`" "info"

cd "$REPO_PATH" || { log "ERROR: Cannot cd to $REPO_PATH"; exit 1; }

if [ ! -d ".git" ]; then
    log "ERROR: $REPO_PATH is not a git repository"
    exit 1
fi

# Step 1: Stop existing miner process
MINER_PID=$(pgrep -f "localRunner.py\|run.py" 2>/dev/null || true)
if [ -n "$MINER_PID" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry-run: would stop miner processes: $MINER_PID"
    else
        log "Stopping miner (PID: $MINER_PID)..."
        kill $MINER_PID 2>/dev/null || true
        sleep 2
    fi
fi

# Step 2: Pull latest changes
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)

if [ "$FORCE_RESET" -eq 1 ]; then
    log "Force mode: resetting to origin/$BRANCH..."
    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry-run: would run git clean -fd && git reset --hard && git pull"
        git fetch origin "$BRANCH" 2>/dev/null || true
        log "Dry-run: commits that would be pulled:"
        git log --oneline "HEAD..origin/$BRANCH" 2>/dev/null | while read -r line; do log "  $line"; done
    else
        git clean -fd 2>/dev/null || true
        git reset --hard HEAD 2>/dev/null
        git pull origin "$BRANCH"
    fi
else
    log "Pulling latest changes from origin/$BRANCH..."
    if [ "$DRY_RUN" -eq 1 ]; then
        git fetch origin "$BRANCH" 2>/dev/null || true
        log "Dry-run: commits that would be pulled:"
        git log --oneline "HEAD..origin/$BRANCH" 2>/dev/null | while read -r line; do log "  $line"; done
    else
        git pull origin "$BRANCH"
    fi
fi

NEW_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
REPO_CHANGED=0
if [ "$CURRENT_COMMIT" != "$NEW_COMMIT" ]; then
    REPO_CHANGED=1
    log "Updated: $CURRENT_COMMIT -> $NEW_COMMIT"
    notify "Pulled \`$CURRENT_COMMIT\` -> \`$NEW_COMMIT\`" "info"
else
    log "Already up to date ($CURRENT_COMMIT)"
fi

# Step 3: Update dependencies if repo changed or forced
if [ "$REPO_CHANGED" -eq 1 ] || [ "$FORCE_DEPS" -eq 1 ]; then
    if [ -f "requirements.txt" ]; then
        PYTHON_CMD=$(find_python)
        if [ -n "$PYTHON_CMD" ]; then
            log "Installing dependencies with $PYTHON_CMD..."
            if [ "$DRY_RUN" -eq 1 ]; then
                log "Dry-run: would run pip install -r requirements.txt"
            else
                if echo "$PYTHON_CMD" | grep -q "\.venv"; then
                    "$PYTHON_CMD" -m pip install --upgrade -r requirements.txt >> "$LOG_FILE" 2>&1 || true
                else
                    "$PYTHON_CMD" -m pip install --user --upgrade -r requirements.txt >> "$LOG_FILE" 2>&1 || true
                fi
                log "Dependencies updated."
            fi
        else
            log "WARNING: No Python interpreter found, skipping dependencies."
        fi
    fi
else
    log "No repo changes, skipping dependency update."
fi

# Step 4: Start the miner
if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run: would start localRunner.py"
    log "=== Dry-run complete ==="
    exit 0
fi

if [ ! -f "localRunner.py" ]; then
    log "ERROR: localRunner.py not found"
    notify "Deploy failed: localRunner.py not found" "error"
    exit 1
fi

PYTHON_CMD=$(find_python)
if [ -z "$PYTHON_CMD" ]; then
    log "ERROR: No Python interpreter found"
    notify "Deploy failed: no Python found" "error"
    exit 1
fi

mkdir -p "$(dirname "$MINER_LOG")" 2>/dev/null || true
log "Starting localRunner.py..."
if [ -w "$(dirname "$MINER_LOG")" ] 2>/dev/null; then
    nohup "$PYTHON_CMD" localRunner.py > "$MINER_LOG" 2>&1 &
else
    nohup "$PYTHON_CMD" localRunner.py >/dev/null 2>&1 &
fi
MINER_PID=$!
sleep 3

if kill -0 "$MINER_PID" 2>/dev/null; then
    log "Miner started (PID: $MINER_PID)"
    notify "Deploy complete. Miner running (PID: \`$MINER_PID\`, commit: \`$NEW_COMMIT\`)" "info"
    log "=== Deploy complete ==="
    exit 0
else
    log "ERROR: Miner failed to start. Check $MINER_LOG"
    notify "Deploy failed: miner did not start. Check logs." "error"
    log "=== Deploy failed ==="
    exit 1
fi
