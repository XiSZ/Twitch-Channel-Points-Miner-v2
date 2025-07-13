#!/bin/sh
# Simple startup script for Serv00/FreeBSD
# This is a minimal version that focuses on just starting localRunner.py

# Set environment for Serv00
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PYTHONPATH="$HOME/.local/lib/python3.11/site-packages:$HOME/.local/lib/python3.10/site-packages:$HOME/.local/lib/python3.9/site-packages:$HOME/.local/lib/python3.8/site-packages:$PYTHONPATH"
export PYTHONUNBUFFERED=1

# Change to script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Create logs directory
mkdir -p "$HOME/logs" 2>/dev/null

# Log file
LOG_FILE="$HOME/logs/simple_startup.log"

# Function to log messages
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_msg "Simple startup script started"
log_msg "Working directory: $SCRIPT_DIR"

# Find Python
PYTHON_CMD=""
for py in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v "$py" >/dev/null 2>&1; then
        PYTHON_CMD="$py"
        log_msg "Found Python: $py"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    log_msg "ERROR: No Python interpreter found"
    exit 1
fi

# Check if localRunner.py exists
if [ ! -f "localRunner.py" ]; then
    log_msg "ERROR: localRunner.py not found"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    log_msg "ERROR: .env file not found"
    exit 1
fi

# Try to install python-dotenv if missing
if ! "$PYTHON_CMD" -c "import dotenv" 2>/dev/null; then
    log_msg "Installing python-dotenv..."
    "$PYTHON_CMD" -m pip install --user python-dotenv >> "$LOG_FILE" 2>&1
fi

# Kill any existing localRunner processes
log_msg "Stopping any existing Python processes..."
for py in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v killall >/dev/null 2>&1; then
        killall "$py" 2>/dev/null
    elif command -v pkill >/dev/null 2>&1; then
        pkill -f "$py" 2>/dev/null
    fi
done

sleep 2

# Start localRunner.py
log_msg "Starting localRunner.py..."
LOCAL_LOG="$HOME/logs/localRunner.log"

# Try multiple startup methods
START_SUCCESS=0

# Method 1: nohup
log_msg "Method 1: Trying with nohup..."
nohup "$PYTHON_CMD" localRunner.py > "$LOCAL_LOG" 2>&1 &
PID1=$!
sleep 3
if kill -0 "$PID1" 2>/dev/null; then
    log_msg "✓ SUCCESS: Process started with nohup (PID: $PID1)"
    START_SUCCESS=1
else
    log_msg "✗ Method 1 failed"
    
    # Method 2: Direct background
    log_msg "Method 2: Trying direct background..."
    "$PYTHON_CMD" localRunner.py > "$LOCAL_LOG" 2>&1 &
    PID2=$!
    sleep 3
    if kill -0 "$PID2" 2>/dev/null; then
        log_msg "✓ SUCCESS: Process started directly (PID: $PID2)"
        START_SUCCESS=1
    else
        log_msg "✗ Method 2 failed"
        
        # Method 3: Screen (if available)
        if command -v screen >/dev/null 2>&1; then
            log_msg "Method 3: Trying with screen..."
            screen -dmS miner_session "$PYTHON_CMD" localRunner.py
            sleep 3
            if screen -list | grep -q miner_session; then
                log_msg "✓ SUCCESS: Process started with screen"
                START_SUCCESS=1
            else
                log_msg "✗ Method 3 failed"
            fi
        fi
    fi
fi

if [ $START_SUCCESS -eq 1 ]; then
    log_msg "LocalRunner.py startup completed successfully"
    
    # Show log output for verification
    if [ -f "$LOCAL_LOG" ]; then
        log_msg "First few lines of localRunner log:"
        head -10 "$LOCAL_LOG" 2>/dev/null | while read -r line; do
            log_msg "  $line"
        done
    fi
else
    log_msg "ERROR: All startup methods failed"
    
    # Show error details
    if [ -f "$LOCAL_LOG" ]; then
        log_msg "Error log contents:"
        cat "$LOCAL_LOG" 2>/dev/null | while read -r line; do
            log_msg "  $line"
        done
    fi
    
    exit 1
fi

log_msg "Simple startup script finished"
