#!/bin/sh

# Test script for FreeBSD/Serv00 deployment setup

echo "=== FreeBSD/Serv00 Deployment Test ==="
echo

# Test 1: Environment detection
echo "1. System Information:"
echo "   OS: $(uname -s)"
echo "   Hostname: $(hostname)"
echo "   User: $(whoami)"
echo "   Home: $HOME"
echo

# Test 2: Required commands
echo "2. Command availability:"
for cmd in git curl fetch python python3 python3.8 python3.9 python3.10 python3.11; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "   ✓ $cmd: $(command -v "$cmd")"
    else
        echo "   ✗ $cmd: not found"
    fi
done
echo

# Test 3: Python environment
echo "3. Python environment:"
for python_cmd in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v "$python_cmd" >/dev/null 2>&1; then
        version=$("$python_cmd" --version 2>&1)
        echo "   ✓ $python_cmd: $version"
        pip_version=$("$python_cmd" -m pip --version 2>&1 | head -1)
        echo "     pip: $pip_version"
        break
    fi
done
echo

# Test 4: Directory setup
echo "4. Directory setup test:"
TEST_REPO_PATH="$HOME/repo/git/pub/TTV"
TEST_LOG_FILE="$HOME/repo/git/pub/TTV/deploy.log"

echo "   Testing directory creation..."
mkdir -p "$(dirname "$TEST_LOG_FILE")" 2>/dev/null
if [ -d "$(dirname "$TEST_LOG_FILE")" ]; then
    echo "   ✓ Log directory: $(dirname "$TEST_LOG_FILE")"
else
    echo "   ✗ Failed to create log directory"
fi

# Test 5: Log file creation
echo "   Testing log file creation..."
echo "Test log entry $(date)" >> "$TEST_LOG_FILE" 2>/dev/null
if [ -f "$TEST_LOG_FILE" ]; then
    echo "   ✓ Log file: $TEST_LOG_FILE"
    echo "   Last entry: $(tail -1 "$TEST_LOG_FILE")"
else
    echo "   ✗ Failed to create log file"
fi
echo

# Test 6: .env file detection
echo "5. Configuration:"
if [ -f ".env" ]; then
    echo "   ✓ .env file found"
    echo "   Variables in .env:"
    grep -v '^#' .env | grep -v '^$' | while read line; do
        echo "     $line"
    done
else
    echo "   ✗ .env file not found"
    echo "   Create .env file from .env.example for configuration"
fi
echo

echo "=== Test Complete ==="
echo "If all tests passed, the deployment script should work on this system."
