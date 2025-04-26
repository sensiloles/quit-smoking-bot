# Quit Smoking Bot

Telegram bot that helps track smoke-free periods and motivates users with quotes and a prize fund system.

## Features

- Track smoke-free period duration (years, months, days)
- Calculate and display prize fund based on smoke-free period
- Send monthly motivational notifications
- Show next prize fund increase date
- Display random motivational quotes
- Admin commands for managing users and notifications

## Requirements

- Docker and Docker Compose
- Systemd (for service management)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/sensiloles/quit-smoking-bot.git
cd quit-smoking-bot
```

2. Set up your Telegram bot token using one of these methods:
   - Create `.env` file and add your token:
     ```bash
     echo 'BOT_TOKEN=your_bot_token_here' > .env
     ```
   - Export token in your environment:
     ```bash
     export BOT_TOKEN='your_bot_token_here'
     ```
   - Pass token as an argument to scripts:
     ```bash
     ./scripts/run.sh --token your_bot_token_here
     ```

3. Make the scripts executable:
```bash
chmod +x scripts/*.sh
```

4. Start the bot:
```bash
./scripts/run.sh
```

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
- Create a systemd service file (overwrites existing if any)
- Configure automatic startup
- Start the service
- Monitor the startup process
- Show detailed status information

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

### Status Check

```bash
sudo ./scripts/check-service.sh
```

The status check script provides comprehensive information about:
- Systemd service status
- Docker containers, images, and volumes
- Project files and directories
- Network connections
- Recent logs from both systemd and Docker

## Bot Commands

- `/start` - Start tracking your smoke-free period
- `/status` - Show current status (period, prize fund, next increase)
- `/notify_all` - Send notifications to all users (admin only)

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
- Bot startup with proper configuration
- Signal handling for graceful shutdown

## Configuration

The bot can be configured using environment variables:

- `BOT_TOKEN` - Telegram bot token (required)
- `TZ` - Timezone (default: Asia/Novosibirsk)
- `NOTIFICATION_HOUR` - Hour for monthly notifications (default: 21)
- `NOTIFICATION_MINUTE` - Minute for monthly notifications (default: 58)
- `NOTIFICATION_DAY` - Day of month for notifications (default: 23)

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
- Restart the container if it stops

To stop the service:
```bash
sudo systemctl stop quit-smoking-bot.service
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
