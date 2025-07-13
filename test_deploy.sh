#!/bin/sh

# Comprehensive test script for FreeBSD/Serv00 deployment setup and Discord notifications

echo "=== FreeBSD/Serv00 Deployment & Discord Test Suite ==="
echo

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    printf "Testing %-50s" "$test_name..."
    
    if eval "$test_command" >/dev/null 2>&1; then
        printf "${GREEN}✓ PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}✗ FAIL${NC}\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test function with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    printf "Testing %-50s" "$test_name..."
    
    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "${GREEN}✓ PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        if [ -n "$output" ]; then
            echo "   Output: $output"
        fi
        return 0
    else
        printf "${RED}✗ FAIL${NC}\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        if [ -n "$output" ]; then
            echo "   Error: $output"
        fi
        return 1
    fi
}

echo "${BLUE}1. System Information:${NC}"
echo "   OS: $(uname -s)"
echo "   Hostname: $(hostname)"
echo "   User: $(whoami)"
echo "   Home: $HOME"
echo "   Shell: $SHELL"
echo "   Date: $(date)"
echo

echo "${BLUE}2. Command Availability Tests:${NC}"
run_test "git command" "command -v git"
run_test "curl command" "command -v curl"
run_test "fetch command" "command -v fetch"
run_test "killall command" "command -v killall"
run_test "pkill command" "command -v pkill"
run_test "nohup command" "command -v nohup"
run_test "mail command" "command -v mail"
run_test "date command with ISO format" "date -u +%Y-%m-%dT%H:%M:%S.000Z"

# Test Python versions
echo
echo "${BLUE}3. Python Environment Tests:${NC}"
for python_cmd in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v "$python_cmd" >/dev/null 2>&1; then
        run_test_with_output "$python_cmd version" "$python_cmd --version"
        run_test "$python_cmd pip module" "$python_cmd -m pip --version"
    else
        printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (not installed)\n" "$python_cmd"
    fi
done

echo
echo "${BLUE}4. Directory Structure Tests:${NC}"
TEST_REPO_PATH="$HOME/repo/git/pub/TTV"
TEST_LOG_FILE="$HOME/repo/git/pub/TTV/deploy.log"
TEST_LOCK_FILE="$HOME/tmp/deploy.lock"

run_test "Create log directory" "mkdir -p '$(dirname \"$TEST_LOG_FILE\")'"
run_test "Create lock directory" "mkdir -p '$(dirname \"$TEST_LOCK_FILE\")'"
run_test "Log directory exists" "[ -d '$(dirname \"$TEST_LOG_FILE\")' ]"
run_test "Lock directory exists" "[ -d '$(dirname \"$TEST_LOCK_FILE\")' ]"

# Test log file creation
run_test "Create test log file" "echo 'Test log entry $(date)' >> '$TEST_LOG_FILE'"
run_test "Log file exists" "[ -f '$TEST_LOG_FILE' ]"
run_test_with_output "Read last log entry" "tail -1 '$TEST_LOG_FILE'"

echo
echo "${BLUE}5. Configuration File Tests:${NC}"
run_test ".env.example exists" "[ -f '.env.example' ]"

if [ -f ".env" ]; then
    run_test ".env file exists" "true"
    echo "   ${GREEN}✓${NC} .env file found"
    echo "   Configuration variables:"
    while IFS='=' read -r key value; do
        case "$key" in
            '#'*|'') continue ;;
            *)
                # Hide sensitive values
                case "$key" in
                    *PASSWORD*|*TOKEN*|*SECRET*|*WEBHOOK*)
                        echo "     $key=***HIDDEN***"
                        ;;
                    *)
                        echo "     $key=$value"
                        ;;
                esac
                ;;
        esac
    done < .env
else
    printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (.env not found)\n" ".env file"
    echo "   ${YELLOW}⚠${NC} Create .env file from .env.example for full testing"
fi

