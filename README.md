# Quit Smoking Bot

Telegram bot that helps track smoke-free periods and motivates users with quotes and a prize fund system.

## Features

- Track smoke-free period duration (years, months, days)
- Calculate and display prize fund based on smoke-free period
- Send monthly motivational notifications
- Show next prize fund increase date
- Display random motivational quotes
- Admin commands for managing users and notifications
- Token validation during setup to ensure proper connectivity
- Conflict detection with external bot instances
- Improved service monitoring and diagnostics

## Requirements

- Docker and Docker Compose
- Systemd (for service management)
- curl (for token validation and conflict detection)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/sensiloles/quit-smoking-bot.git
cd quit-smoking-bot
```

2. Create a `.env` file with the required environment variables:
```bash
# Required variables
BOT_TOKEN="your_telegram_bot_token_here"  # Get from BotFather
SYSTEM_NAME="quit-smoking-bot"            # Name used for Docker containers and systemd service
SYSTEM_DISPLAY_NAME="Quit Smoking Bot"    # Display name for the service and logs

# Optional variables (with defaults)
TZ="Asia/Novosibirsk"                     # Timezone for scheduled notifications
NOTIFICATION_DAY=23                       # Day of month for notifications
NOTIFICATION_HOUR=21                      # Hour for notifications
NOTIFICATION_MINUTE=58                    # Minute for notifications
```

3. Make the scripts executable:
```bash
chmod +x scripts/*.sh
```

4. Start the bot:
```bash
./scripts/run.sh
```

You can also pass the bot token directly as a parameter:
```bash
./scripts/run.sh --token YOUR_BOT_TOKEN
```
The token will be validated against the Telegram API and saved to the `.env` file if valid.

### Additional Command-Line Options

All scripts support these additional options:

- `--force-rebuild` - Forces a complete rebuild of Docker images without using the cache
```bash
./scripts/run.sh --force-rebuild
```

- `--cleanup` - Performs additional cleanup of Docker resources (volumes, networks)
```bash
./scripts/stop.sh --cleanup
```

## Environment Variables

The following environment variables can be set in the `.env` file:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BOT_TOKEN` | Yes | - | Your Telegram bot token from BotFather (use quotes) |
| `SYSTEM_NAME` | Yes | quit-smoking-bot | Name for Docker containers and systemd service (use quotes) |
| `SYSTEM_DISPLAY_NAME` | Yes | Quit Smoking Bot | Display name for the service and logs (use quotes, especially for values with spaces) |
| `TZ` | No | Asia/Novosibirsk | Timezone for the bot and scheduled notifications (use quotes) |
| `NOTIFICATION_DAY` | No | 23 | Day of month for scheduled notifications (numeric value) |
| `NOTIFICATION_HOUR` | No | 21 | Hour for notifications (24-hour format, numeric value) |
| `NOTIFICATION_MINUTE` | No | 58 | Minute for notifications (numeric value) |

**Note about .env format:** All string values should be enclosed in double quotes (`"value"`), especially if they contain spaces or special characters. Numeric values don't need quotes.

You can also set environment variables in other ways:
- Export them in your shell session: `export BOT_TOKEN=your_token_here`
- Pass them as arguments to scripts: `./scripts/run.sh --token your_token_here`

## Testing

To run the tests:
```bash
./scripts/test.sh
```

The test script will:
1. Build and run tests in a dedicated container (`quit-smoking-bot-test`)
2. Run integration tests for notification system
3. Send test results to all admins via Telegram
4. Clean up test containers after completion

Test results will be:
- Displayed in the console
- Sent to admin users via Telegram with timestamp

## Usage

The bot will automatically start when the container is running. Logs can be viewed with:
```bash
docker-compose logs -f bot
```

To stop the container:
```bash
docker-compose down
```

## Service Management

The project includes several scripts for managing the bot as a system service:

### Installation and Setup

```bash
sudo ./scripts/install-service.sh
```

The installation script will:
- Validate the Telegram bot token
- Check for conflicts with other bot instances using the same token
- Clear any existing containers or services with the same name
- Create a systemd service file (overwrites existing if any)
- Configure automatic startup
- Start the service
- Monitor the startup process
- Show detailed status information and recent logs

You can also pass the bot token directly:
```bash
sudo ./scripts/install-service.sh --token YOUR_BOT_TOKEN
```

For a clean installation, forcing a complete rebuild:
```bash
sudo ./scripts/install-service.sh --force-rebuild
```

### Service Management Commands

After installation, you can manage the service with these commands:

```bash
# Start the service
sudo systemctl start quit-smoking-bot.service

# Stop the service
sudo systemctl stop quit-smoking-bot.service

# Restart the service
sudo systemctl restart quit-smoking-bot.service

# Check service status
sudo systemctl status quit-smoking-bot.service

# View service logs
sudo journalctl -u quit-smoking-bot.service -f
```

### Stopping the Bot

To stop the bot and clean up resources:

```bash
./scripts/stop.sh [--cleanup]
```

The stop script will:
- Stop and remove all bot containers
- Optionally clean up Docker resources (volumes and networks) if `--cleanup` flag is provided

### Uninstallation

```bash
sudo ./scripts/uninstall-service.sh
```

The uninstallation script will:
- Stop and disable the service
- Remove the service file
- Clean up Docker containers and images
- Remove project artifacts
- Show status before and after uninstallation

To perform a thorough cleanup during uninstallation:
```bash
sudo ./scripts/uninstall-service.sh --cleanup
```

### Status Check

```bash
sudo ./scripts/check-service.sh
```

The status check script provides comprehensive information about:
- Systemd service status
- Docker containers, images, and volumes
- Project files and directories
- Network connections
- Bot operational status with detailed diagnostics
- Recent logs from both systemd and Docker

## Bot Commands

- `/start` - Start tracking your smoke-free period
- `/status` - Show current status (period, prize fund, next increase)
- `/notify_all` - Send notifications to all users (admin only)
- `/list_users` - List all registered users (admin only)
- `/list_admins` - List all admin users (admin only)

## Development

All scripts use docker-compose for container management. The main services are:
- `bot` - Main bot service
- `test` - Test service for running integration tests

Container names are fixed:
- Main bot: `quit-smoking-bot`
- Test container: `quit-smoking-bot-test`

For development and debugging, you can use standard docker-compose commands:
```bash
# Build services
docker-compose build

# Start bot in background
docker-compose up -d bot

# Run tests
docker-compose run --rm test

# View logs
docker-compose logs -f bot

# Stop all services
docker-compose down
```

## Project Structure

```
quit-smoking-bot/
├── src/
│   ├── __init__.py
│   ├── bot.py           # Main bot class and handlers
│   ├── config.py         # Configuration and constants
│   ├── quotes.py        # Quotes management
│   ├── status.py        # Status information and calculations
│   ├── users.py         # User management and storage
│   └── utils.py         # Utility functions and helpers
├── tests/
│   ├── __init__.py
│   ├── integration/     # Integration tests
│   │   ├── __init__.py
│   │   └── test_notifications.py  # Notification system tests
│   └── unit/            # Unit tests
│       ├── __init__.py
│       └── test_utils.py # Utility functions tests
├── scripts/             # Shell scripts
│   ├── common.sh        # Common functions
│   ├── run.sh           # Run bot script
│   ├── test.sh          # Test script
│   ├── install-service.sh # Service installation
│   ├── uninstall-service.sh # Service removal
│   ├── check-service.sh # Status check
│   └── entrypoint.sh    # Container entrypoint script
├── data/                # Data storage
│   ├── bot_users.json
│   ├── bot_admins.json
│   ├── quotes.json
├── logs/                # Log files
├── Dockerfile            # Docker configuration
├── docker-compose.yml   # Docker Compose configuration
├── .dockerignore        # Docker ignore patterns
├── .gitignore           # Git ignore patterns
├── main.py              # Legacy entry point (redirects to src/bot.py)
├── setup.py             # Package configuration
├── .env.example         # Environment variables example
└── README.md            # Documentation
```

The `entrypoint.sh` script is used as the container's entry point and handles:
- Environment variable setup
- Log directory creation
- Prevention of multiple bot instances
- Bot startup with proper configuration
- Signal handling for graceful shutdown

## Configuration

The bot can be configured using environment variables:

- `BOT_TOKEN` - Telegram bot token (required, use quotes)
- `SYSTEM_NAME` - Name for Docker containers and systemd service (required, use quotes)
- `SYSTEM_DISPLAY_NAME` - Display name for the service and logs (required, use quotes)
- `TZ` - Timezone (default: "Asia/Novosibirsk", use quotes)
- `NOTIFICATION_HOUR` - Hour for monthly notifications (default: 21, numeric value)
- `NOTIFICATION_MINUTE` - Minute for monthly notifications (default: 58, numeric value)
- `NOTIFICATION_DAY` - Day of month for notifications (default: 23, numeric value)

## Token Validation and Conflict Detection

The bot now includes intelligent token validation and conflict detection features:

- **Token Validation**: When providing a token through command line arguments, the system will validate it with the Telegram API before saving it to the `.env` file.
- **Conflict Detection**: The system checks for other bot instances using the same token, which could cause conflicts.
- **Instance Management**: The entrypoint script prevents multiple bot processes within the same container.
- **Detailed Error Messages**: Clear error messages and troubleshooting guides if conflicts or validation issues are detected.

## Automatic Startup on VPS

To configure automatic startup of the bot when the VPS server reboots:

1. Install the systemd service:
```bash
sudo ./scripts/install-service.sh
```

2. Start the service:
```bash
sudo systemctl start quit-smoking-bot.service
```

3. Check service status:
```bash
sudo systemctl status quit-smoking-bot.service
```

The service will:
- Start automatically when the server boots
- Wait for Docker service to be ready
- Run the bot in a container
- Use restart policies to handle temporary failures
- Monitor bot health and restart if needed

To stop the service:
```bash
sudo systemctl stop quit-smoking-bot.service
```

## Troubleshooting

### Bot doesn't start or reports conflicts

If the bot fails to start and reports conflicts with another instance:

1. Check if another bot is running with the same token:
```bash
sudo ./scripts/check-service.sh
```

2. If you have multiple servers or machines running the bot, make sure only one is active with a given token.

3. If a conflict persists but no other instances are running:
```bash
# Wait for Telegram API connections to time out (typically 1-2 minutes)
sudo systemctl stop quit-smoking-bot.service
# Wait 2 minutes
sudo systemctl start quit-smoking-bot.service
```

4. If all else fails, try creating a new bot token with BotFather and update your `.env` file.

### Checking if bot is running correctly

The bot provides comprehensive status information:
```bash
sudo ./scripts/check-service.sh
```

Look for the "Bot Operational Status" section which will indicate if the bot is fully operational and connected to the Telegram API.

### Docker build issues

If you're experiencing Docker build issues or suspect cached layers are causing problems:
```bash
./scripts/run.sh --force-rebuild
```
This forces Docker to rebuild all images from scratch without using the cache.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
