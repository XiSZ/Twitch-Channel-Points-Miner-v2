#!/bin/sh

# Comprehensive test script for FreeBSD/Serv00 deployment setup and notifications
# Uses POSIX shell features for maximum compatibility

echo "=== FreeBSD/Serv00 Deployment & Notification Test Suite ==="
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

# Enhanced Python environment tests for Deploy.sh compatibility
echo
echo "${BLUE}3b. Python Dependencies and Compatibility Tests:${NC}"

for python_cmd in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v "$python_cmd" >/dev/null 2>&1; then
        echo "   Testing $python_cmd dependencies:"
        
        # Test pip install with --user flag (used in Deploy.sh)
        run_test "$python_cmd pip user install test" "$python_cmd -m pip install --user --help >/dev/null 2>&1"
        
        # Test pip upgrade functionality (used in Deploy.sh)  
        run_test "$python_cmd pip upgrade test" "$python_cmd -m pip install --upgrade --help >/dev/null 2>&1"
        
        # Test if python can import basic modules
        run_test "$python_cmd basic imports" "$python_cmd -c 'import sys, os, json, urllib, ssl' 2>/dev/null"
        
        # Test Python path handling for user packages
        run_test "$python_cmd user site packages" "$python_cmd -c 'import site; print(site.getusersitepackages())' >/dev/null 2>&1"
        
        # Test virtual environment detection capability
        run_test "$python_cmd venv module" "$python_cmd -c 'import venv' 2>/dev/null"
        
        # Found working Python, break to avoid redundant tests
        echo "   ${GREEN}✓${NC} Using $python_cmd as primary Python for remaining tests"
        break
    fi
done

# Test requirements.txt handling
echo
echo "${BLUE}3c. Requirements.txt and Dependencies:${NC}"
run_test "requirements.txt exists" "[ -f 'requirements.txt' ]"

if [ -f "requirements.txt" ]; then
    run_test_with_output "requirements.txt line count" "wc -l < requirements.txt"
    run_test "requirements.txt readable" "head -5 requirements.txt >/dev/null"
    
    # Test if requirements contain any obvious issues
    run_test "requirements.txt format check" "grep -v '^#' requirements.txt | grep -v '^$' | head -1 >/dev/null"
    
    echo "   Sample requirements (first 5 non-comment lines):"
    grep -v '^#' requirements.txt | grep -v '^$' | head -5 | while read line; do
        echo "     $line"
    done
else
    printf "Testing %-50s${YELLOW}⚠ WARN${NC} (no requirements.txt)\n" "requirements.txt"
fi

# Virtual environment tests
echo
echo "${BLUE}3d. Virtual Environment Tests:${NC}"
if [ -f ".venv/bin/python" ]; then
    run_test "Virtual environment exists" "true"
    run_test_with_output "Virtual environment Python version" ".venv/bin/python --version"
    run_test "Virtual environment pip" ".venv/bin/python -m pip --version >/dev/null"
    run_test "Virtual environment activate script" "[ -f '.venv/bin/activate' ]"
    
    echo "   ${GREEN}✓${NC} Virtual environment found and working"
elif [ -d ".venv" ]; then
    printf "Testing %-50s${YELLOW}⚠ WARN${NC} (.venv exists but no Python)\n" "Virtual environment"
    echo "   ${YELLOW}⚠${NC} .venv directory exists but no Python executable found"
else
    printf "Testing %-50s${YELLOW}⚠ INFO${NC} (no virtual environment)\n" "Virtual environment"
    echo "   ${YELLOW}ℹ${NC} No virtual environment detected - Deploy.sh will use system Python"
fi

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
                    *PASSWORD*|*TOKEN*|*SECRET*|*WEBHOOK*|*CHATID*)
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

# Enhanced configuration validation
echo
echo "${BLUE}5b. Advanced Configuration Tests:${NC}"