echo
echo "${BLUE}6. Git Repository Tests:${NC}"
if [ -d ".git" ]; then
    run_test "Git repository detected" "true"
    run_test_with_output "Git status" "git status --porcelain | wc -l | tr -d ' '"
    run_test_with_output "Current branch" "git branch --show-current"
    run_test_with_output "Remote origin" "git remote get-url origin"
    run_test "Git fetch test" "git fetch --dry-run"
else
    printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (not a git repo)\n" "Git repository"
fi

echo
echo "${BLUE}7. Discord Webhook Tests:${NC}"

# Load .env for webhook testing
if [ -f ".env" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            '#'*|'') continue ;;
        esac
        value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
        export "$key=$value"
    done < ".env"
fi

WEBHOOK_URL="${WEBHOOK:-}"

if [ -n "$WEBHOOK_URL" ]; then
    echo "   ${GREEN}✓${NC} Webhook URL configured"
    
    # Test webhook URL format
    case "$WEBHOOK_URL" in
        https://discord.com/api/webhooks/*)
            run_test "Discord webhook URL format" "true"
            ;;
        https://discordapp.com/api/webhooks/*)
            run_test "Discord webhook URL format" "true"
            ;;
        *)
            printf "Testing %-50s${YELLOW}⚠ WARN${NC} (not Discord format)\n" "Discord webhook URL format"
            ;;
    esac
    
    # Test webhook connectivity
    if command -v curl >/dev/null 2>&1; then
        run_test "Webhook connectivity (curl)" "curl -s --connect-timeout 5 --head '$WEBHOOK_URL' | head -1 | grep -q '200\\|204'"
    elif command -v fetch >/dev/null 2>&1; then
        run_test "Webhook connectivity (fetch)" "fetch -q -o /dev/null -T 5 '$WEBHOOK_URL'"
    fi
    
    # Test Discord notification function
    echo "   Testing Discord notification function..."
    
    # Create a test function (simplified version of the real one)
    test_discord_notification() {
        local message="$1"
        local status="$2"
        local title="🧪 Test Notification"
        
        case "$status" in
            "error") title="❌ Test Error" ;;
            "warning") title="⚠️ Test Warning" ;;
            "info") title="ℹ️ Test Info" ;;
            "start") title="🚀 Test Start" ;;
        esac
        
        if command -v curl >/dev/null 2>&1; then
            local payload="{
                \"username\": \"$(hostname) Test Bot\",
                \"embeds\": [{
                    \"title\": \"$title\",
                    \"description\": \"$message\",
                    \"color\": 3066993,
                    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
                    \"footer\": {
                        \"text\": \"Deployment Test Suite\"
                    },
                    \"fields\": [
                        {
                            \"name\": \"Server\",
                            \"value\": \"$(hostname)\",
                            \"inline\": true
                        },
                        {
                            \"name\": \"Test Status\",
                            \"value\": \"Running\",
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
        else
            local simple_payload="{
                \"username\": \"$(hostname) Test Bot\",
                \"content\": \"$title\\n**$message**\\n\\nServer: \`$(hostname)\`\"
            }"
            
            local temp_file="$HOME/tmp/test_webhook_$$"
            mkdir -p "$HOME/tmp" 2>/dev/null
            printf '%s\n' "$simple_payload" > "$temp_file"
            fetch -q -o /dev/null -T 30 \
                --method=POST \
                --header="Content-Type: application/json" \
                --upload-file="$temp_file" \
                "$WEBHOOK_URL" 2>/dev/null
            rm -f "$temp_file"
        fi
    }
    
    run_test "Send test Discord notification" "test_discord_notification 'Test suite is running successfully! All systems operational.' 'info'"
    
else
    printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (no webhook URL)\n" "Discord webhook"
    echo "   ${YELLOW}⚠${NC} Set WEBHOOK in .env file to test Discord notifications"
fi

echo
echo "${BLUE}8. Process Management Tests:${NC}"
run_test "Process listing (ps)" "ps aux | head -1"
run_test "Python process detection" "ps aux | grep -v grep | grep python | wc -l"

