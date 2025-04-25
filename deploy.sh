#!/bin/bash

# Script for automatic deployment of Telegram bot on a VPS server
# Make sure the script is run with root privileges

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse command line arguments
BOT_TOKEN=""
INTERACTIVE=false # Default to non-interactive mode
while [[ $# -gt 0 ]]; do
    case $1 in
        --token=*)
            BOT_TOKEN="${1#*=}"
            shift
            ;;
        --token)
            BOT_TOKEN="$2"
            shift 2
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo -e "Usage: $0 [--token=YOUR_BOT_TOKEN] [--interactive] or $0 [--token YOUR_BOT_TOKEN] [--interactive]"
            exit 1
            ;;
    esac
done

# Check if token was provided
if [ -z "$BOT_TOKEN" ]; then
    echo -e "${YELLOW}No bot token provided. The bot will use the default token or look for BOT_TOKEN environment variable.${NC}"
    echo -e "${YELLOW}To provide a token, use: $0 --token=YOUR_BOT_TOKEN${NC}"
    
    if $INTERACTIVE; then
        read -p "Continue without specifying a token? (yes/no): " continue_without_token
        if [[ ! "$continue_without_token" =~ ^(yes|y)$ ]]; then
            echo -e "${RED}Deployment cancelled.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Automated mode: continuing without token${NC}"
    fi
fi

# Directory setup
BOT_DIR="/root/telegram-bots/quit-smoking-assistant"

# Configure Git to ignore permission changes
echo -e "${YELLOW}Checking Git settings...${NC}"
if [ -d "$BOT_DIR/.git" ]; then
    # Check if core.fileMode false is already set
    FILEMODE=$(git -C $BOT_DIR config --get core.fileMode)
    if [ "$FILEMODE" = "false" ]; then
        echo -e "${GREEN}Git is already configured to ignore permission changes${NC}"
    else
        echo -e "${YELLOW}Configuring Git to ignore permission changes...${NC}"
        git -C $BOT_DIR config core.fileMode false
        echo -e "${GREEN}Git is configured to ignore permission changes${NC}"
    fi
else
    echo -e "${YELLOW}Git directory not found in $BOT_DIR, skipping Git configuration${NC}"
fi

echo -e "${GREEN}=== Starting bot setup... ===${NC}"

# 2. Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"

# List of required packages
PACKAGES=("python3" "python3-pip" "python3-venv" "git")
PACKAGES_TO_INSTALL=()

# Check each package
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        PACKAGES_TO_INSTALL+=("$pkg")
    else
        echo -e "${GREEN}Package $pkg is already installed${NC}"
    fi
done