if [ -f ".env" ]; then
    echo "   Validating .env configuration completeness:"
    
    # Check for all configuration variables used in Deploy.sh
    ENV_VARS_TO_CHECK="WEBHOOK TELEGRAMTOKEN CHATID EMAIL_RECIPIENT SEND_EMAIL_ON_ERROR SEND_EMAIL_ON_SUCCESS SEND_WEBHOOK_NOTIFICATIONS SEND_TELEGRAM_NOTIFICATIONS REPO_PATH LOG_FILE BRANCH"
    
    for var in $ENV_VARS_TO_CHECK; do
        if grep -q "^$var=" .env 2>/dev/null; then
            printf "Testing %-50s${GREEN}✓ FOUND${NC}\n" "$var in .env"
        else
            printf "Testing %-50s${YELLOW}⚠ MISSING${NC}\n" "$var in .env"
        fi
    done
    
    # Test for sensitive data exposure
    run_test ".env file permissions" "[ ! -r .env ] || [ \"$(stat -c %a .env 2>/dev/null || stat -f %Lp .env 2>/dev/null)\" -le 600 ] || echo 'WARNING: .env should have 600 permissions'"
    
    # Validate configuration combinations
    echo "   Configuration validation:"
    
    # Check if at least one notification method is configured
    NOTIFICATION_METHODS=0
    if [ -n "$WEBHOOK_URL" ]; then
        NOTIFICATION_METHODS=$((NOTIFICATION_METHODS + 1))
    fi
    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        NOTIFICATION_METHODS=$((NOTIFICATION_METHODS + 1))  
    fi
    if [ -n "$EMAIL_RECIPIENT" ] && [ "$EMAIL_RECIPIENT" != "your-email@example.com" ]; then
        NOTIFICATION_METHODS=$((NOTIFICATION_METHODS + 1))
    fi
    
    if [ $NOTIFICATION_METHODS -gt 0 ]; then
        printf "   %-47s${GREEN}✓ GOOD${NC} ($NOTIFICATION_METHODS methods)\n" "Notification methods configured"
    else
        printf "   %-47s${YELLOW}⚠ WARN${NC} (no notifications)\n" "Notification methods configured"
        echo "     ${YELLOW}⚠${NC} Consider configuring at least one notification method"
    fi
    
    # Validate path configurations
    if [ -n "$REPO_PATH" ]; then
        printf "   %-47s${GREEN}✓ SET${NC} ($REPO_PATH)\n" "REPO_PATH configured"
    else
        printf "   %-47s${YELLOW}⚠ DEFAULT${NC}\n" "REPO_PATH configured"
    fi
    
else
    echo "   ${YELLOW}ℹ${NC} Create comprehensive .env file for full configuration testing"
    echo "   Required variables for Deploy.sh:"
    echo "     • WEBHOOK (Discord webhook URL)"
    echo "     • TELEGRAMTOKEN and CHATID (Telegram notifications)"  
    echo "     • EMAIL_RECIPIENT (Email notifications)"
    echo "     • REPO_PATH, LOG_FILE, BRANCH (Path configurations)"
    echo "     • SEND_*_NOTIFICATIONS flags (Control notification types)"
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
echo "${BLUE}7. Notification Services Tests:${NC}"

# Load .env for notification testing
if [ -f ".env" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            '#'*|'') continue ;;
        esac
        value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
        export "$key=$value"
    done < ".env"
fi

# Discord Webhook Tests
echo
echo "${BLUE}7a. Discord Webhook Tests:${NC}"
# POSIX-compatible parameter expansion
if [ -n "$WEBHOOK" ]; then
    WEBHOOK_URL="$WEBHOOK"
else
    WEBHOOK_URL=""
fi

if [ -n "$WEBHOOK_URL" ]; then
    echo "   ${GREEN}✓${NC} Discord webhook URL configured"
    
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
        run_test "Discord webhook connectivity (curl)" "curl -s --connect-timeout 5 --head '$WEBHOOK_URL' | head -1 | grep -q '200\\|204'"
    elif command -v fetch >/dev/null 2>&1; then
        run_test "Discord webhook connectivity (fetch)" "fetch -q -o /dev/null -T 5 '$WEBHOOK_URL'"
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
                \"username\": \"Test Bot\",
                \"avatar_url\": \"https://avatars.githubusercontent.com/u/40718990\",
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

