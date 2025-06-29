# Quit Smoking Bot

Telegram bot that helps track smoke-free periods and motivates users with quotes and a prize fund system.

## Features

- Track smoke-free period duration (years, months, days)
- Calculate and display prize fund based on smoke-free period
- Send monthly motivational notifications
- Show next prize fund increase date
- Display random motivational quotes
- Admin commands for managing users and notifications

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/sensiloles/quit-smoking-bot.git
cd quit-smoking-bot
```

2. Create a `.env` file with required environment variables:
```bash
BOT_TOKEN="your_telegram_bot_token_here"  # Get from BotFather
SYSTEM_NAME="quit-smoking-bot"            # For Docker containers
SYSTEM_DISPLAY_NAME="Quit Smoking Bot"    # For service and logs
```

3. Start the bot:
```bash
chmod +x scripts/*.sh
./scripts/run.sh
```

You can also pass the bot token directly:
```bash
./scripts/run.sh --token YOUR_BOT_TOKEN
```

## Bot Commands

- `/start` - Start tracking your smoke-free period
- `/status` - Show current status (period, prize fund, next increase)
- `/notify_all` - Send notifications to all users (admin only)
- `/list_users` - List all registered users (admin only)
- `/list_admins` - List all admin users (admin only)

## Requirements

- Docker and Docker Compose
- curl (for token validation and conflict detection)

## Running as a Service

Install Docker and start the bot service:
```bash
./scripts/install-service.sh
```

This will:
- Install Docker and Docker Compose (if not already installed)
- Build and start the bot with automatic restart on failures
- Enable Docker for automatic startup on system boot

Manage the service:
```bash
# Start the bot
./scripts/run.sh

# Stop the bot
./scripts/stop.sh

# Check status and diagnostics
./scripts/check-service.sh

# View logs
docker-compose logs -f bot

# Restart the bot
docker-compose restart bot

# Update and restart
./scripts/run.sh --force-rebuild
```

Uninstall the service:
```bash
./scripts/uninstall-service.sh
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BOT_TOKEN` | Yes | - | Your Telegram bot token from BotFather |
| `SYSTEM_NAME` | Yes | quit-smoking-bot | Name for Docker containers |
| `SYSTEM_DISPLAY_NAME` | Yes | Quit Smoking Bot | Display name for the service and logs |
| `TZ` | No | Asia/Novosibirsk | Timezone for scheduled notifications |
| `NOTIFICATION_DAY` | No | 23 | Day of month for notifications |
| `NOTIFICATION_HOUR` | No | 21 | Hour for notifications (24-hour format) |
| `NOTIFICATION_MINUTE` | No | 58 | Minute for notifications |

**Note:** All string values should be enclosed in double quotes in the `.env` file.

## Common Commands

```bash
# Start the bot
./scripts/run.sh

# Stop the bot  
./scripts/stop.sh [--cleanup]

# Start with additional services
./scripts/run.sh --monitoring --logging

# Check comprehensive service status
./scripts/check-service.sh

# Run tests
./scripts/test.sh

# Run tests using Docker Compose
docker-compose --profile test run --rm test

# View logs
docker-compose logs -f bot

# Update bot
./scripts/run.sh --force-rebuild
```

## Command-Line Options

### run.sh and install-service.sh options:

- `--token YOUR_BOT_TOKEN` - Specify the Telegram bot token
- `--force-rebuild` - Forces a complete rebuild of Docker images
- `--tests` - Runs the test suite after building. If tests fail, the script will stop
- `--monitoring` - Enable health monitoring service
- `--logging` - Enable log aggregation service
- `--help` - Displays usage information and options

### stop.sh options:

- `--all` - Stop all services including monitoring and logging
- `--cleanup` - Perform thorough cleanup of Docker resources
- `--volumes` - Remove volumes (WARNING: this will delete data)
- `--images` - Remove bot images after stopping

### uninstall-service.sh options:

- `--keep-data` - Keep data directory and logs
- `--keep-images` - Keep Docker images
- `--full-cleanup` - Remove everything including Docker volumes
- `--remove-legacy` - Remove legacy systemd/supervisor services if exist

## Service Profiles

The bot supports additional services through Docker Compose profiles:

### Health Monitoring
```bash
# Start with health monitoring
./scripts/run.sh --monitoring

# Or directly with docker-compose
docker-compose --profile monitoring up -d
```

### Log Aggregation
```bash
# Start with log aggregation
./scripts/run.sh --logging

# Or directly with docker-compose
docker-compose --profile logging up -d
```

### Testing
```bash
# Run tests
docker-compose --profile test run --rm test
```

## Architecture and Technology Stack

The bot is fully containerized using **Docker Compose** for modern, portable deployment:

- **Container Runtime**: Docker with Docker Compose orchestration
- **Service Management**: Native Docker restart policies (no systemd/supervisor needed)
- **Health Monitoring**: Built-in Docker health checks with custom scripts
- **Log Management**: Docker logging with automatic rotation
- **Resource Control**: Container-level CPU and memory limits
- **Network Isolation**: Dedicated Docker bridge network
- **Data Persistence**: Docker volumes for user data and logs

This architecture provides:
- ✅ **Portability**: Runs identically on any Docker-capable system
- ✅ **Simplicity**: No complex service managers or system dependencies
- ✅ **Reliability**: Automatic restart and health monitoring
- ✅ **Security**: Process isolation and non-root execution
- ✅ **Scalability**: Easy to extend with additional services

## Automatic Features

The bot includes several automatic features:

- **Auto-restart**: Bot automatically restarts if it crashes (Docker restart policy)
- **Boot startup**: Bot starts automatically when Docker starts (if Docker auto-starts)
- **Health checks**: Built-in health monitoring to detect issues
- **Log rotation**: Automatic log file management with size limits
- **Resource limits**: Memory and CPU usage limits for stability
- **Conflict detection**: Automatically detects and handles token conflicts

## Troubleshooting

### Bot doesn't start or reports conflicts

1. Check comprehensive service status:
```bash
./scripts/check-service.sh
```

2. Stop all running instances:
```bash
./scripts/stop.sh --all
# Wait a moment, then restart
./scripts/run.sh
```

3. If conflict persists, create a new bot token with BotFather.

### Docker build issues

Force a complete rebuild:
```bash
./scripts/run.sh --force-rebuild
```

Clean up Docker resources:
```bash
./scripts/stop.sh --cleanup
docker system prune -f
```

### Service Status and Debugging

Get comprehensive diagnostics:
```bash
./scripts/check-service.sh
```

This will show:
- Docker Compose service status
- Container health and resource usage
- Bot process status and logs
- Network and volume information
- Recent errors and operational status

Enable verbose debug output:
```bash
DEBUG=1 ./scripts/run.sh --force-rebuild --token YOUR_TOKEN
DEBUG=1 ./scripts/install-service.sh --tests
```

This will print detailed step-by-step information to help pinpoint issues.

## Project Structure

```
quit-smoking-bot/
├── src/                            # Source code directory
│   ├── __init__.py                 # Python package initialization
│   ├── bot.py                      # Main bot class and handlers
│   ├── config.py                   # Configuration and constants
│   ├── quotes.py                   # Quotes management
│   ├── status.py                   # Status information and calculations
│   ├── users.py                    # User management and storage
│   ├── utils.py                    # Utility functions and helpers
│   └── send_results.py             # Test results notification system
├── tests/                          # Tests directory
│   ├── integration/                # Integration tests
│   └── unit/                       # Unit tests
├── scripts/                        # Shell scripts for operations
│   ├── modules/                    # Common script modules
│   ├── bootstrap.sh               # Script initialization
│   ├── check-service.sh           # Service status check
│   ├── entrypoint.sh              # Container entrypoint script
│   ├── healthcheck.sh             # Container health check
│   ├── install-service.sh         # Service installation
│   ├── run.sh                     # Start bot service
│   ├── stop.sh                    # Stop bot service
│   ├── test.sh                    # Run tests
│   └── uninstall-service.sh       # Service uninstallation
├── data/                          # Bot data directory (created on first run)
├── logs/                          # Log files directory (created on first run)
├── docker-compose.yml             # Docker Compose configuration
├── Dockerfile                     # Docker image definition
├── requirements.txt               # Python dependencies
├── setup.py                       # Python package setup
└── main.py                        # Application entry point
```

## Docker Configuration

The bot is containerized using Docker for consistent deployment across different environments. For detailed information about the Docker setup, container lifecycle, networking, and advanced configurations, see [DOCKER.md](DOCKER.md).

Key features of the Docker implementation include:
- Multi-stage build process for optimized image size
- Non-root user execution for enhanced security
- Persistent volume mapping for data and logs
- Comprehensive health checking system
- Resource limits and container management
- Bridge network isolation for services
- JSON logging with rotation

Container management is handled through shell scripts that provide a simple interface to the underlying Docker operations.

## Development Setup

For local development and testing:

### Using Docker (Recommended)

The easiest way to develop and test is using the existing Docker setup:

```bash
# Start development environment
./scripts/run.sh --token YOUR_DEV_TOKEN

# Run tests
./scripts/test.sh

# Access container for debugging
docker exec -it quit-smoking-bot sh
```

### Native Python Environment

For native development without Docker:

```bash
# Install development dependencies
python3 -m pip install -r requirements-dev.txt

# Install project in editable mode
pip install -e .

# Run tests
python -m pytest tests/
```

This approach is useful for:
- IDE integration and debugging
- Faster iteration during development
- Direct access to Python debugging tools

### Testing Environment

The project includes comprehensive testing:

```bash
# Run all tests with Docker
./scripts/test.sh

# Run specific test categories
docker-compose --profile test run --rm test python -m pytest tests/unit/
docker-compose --profile test run --rm test python -m pytest tests/integration/

# Run tests natively
python -m pytest tests/unit/
python -m pytest tests/integration/ --token YOUR_TOKEN
```

## Future Development Plans

### Migration from Bash to Python

There is a planned migration to rewrite operational scripts from Bash to Python. This will provide several advantages:

- **Code Consistency**: Using Python for both application and operational scripts maintains a single language across the codebase
- **Better Error Handling**: Python's exception handling is more robust than Bash error processing
- **Improved Testability**: Python scripts are easier to unit test than Bash scripts
- **Enhanced Maintainability**: Python's cleaner syntax and stronger typing improves long-term code maintenance
- **Library Reuse**: Ability to reuse application code utilities within operational scripts

The migration will be implemented in phases:
1. Create Python equivalents of current Bash scripts
2. Support both Bash and Python versions during transition period
3. Eventually make Python the default with Bash as optional legacy support

### Extended OS Support

While the current implementation works on any Docker-compatible system, future versions will include:

- **Enhanced macOS Support**: Improved native integration and service management
- **Windows Support**: Native Windows container support and PowerShell scripts
- **Cross-platform Abstractions**: Using Python to create OS-independent operational scripts

This extended platform support will primarily be enabled by the migration to Python-based scripts, which offer better cross-platform capabilities than Bash.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Commit Conventions

This project follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification for commit messages. This format helps in automating CHANGELOG generation and makes the commit history more readable.

The basic format is:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Common types include:

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)
- `ci`: Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)
- `chore`: Other changes that don't modify src or test files

### Enforcement

Commit message formatting can be enforced using Git hooks or CI/CD pipelines to maintain consistency across the project.