# Install only missing packages
if [ ${#PACKAGES_TO_INSTALL[@]} -ne 0 ]; then
    echo -e "${YELLOW}Installing missing packages: ${PACKAGES_TO_INSTALL[*]}${NC}"
    apt install -y "${PACKAGES_TO_INSTALL[@]}"
else
    echo -e "${GREEN}All required packages are already installed${NC}"
fi

# 3. Check for virtual environment and install dependencies
echo -e "${YELLOW}Setting up virtual environment and installing dependencies...${NC}"
cd $BOT_DIR

if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating new virtual environment...${NC}"
    python3 -m venv venv
    echo -e "${GREEN}Virtual environment created${NC}"
else
    echo -e "${YELLOW}Virtual environment already exists, skipping creation${NC}"
fi

echo -e "${YELLOW}Installing/updating dependencies...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# 4. Check and create systemd service
echo -e "${YELLOW}Setting up systemd service...${NC}"
SERVICE_FILE="/etc/systemd/system/telegrambot.service"

# Prepare the ExecStart command with token if provided
if [ -n "$BOT_TOKEN" ]; then
    EXEC_START="$BOT_DIR/venv/bin/python3 $BOT_DIR/bot.py --token=$BOT_TOKEN"
    echo -e "${GREEN}Configuring service with provided bot token${NC}"
else
    EXEC_START="$BOT_DIR/venv/bin/python3 $BOT_DIR/bot.py"
    echo -e "${YELLOW}Configuring service without explicit token${NC}"
fi

# Create or update the service file
echo -e "${YELLOW}Creating/updating systemd service...${NC}"
cat > $SERVICE_FILE << EOF
[Unit]
Description=Telegram Bot
After=network.target

[Service]
User=root
WorkingDirectory=$BOT_DIR
ExecStart=$EXEC_START
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}Service telegrambot created/updated${NC}"

# 5. Configure timezone (for correct schedule operation)
echo -e "${YELLOW}Setting timezone...${NC}"
timedatectl set-timezone Asia/Novosibirsk

# 6. Reload systemd and start/restart service
echo -e "${YELLOW}Reloading systemd and managing service...${NC}"
systemctl daemon-reload

# Check if telegrambot service is running
if systemctl is-active --quiet telegrambot; then
    echo -e "${YELLOW}Restarting telegrambot service...${NC}"
    systemctl restart telegrambot
else
    echo -e "${YELLOW}Enabling and starting telegrambot service...${NC}"
    systemctl enable telegrambot
    systemctl start telegrambot
fi

# 7. Check service status
echo -e "${YELLOW}Checking service status...${NC}"
systemctl status telegrambot | cat  # Using 'cat' to avoid pager

# 8. Run tests to check notification settings
echo -e "${YELLOW}Running tests to check notification settings...${NC}"

# Function to find Python path in virtual environment
find_venv_python() {
    # Check standard paths
    if [ -f "$BOT_DIR/venv/bin/python3" ]; then
        echo "$BOT_DIR/venv/bin/python3"
    elif [ -f "$BOT_DIR/venv/bin/python" ]; then
        echo "$BOT_DIR/venv/bin/python"
    elif [ -f "$BOT_DIR/bin/python3" ] && [ -d "$BOT_DIR/lib" ] && [ -f "$BOT_DIR/pyvenv.cfg" ]; then
        # If BOT_DIR itself is a venv directory
        echo "$BOT_DIR/bin/python3"
    elif [ -f "$BOT_DIR/bin/python" ] && [ -d "$BOT_DIR/lib" ] && [ -f "$BOT_DIR/pyvenv.cfg" ]; then
        echo "$BOT_DIR/bin/python"
    else
        echo ""
    fi
}

# Check for test script
if [ -f "$BOT_DIR/test_notifications.py" ]; then
    chmod +x $BOT_DIR/test_notifications.py

    # Check for virtual environment
    PYTHON_PATH=$(find_venv_python)
    
    if [ -z "$PYTHON_PATH" ]; then
        echo -e "${RED}Error: Could not find Python interpreter in virtual environment${NC}"
        echo -e "${YELLOW}Check that directory $BOT_DIR exists and virtual environment was created correctly${NC}"
        echo -e "${YELLOW}Testing skipped due to missing virtual environment${NC}"
    else
        echo -e "${GREEN}Found Python interpreter: $PYTHON_PATH${NC}"
        
        # Ask user if tests should be run
        run_tests="yes"  # Default to yes in non-interactive mode
        if $INTERACTIVE; then
            read -p "Run notification settings tests? (yes/no): " run_tests
        else
            echo -e "${YELLOW}Automated mode: automatically running tests${NC}"
        fi

        if [[ "$run_tests" =~ ^(yes|y)$ ]]; then
            echo -e "${GREEN}Running tests in virtual environment...${NC}"
            
            # Create a wrapper script to automatically answer Python's input prompts
            if ! $INTERACTIVE; then
                echo -e "${YELLOW}Creating auto-answer wrapper for tests...${NC}"
                cat > $BOT_DIR/test_wrapper.py << EOF
#!/usr/bin/env python3
import sys
import os
import subprocess

# Redirect stdin to provide automatic 'yes' answers to any prompts
with open('/dev/null', 'w') as devnull:
    # Run the original test script with its arguments, but with automatic 'yes' answers to any input() calls
    process = subprocess.Popen(
        [sys.argv[1]] + sys.argv[2:],
        env=dict(os.environ, PYTHONUNBUFFERED='1', AUTOMATED_TEST='1'),
        stdin=subprocess.PIPE,
        stdout=sys.stdout,
        stderr=sys.stderr
    )
    
    # Send 'yes' responses for each expected prompt
    for _ in range(5):  # Assume maximum of 5 prompts
        try:
            process.stdin.write(b'yes\n')
            process.stdin.flush()
        except:
            break
    
    process.wait()
    sys.exit(process.returncode)
EOF
                chmod +x $BOT_DIR/test_wrapper.py
                
                # Direct test execution using the wrapper
                if [ -n "$BOT_TOKEN" ]; then
                    $PYTHON_PATH $BOT_DIR/test_wrapper.py $PYTHON_PATH $BOT_DIR/test_notifications.py --token="$BOT_TOKEN"
                else
                    $PYTHON_PATH $BOT_DIR/test_wrapper.py $PYTHON_PATH $BOT_DIR/test_notifications.py
                fi
                
                # Remove the wrapper
                rm $BOT_DIR/test_wrapper.py
            else
                # Direct test execution using Python from virtual environment in interactive mode
                if [ -n "$BOT_TOKEN" ]; then
                    $PYTHON_PATH $BOT_DIR/test_notifications.py --token="$BOT_TOKEN"
                else
                    $PYTHON_PATH $BOT_DIR/test_notifications.py
                fi
            fi
            
            echo -e "${GREEN}Testing completed${NC}"
            
            # Check for test result files if they exist
            if [ -f "$BOT_DIR/test_log.txt" ]; then
                echo -e "${YELLOW}Test log contents:${NC}"
                cat "$BOT_DIR/test_log.txt"
            fi
            
            if [ -f "$BOT_DIR/test_results.txt" ]; then
                echo -e "${YELLOW}Test results:${NC}"
                cat "$BOT_DIR/test_results.txt"
            fi
        else
            echo -e "${YELLOW}Testing skipped by user request${NC}"
        fi
    fi
else
    echo -e "${RED}Error: Test file $BOT_DIR/test_notifications.py not found${NC}"
    echo -e "${YELLOW}Testing skipped due to missing test file${NC}"
fi

# Run notification job test
echo -e "${YELLOW}Running notification job specific tests...${NC}"
if [ -f "$BOT_DIR/test_notification_job.py" ]; then
    chmod +x $BOT_DIR/test_notification_job.py
    
    # Check for virtual environment
    PYTHON_PATH=$(find_venv_python)
    
    if [ -z "$PYTHON_PATH" ]; then
        echo -e "${RED}Error: Could not find Python interpreter in virtual environment${NC}"
        echo -e "${YELLOW}Notification job testing skipped due to missing virtual environment${NC}"
    else
        echo -e "${GREEN}Found Python interpreter: $PYTHON_PATH${NC}"
        
        # Run notification job test
        echo -e "${GREEN}Running notification job tests...${NC}"
        if [ -n "$BOT_TOKEN" ]; then
            $PYTHON_PATH $BOT_DIR/test_notification_job.py --token="$BOT_TOKEN"
        else
            $PYTHON_PATH $BOT_DIR/test_notification_job.py
        fi
        echo -e "${GREEN}Notification job testing completed${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Test file $BOT_DIR/test_notification_job.py not found${NC}"
    echo -e "${YELLOW}Notification job testing skipped due to missing test file${NC}"
fi

# Run prize fund calculation test
echo -e "${YELLOW}Running prize fund calculation test...${NC}"
if [ -f "$BOT_DIR/prize_fund_test.py" ]; then
    chmod +x $BOT_DIR/prize_fund_test.py
    
    # Check for virtual environment
    PYTHON_PATH=$(find_venv_python)
    
    if [ -z "$PYTHON_PATH" ]; then
        echo -e "${RED}Error: Could not find Python interpreter in virtual environment${NC}"
        echo -e "${YELLOW}Prize fund calculation test skipped due to missing virtual environment${NC}"
    else
        echo -e "${GREEN}Found Python interpreter: $PYTHON_PATH${NC}"
        
        # Run prize fund test
        echo -e "${GREEN}Running prize fund calculation test...${NC}"
        $PYTHON_PATH $BOT_DIR/prize_fund_test.py
        echo -e "${GREEN}Prize fund calculation test completed${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Test file $BOT_DIR/prize_fund_test.py not found${NC}"
    echo -e "${YELLOW}Prize fund calculation test skipped due to missing test file${NC}"
fi

echo -e "${GREEN}=== Bot setup completed! ===${NC}"
echo -e "${YELLOW}To view logs use: ${NC}journalctl -u telegrambot -f"
echo -e "${YELLOW}To restart the bot use: ${NC}systemctl restart telegrambot"

# Offer to perform direct message sending check via Telegram API
echo -e "${YELLOW}Would you like to perform a direct message sending check via Telegram? (yes/no): ${NC}"
direct_test="yes"  # Default to yes in non-interactive mode
if $INTERACTIVE; then
    read direct_test
else
    echo -e "${YELLOW}Automated mode: automatically performing direct message check${NC}"
fi

if [[ "$direct_test" =~ ^(yes|y)$ ]]; then
    echo -e "${YELLOW}Performing direct message sending check...${NC}"
    
    # Create temporary script for sending test message
    # Pass token if provided
    TOKEN_PARAM=""
    if [ -n "$BOT_TOKEN" ]; then
        TOKEN_PARAM="--token=\"$BOT_TOKEN\""
    fi
    
    cat > $BOT_DIR/direct_test.py << EOF
#!/usr/bin/env python3
import os
import sys
import asyncio
import importlib.util
import argparse
from datetime import datetime

# Parse command line arguments
parser = argparse.ArgumentParser(description='Direct Test')
parser.add_argument('--token', type=str, help='Telegram bot token')
args = parser.parse_args()

async def send_test_message():
    try:
        # Load bot.py module to get token and admin list
        spec = importlib.util.spec_from_file_location("bot", "bot.py")
        bot_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(bot_module)
        
        # Use provided token if available, otherwise use from bot module
        token = args.token if args.token else bot_module.BOT_TOKEN
        admins = bot_module.admin_users
        
        # Import telegram module
        from telegram import Bot
        
        # Create bot instance
        bot = Bot(token=token)
        
        # Prepare test message
        message = f"🔄 Test message from direct check\nTime: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        
        # Send message to each admin
        success = False
        for admin_id in admins:
            try:
                print(f"Sending test message to admin {admin_id}...")
                await bot.send_message(
                    chat_id=admin_id,
                    text=message
                )
                print(f"✅ Message successfully sent to admin {admin_id}")
                success = True
            except Exception as e:
                print(f"❌ Error sending message to admin {admin_id}: {str(e)}")
        
        if success:
            print("✅ Message sending check completed successfully")
        else:
            print("❌ Could not send message to any admin")
            
    except Exception as e:
        print(f"❌ General error during message sending check: {str(e)}")

if __name__ == "__main__":
    asyncio.run(send_test_message())
EOF

    # Make script executable
    chmod +x $BOT_DIR/direct_test.py
    
    # Run direct check
    echo -e "${YELLOW}Starting direct check...${NC}"
    if [ -n "$BOT_TOKEN" ]; then
        $PYTHON_PATH $BOT_DIR/direct_test.py --token="$BOT_TOKEN"
    else
        $PYTHON_PATH $BOT_DIR/direct_test.py
    fi
    
    # Remove temporary script
    rm $BOT_DIR/direct_test.py
else
    echo -e "${YELLOW}Direct message sending check skipped${NC}"
fi