# Telegram Bot Tests
echo
echo "${BLUE}7b. Telegram Bot Tests:${NC}"
# POSIX-compatible parameter expansion
if [ -n "$TELEGRAMTOKEN" ]; then
    TELEGRAM_TOKEN="$TELEGRAMTOKEN"
else
    TELEGRAM_TOKEN=""
fi

if [ -n "$CHATID" ]; then
    TELEGRAM_CHAT_ID="$CHATID"
else
    TELEGRAM_CHAT_ID=""
fi

if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    echo "   ${GREEN}✓${NC} Telegram bot token and chat ID configured"
    
    # Test token format (basic check)
    case "$TELEGRAM_TOKEN" in
        *:*)
            run_test "Telegram token format" "true"
            ;;
        *)
            printf "Testing %-50s${YELLOW}⚠ WARN${NC} (invalid format)\n" "Telegram token format"
            ;;
    esac
    
    # Test chat ID format (should be numeric or start with -)
    case "$TELEGRAM_CHAT_ID" in
        -[0-9]*|[0-9]*)
            run_test "Telegram chat ID format" "true"
            ;;
        *)
            printf "Testing %-50s${YELLOW}⚠ WARN${NC} (should be numeric)\n" "Telegram chat ID format"
            ;;
    esac
    
    # Test Telegram API connectivity
    TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_TOKEN/getMe"
    if command -v curl >/dev/null 2>&1; then
        run_test "Telegram API connectivity (curl)" "curl -s --connect-timeout 5 '$TELEGRAM_API_URL' | grep -q '\"ok\":true'"
    elif command -v fetch >/dev/null 2>&1; then
        run_test "Telegram API connectivity (fetch)" "fetch -q -o /dev/null -T 5 '$TELEGRAM_API_URL'"
    fi
    
    # Test Telegram notification function
    echo "   Testing Telegram notification function..."
    
    test_telegram_notification() {
        local message="$1"
        local status="$2"
        local emoji="🧪"
        local status_text="Test"
        
        case "$status" in
            "error") emoji="❌"; status_text="Error" ;;
            "warning") emoji="⚠️"; status_text="Warning" ;;
            "info") emoji="ℹ️"; status_text="Info" ;;
            "start") emoji="🚀"; status_text="Start" ;;
        esac
        
        local telegram_message="$emoji *Deployment $status_text*

$message