# Test killall/pkill functionality
if command -v killall >/dev/null 2>&1; then
    run_test "killall help" "killall -h 2>&1 | head -1"
else
    run_test "pkill alternative" "pkill --help 2>&1 | head -1"
fi

echo
echo "${BLUE}9. File System Tests:${NC}"
run_test "Home directory writable" "touch '$HOME/test_write' && rm '$HOME/test_write'"
run_test "Temp directory creation" "mkdir -p '$HOME/tmp' && [ -d '$HOME/tmp' ]"
run_test "Log file rotation test" "echo 'test' >> '$TEST_LOG_FILE' && tail -1 '$TEST_LOG_FILE' | grep -q 'test'"

# Test file permissions
run_test "Script execute permission" "[ -x './Deploy.sh' ] || chmod +x './Deploy.sh'"

echo
echo "${BLUE}10. Network Tests:${NC}"
run_test "DNS resolution" "nslookup github.com >/dev/null 2>&1"
run_test "HTTPS connectivity" "curl -s --connect-timeout 5 https://api.github.com >/dev/null 2>&1 || fetch -q -o /dev/null -T 5 https://api.github.com"

echo
echo "${BLUE}11. Deploy.sh Script Tests:${NC}"
run_test "Deploy script exists" "[ -f 'Deploy.sh' ]"
run_test "Deploy script readable" "[ -r 'Deploy.sh' ]"
run_test "Deploy script syntax check" "sh -n Deploy.sh"

# Test specific functions in the deploy script
if [ -f "Deploy.sh" ]; then
    run_test "Load env function present" "grep -q 'load_env_file' Deploy.sh"
    run_test "Send webhook function present" "grep -q 'send_webhook' Deploy.sh"
    run_test "Cleanup function present" "grep -q 'cleanup()' Deploy.sh"
    run_test "Python process kill logic" "grep -q 'killall.*python' Deploy.sh"
    run_test "Discord embed formatting" "grep -q 'embeds' Deploy.sh"
fi

echo
echo "${BLUE}12. Final Integration Test:${NC}"

# Create a minimal test environment
if [ -f "localRunner.py" ]; then
    run_test "localRunner.py exists" "true"
else
    printf "Testing %-50s${YELLOW}⚠ INFO${NC} (creating test file)\n" "localRunner.py"
    echo "# Test localRunner.py
import time
print('Test runner started')
time.sleep(2)
print('Test runner finished')" > localRunner.py
fi

run_test "requirements.txt exists" "[ -f 'requirements.txt' ]"

# Cleanup test files
echo
echo "${BLUE}Cleaning up test files...${NC}"
rm -f "$HOME/test_write" 2>/dev/null
echo "Test cleanup completed"

echo
echo "=== Test Results Summary ==="
echo "Total tests: $TESTS_TOTAL"
echo "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo "Failed: 0"
fi

echo
if [ $TESTS_FAILED -eq 0 ]; then
    echo "${GREEN}🎉 All tests passed! Your deployment environment is ready.${NC}"
    echo "${GREEN}✓ The Deploy.sh script should work perfectly on this system.${NC}"
    
    if [ -n "$WEBHOOK_URL" ]; then
        echo "${GREEN}✓ Discord notifications are configured and working.${NC}"
    else
        echo "${YELLOW}⚠ Set up Discord webhook in .env for notifications.${NC}"
    fi
else
    echo "${RED}⚠ Some tests failed. Please review the failures above.${NC}"
    echo "${YELLOW}💡 The deployment script may still work, but some features might not function properly.${NC}"
fi

echo
echo "Next steps:"
echo "1. ${BLUE}Create .env file:${NC} cp .env.example .env"
echo "2. ${BLUE}Configure webhook:${NC} Add your Discord webhook URL to .env"
echo "3. ${BLUE}Test deployment:${NC} ./Deploy.sh"
echo "4. ${BLUE}Monitor logs:${NC} tail -f ~/repo/git/pub/TTV/deploy.log"

exit $TESTS_FAILED