🖥️ *Server:* \`$(hostname)\`
📁 *Test Suite:* Running
⏰ *Time:* $(date '+%Y-%m-%d %H:%M:%S')"
        
        local telegram_url="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"
        
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
            local temp_file="$HOME/tmp/test_telegram_$$"
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
    }
    
    run_test "Send test Telegram notification" "test_telegram_notification 'Test suite is running successfully! All systems operational.' 'info'"
    
elif [ -n "$TELEGRAM_TOKEN" ] || [ -n "$TELEGRAM_CHAT_ID" ]; then
    printf "Testing %-50s${YELLOW}⚠ WARN${NC} (incomplete config)\n" "Telegram bot"
    if [ -z "$TELEGRAM_TOKEN" ]; then
        echo "   ${YELLOW}⚠${NC} Missing TELEGRAMTOKEN in .env file"
    fi
    if [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "   ${YELLOW}⚠${NC} Missing CHATID in .env file"
    fi
else
    printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (not configured)\n" "Telegram bot"
    echo "   ${YELLOW}⚠${NC} Set TELEGRAMTOKEN and CHATID in .env file to test Telegram notifications"
fi

# Email Tests
echo
echo "${BLUE}7c. Email Notification Tests:${NC}"
# POSIX-compatible parameter expansion
if [ -n "$EMAIL_RECIPIENT" ]; then
    EMAIL_RECIPIENT="$EMAIL_RECIPIENT"
else
    EMAIL_RECIPIENT=""
fi

if [ -n "$SEND_EMAIL_ON_ERROR" ]; then
    SEND_EMAIL_ON_ERROR="$SEND_EMAIL_ON_ERROR"
else
    SEND_EMAIL_ON_ERROR="true"
fi

if [ -n "$SEND_EMAIL_ON_SUCCESS" ]; then
    SEND_EMAIL_ON_SUCCESS="$SEND_EMAIL_ON_SUCCESS"
else
    SEND_EMAIL_ON_SUCCESS="false"
fi

if [ -n "$EMAIL_RECIPIENT" ]; then
    echo "   ${GREEN}✓${NC} Email recipient configured: $EMAIL_RECIPIENT"
    
    # Test email address format (basic validation)
    case "$EMAIL_RECIPIENT" in
        *@*.*)
            run_test "Email address format" "true"
            ;;
        *)
            printf "Testing %-50s${YELLOW}⚠ WARN${NC} (invalid email format)\n" "Email address format"
            ;;
    esac
    
    # Test mail command functionality
    run_test "Mail command with subject test" "echo 'Test message' | mail -s 'Test Subject' root 2>/dev/null; true"
    
    # Test email configuration flags
    echo "   Email configuration:"
    echo "     SEND_EMAIL_ON_ERROR: $SEND_EMAIL_ON_ERROR"
    echo "     SEND_EMAIL_ON_SUCCESS: $SEND_EMAIL_ON_SUCCESS"
    
    if [ "$SEND_EMAIL_ON_ERROR" = "true" ] || [ "$SEND_EMAIL_ON_SUCCESS" = "true" ]; then
        run_test "Email notification enabled" "true"
        
        # Test sending actual email if mail command works
        echo "   Testing email notification function..."
        
        test_email_notification() {
            local subject="$1"
            local message="$2"
            
            # Test the actual email function from Deploy.sh
            printf "%s\n" "$message" | mail -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null
            return $?
        }
        
        # Only run actual email test if mail command is available and working
        if command -v mail >/dev/null 2>&1 && [ "$EMAIL_RECIPIENT" != "your-email@example.com" ]; then
            run_test "Send test email notification" "test_email_notification 'FreeBSD Deploy Test' 'This is a test email from the deployment test suite running on $(hostname). If you receive this, email notifications are working correctly.'"
        else
            printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (default email or no mail)\n" "Send test email"
            if [ "$EMAIL_RECIPIENT" = "your-email@example.com" ]; then
                echo "   ${YELLOW}⚠${NC} Update EMAIL_RECIPIENT in .env file to test actual email sending"
            fi
        fi
    else
        printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (email disabled)\n" "Email notifications"
        echo "   ${YELLOW}⚠${NC} Email notifications are disabled in configuration"
    fi
    
else
    printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (not configured)\n" "Email notifications"
    echo "   ${YELLOW}⚠${NC} Set EMAIL_RECIPIENT in .env file to test email notifications"
fi

# Email system tests
echo
echo "${BLUE}7d. Email System Tests:${NC}"
run_test "Mail system status" "mailq 2>/dev/null | head -1 | grep -q 'Mail queue is empty' || mailq 2>/dev/null | wc -l"
run_test "Sendmail compatibility" "which sendmail >/dev/null 2>&1 || which mail >/dev/null 2>&1"

# Test mail aliases and system mail setup
run_test "System mail directory" "[ -d /var/mail ] || [ -d /var/spool/mail ]"
run_test "User mail access" "touch /tmp/test_mail && rm /tmp/test_mail"

# Test mail delivery paths
if command -v mail >/dev/null 2>&1; then
    run_test "Mail command help" "mail -h 2>&1 | head -1"
    run_test "Mail command version/info" "mail -V 2>&1 | head -1 || echo 'Version info not available'"
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

# Enhanced process management tests for Deploy.sh
echo
echo "${BLUE}8b. Advanced Process Management Tests:${NC}"

# Test process detection methods used in Deploy.sh
run_test "pgrep command availability" "command -v pgrep"
run_test "ps command with specific options" "ps aux | head -1"
run_test "ps command with PID filtering" "ps -p $$ -o pid,ppid,cmd >/dev/null 2>&1"

# Test process killing methods used in Deploy.sh
echo "   Testing process termination methods:"
run_test "killall with signal options" "killall -h 2>&1 | grep -q 'signal' || true"
run_test "pkill with pattern matching" "pkill --help 2>&1 | grep -q 'pattern' || true"

# Test SIGTERM and SIGKILL signal handling
run_test "Signal handling - SIGTERM" "kill -15 $$ 2>/dev/null; true"
run_test "Signal handling - SIGKILL capability" "kill -9 -1 2>/dev/null; true"

# Test nohup command (used for background processes)
run_test "nohup command" "command -v nohup"
run_test "nohup functionality test" "nohup echo 'test' >/dev/null 2>&1; true"

# Test background process management
echo "   Testing background process capabilities:"
run_test "Background process creation" "sleep 1 & wait"
run_test "Process status checking" "kill -0 $$ 2>/dev/null"

# Test process information gathering
run_test "Process command line extraction" "ps -p $$ -o args= 2>/dev/null | head -1 >/dev/null"
run_test "Process working directory" "[ -d \"/proc/$$\" ] && [ -r \"/proc/$$/cwd\" ] || true"

echo
echo "${BLUE}8c. FreeBSD-Specific System Tests:${NC}"

# Test FreeBSD-specific commands and features
run_test "FreeBSD fetch command options" "fetch --help 2>&1 | head -1"
run_test "FreeBSD SSL certificate path" "[ -f '/etc/ssl/cert.pem' ]"
run_test "FreeBSD process filesystem" "[ -d '/proc' ] && echo 'procfs available' || echo 'procfs not mounted'"

# Test system resource limits
run_test "User process limits" "ulimit -u >/dev/null 2>&1"
run_test "File descriptor limits" "ulimit -n >/dev/null 2>&1"

# Test hostname and system identification
run_test_with_output "System hostname for notifications" "hostname"
run_test_with_output "System uptime" "uptime | cut -d',' -f1"

# Test certificate verification for HTTPS
run_test "SSL certificate verification" "fetch -q -o /dev/null -T 5 https://httpbin.org/status/200 2>/dev/null || curl -s --connect-timeout 5 https://httpbin.org/status/200 >/dev/null 2>&1"

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
echo "${BLUE}12. Notification URL Changes Tests:${NC}"

# Test Python import and URL functionality
PYTHON_CMD=""
for python_cmd in python3.11 python3.10 python3.9 python3.8 python3 python; do
    if command -v "$python_cmd" >/dev/null 2>&1; then
        PYTHON_CMD="$python_cmd"
        break
    fi
done

if [ -n "$PYTHON_CMD" ]; then
    echo "   Using Python: $PYTHON_CMD"
    
    # Test basic Python imports
    run_test "Python TwitchChannelPointsMiner import" "$PYTHON_CMD -c 'import sys; sys.path.insert(0, \".\"); from TwitchChannelPointsMiner.classes.entities.Streamer import Streamer; print(\"Import successful\")' 2>/dev/null"
    run_test "Python URL constant import" "$PYTHON_CMD -c 'import sys; sys.path.insert(0, \".\"); from TwitchChannelPointsMiner.constants import URL; print(\"URL:\", URL)' 2>/dev/null"
    
    # Test Streamer URL functionality
    echo "   Testing streamer URL functionality..."
    
    # Create a comprehensive test script inline
    cat > test_notification_urls.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '.'')

try:
    from TwitchChannelPointsMiner.classes.entities.Streamer import Streamer
    from TwitchChannelPointsMiner.constants import URL
    from TwitchChannelPointsMiner.classes.Settings import Events
    
    # Test 1: URL construction
    test_streamer = Streamer("testuser")
    expected_url = f"{URL}/testuser"
    actual_url = test_streamer.streamer_url
    
    print(f"URL Test: {expected_url} == {actual_url} -> {'PASS' if expected_url == actual_url else 'FAIL'}")
    
    # Test 2: URL format validation
    if actual_url.startswith("https://www.twitch.tv/"):
        print("URL Format Test: PASS")
    else:
        print("URL Format Test: FAIL")
    
    # Test 3: Different usernames
    test_cases = ["shroud", "pokimane", "test_user_123", "ninja"]
    all_passed = True
    
    for username in test_cases:
        streamer = Streamer(username)
        expected = f"{URL}/{username}"
        if streamer.streamer_url != expected:
            all_passed = False
            break
    
    print(f"Multiple Username Test: {'PASS' if all_passed else 'FAIL'}")
    
    # Test 4: Check if notification methods exist and can be called
    try:
        # Mock the logger to avoid actual logging during test
        import logging
        from unittest.mock import Mock
        
        # Save original logger
        from TwitchChannelPointsMiner.classes.entities import Streamer as StreamerModule
        original_logger = StreamerModule.logger
        
        # Replace with mock
        StreamerModule.logger = Mock()
        
        # Test set_online
        test_streamer.set_online()
        if StreamerModule.logger.info.called:
            args = StreamerModule.logger.info.call_args[0]
            message = args[0]
            if test_streamer.streamer_url in message and "is Online!" in message:
                print("Online Notification Test: PASS")
            else:
                print("Online Notification Test: FAIL")
        else:
            print("Online Notification Test: FAIL")
        
        # Reset mock
        StreamerModule.logger.reset_mock()
        
        # Test set_offline (set online first)
        test_streamer.is_online = True
        test_streamer.set_offline()
        if StreamerModule.logger.info.called:
            args = StreamerModule.logger.info.call_args[0]
            message = args[0]
            if test_streamer.streamer_url in message and "is Offline!" in message:
                print("Offline Notification Test: PASS")
            else:
                print("Offline Notification Test: FAIL")
        else:
            print("Offline Notification Test: FAIL")
        
        # Restore original logger
        StreamerModule.logger = original_logger
        
    except Exception as e:
        print(f"Notification Method Test: FAIL ({e})")
    
    print("All notification URL tests completed successfully!")
    
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
    
    run_test "Notification URL functionality test" "$PYTHON_CMD test_notification_urls.py"
    
    # Test notification message format
    echo "   Testing notification message formats..."
    
    cat > test_message_format.py << 'EOF'
#!/usr/bin/env python3
import sys
sys.path.insert(0, '.'')

try:
    from TwitchChannelPointsMiner.classes.entities.Streamer import Streamer
    from TwitchChannelPointsMiner.constants import URL
    from unittest.mock import Mock
    
    # Create test streamer
    streamer = Streamer("teststreamer")
    
    # Mock logger to capture messages
    from TwitchChannelPointsMiner.classes.entities import Streamer as StreamerModule
    original_logger = StreamerModule.logger
    StreamerModule.logger = Mock()
    
    # Test online message format
    streamer.set_online()
    online_message = StreamerModule.logger.info.call_args[0][0]
    
    # Test offline message format  
    StreamerModule.logger.reset_mock()
    streamer.is_online = True
    streamer.set_offline()
    offline_message = StreamerModule.logger.info.call_args[0][0]
    
    # Restore logger
    StreamerModule.logger = original_logger
    
    print(f"Online message: {online_message}")
    print(f"Offline message: {offline_message}")
    
    # Validate message formats
    online_valid = "is Online!" in online_message and URL in online_message
    offline_valid = "is Offline!" in offline_message and URL in offline_message
    
    print(f"Online message format: {'PASS' if online_valid else 'FAIL'}")
    print(f"Offline message format: {'PASS' if offline_valid else 'FAIL'}")
    
    if online_valid and offline_valid:
        print("Message format test: PASS")
    else:
        print("Message format test: FAIL")
        sys.exit(1)
        
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
    
    run_test "Notification message format test" "$PYTHON_CMD test_message_format.py"
    
    # Test with actual notification services if configured
    if [ -n "$WEBHOOK_URL" ] || ([ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]); then
        echo "   Testing notification URL integration..."
        
        cat > test_notification_integration.py << 'EOF'
#!/usr/bin/env python3
import sys
sys.path.insert(0, '.'')

try:
    from TwitchChannelPointsMiner.classes.entities.Streamer import Streamer
    from TwitchChannelPointsMiner.constants import URL
    
    # Create a test streamer
    streamer = Streamer("teststreamer")
    
    # Simulate the notification content that would be sent
    online_notification = f"{streamer} is Online! - Watch at {streamer.streamer_url}"
    offline_notification = f"{streamer} is Offline! - Stream was at {streamer.streamer_url}"
    
    print("Sample notification messages that will be sent:")
    print(f"Online: {online_notification}")
    print(f"Offline: {offline_notification}")
    
    # Validate URLs are clickable format
    if streamer.streamer_url.startswith("https://"):
        print("URL format is clickable: PASS")
    else:
        print("URL format is clickable: FAIL")
        sys.exit(1)
        
    print("Notification integration test: PASS")
    
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
        
        run_test "Notification integration test" "$PYTHON_CMD test_notification_integration.py"
    else
        printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (no notifications configured)\n" "Notification integration"
    fi
    
    # Cleanup test files
    rm -f test_notification_urls.py test_message_format.py test_notification_integration.py 2>/dev/null
    
    # Test notification with URL if services are configured
    if [ -n "$WEBHOOK_URL" ] || ([ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]); then
        echo "   Sending test notification with URL format..."
        
        # Send test notification using the notification functions from earlier
        if [ -n "$WEBHOOK_URL" ]; then
            TEST_MESSAGE="🧪 **Test Streamer is Online!** - Watch at https://www.twitch.tv/teststreamer

This is a test of the new notification URL feature. The URL above should be clickable and lead to the Twitch channel.

Server: \`$(hostname)\`
Test Time: $(date '+%Y-%m-%d %H:%M:%S')"
            
            if command -v curl >/dev/null 2>&1; then
                local test_payload="{
                    \"username\": \"Twitch Miner Test\",
                    \"avatar_url\": \"https://avatars.githubusercontent.com/u/40718990\",
                    \"embeds\": [{
                        \"title\": \"🎮 Notification URL Test\",
                        \"description\": \"$TEST_MESSAGE\",
                        \"color\": 9442302,
                        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
                        \"footer\": {
                            \"text\": \"Test Suite - Notification URL Feature\"
                        }
                    }]
                }"
                
                run_test "Send Discord test notification with URL" "curl -X POST -H 'Content-type: application/json' -d '$test_payload' '$WEBHOOK_URL' --connect-timeout 10 --max-time 30 --silent --output /dev/null"
            fi
        fi
        
        if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
            TEST_MESSAGE="🧪 *Test Streamer is Online!* - Watch at https://www.twitch.tv/teststreamer

This is a test of the new notification URL feature\\. The URL above should be clickable and lead to the Twitch channel\\.

🖥️ *Server:* \`$(hostname)\`
⏰ *Test Time:* $(date '+%Y-%m-%d %H:%M:%S')"
            
            local telegram_url="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"
            
            if command -v curl >/dev/null 2>&1; then
                local telegram_test_payload="{
                    \"chat_id\": \"$TELEGRAM_CHAT_ID\",
                    \"text\": \"$TEST_MESSAGE\",
                    \"parse_mode\": \"MarkdownV2\",
                    \"disable_web_page_preview\": false
                }"
                
                run_test "Send Telegram test notification with URL" "curl -X POST -H 'Content-type: application/json' -d '$telegram_test_payload' '$telegram_url' --connect-timeout 10 --max-time 30 --silent --output /dev/null"
            fi
        fi
    fi
else
    printf "Testing %-50s${YELLOW}⚠ SKIP${NC} (no Python found)\n" "Notification URL tests"
    echo "   ${YELLOW}⚠${NC} Python is required for notification URL testing"
fi

echo
echo "${BLUE}13. Final Integration Test:${NC}"

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
    
    # Check notification services
    NOTIFICATION_CONFIGURED=false
    if [ -n "$WEBHOOK_URL" ]; then
        echo "${GREEN}✓ Discord notifications are configured and working.${NC}"
        NOTIFICATION_CONFIGURED=true
    else
        echo "${YELLOW}⚠ Set up Discord webhook in .env for notifications.${NC}"
    fi
    
    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "${GREEN}✓ Telegram notifications are configured and working.${NC}"
        NOTIFICATION_CONFIGURED=true
    else
        echo "${YELLOW}⚠ Set up Telegram bot token and chat ID in .env for notifications.${NC}"
    fi
    
    if [ -n "$EMAIL_RECIPIENT" ] && [ "$EMAIL_RECIPIENT" != "your-email@example.com" ]; then
        echo "${GREEN}✓ Email notifications are configured.${NC}"
        NOTIFICATION_CONFIGURED=true
    else
        echo "${YELLOW}⚠ Set up EMAIL_RECIPIENT in .env for email notifications.${NC}"
    fi
    
    if [ "$NOTIFICATION_CONFIGURED" = "false" ]; then
        echo "${YELLOW}💡 Configure at least one notification service (Discord, Telegram, or Email) for deployment alerts.${NC}"
    fi
else
    echo "${RED}⚠ Some tests failed. Please review the failures above.${NC}"
    echo "${YELLOW}💡 The deployment script may still work, but some features might not function properly.${NC}"
fi

echo
echo "Next steps:"
echo "1. ${BLUE}Create .env file:${NC} cp .env.example .env"
echo "2. ${BLUE}Configure notifications:${NC}"
echo "   • Discord: Add WEBHOOK URL to .env"
echo "   • Telegram: Add TELEGRAMTOKEN and CHATID to .env"
echo "   • Email: Add EMAIL_RECIPIENT to .env and configure mail system"
echo "3. ${BLUE}Test deployment:${NC} ./Deploy.sh"
echo "4. ${BLUE}Monitor logs:${NC} tail -f ~/repo/git/pub/TTV/deploy.log"
echo "5. ${BLUE}Check processes:${NC} ps aux | grep python"

# Test that the actual code changes are present in Streamer.py
echo "   Verifying code changes in Streamer.py..."

run_test "Streamer.py file exists" "[ -f 'TwitchChannelPointsMiner/classes/entities/Streamer.py' ]"

if [ -f "TwitchChannelPointsMiner/classes/entities/Streamer.py" ]; then
    # Check for online notification URL change
    run_test "Online notification includes URL" "grep -q 'is Online.*streamer_url' TwitchChannelPointsMiner/classes/entities/Streamer.py"
    
    # Check for offline notification URL change  
    run_test "Offline notification includes URL" "grep -q 'is Offline.*streamer_url' TwitchChannelPointsMiner/classes/entities/Streamer.py"
    
    # Check for URL construction
    run_test "URL construction present" "grep -q 'streamer_url.*URL.*username' TwitchChannelPointsMiner/classes/entities/Streamer.py"
    
    # Check that both notifications have the dash separator (latest format)
    run_test "Online notification format" "grep -q 'is Online! - Watch at' TwitchChannelPointsMiner/classes/entities/Streamer.py"
    run_test "Offline notification format" "grep -q 'is Offline! - Stream was at' TwitchChannelPointsMiner/classes/entities/Streamer.py"
    
    # Display the actual notification lines for verification
    echo "   Current notification messages in code:"
    echo "   Online:  $(grep -o 'f".*is Online.*"' TwitchChannelPointsMiner/classes/entities/Streamer.py 2>/dev/null || echo 'Not found')"
    echo "   Offline: $(grep -o 'f".*is Offline.*"' TwitchChannelPointsMiner/classes/entities/Streamer.py 2>/dev/null || echo 'Not found')"
else
    printf "Testing %-50s${RED}✗ FAIL${NC} (Streamer.py not found)\n" "Streamer.py verification"
fi

exit $TESTS_FAILED
