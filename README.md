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

> **🚀 Automatic Setup**: Project setup is automatically performed after cloning via git hooks. For manual setup, run: `make setup`

2. Update the `.env` file with your bot token:
```bash
# The .env template is created automatically, just update the BOT_TOKEN:
BOT_TOKEN="your_telegram_bot_token_here"  # Get from BotFather
```

3. Start the bot:
```bash
make start
```

**Alternative quick start:**
```bash
make install    # Full installation with Docker setup
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
./scripts/run.sh --install
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
./scripts/stop.sh --uninstall
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

**Using Makefile (Recommended):**
```bash
# Project setup
make setup              # Initial setup after cloning
make install            # Full installation with Docker

# Service management  
make start              # Start the bot
make stop               # Stop the bot
make restart            # Restart the bot
make status             # Show service status

# Development
make dev                # Start development environment
make logs               # View logs
make shell              # Open shell in container

# Maintenance
make update             # Update and restart
make backup             # Backup bot data
make clean              # Clean up containers
```

**Legacy script commands (still supported):**
```bash
./scripts/run.sh        # Start the bot
./scripts/stop.sh       # Stop the bot

./scripts/check-service.sh  # Check status
```

## Command-Line Options

### run.sh options:

- `--install` - Full installation with Docker setup and auto-restart
- `--token YOUR_BOT_TOKEN` - Specify the Telegram bot token
- `--force-rebuild` - Forces a complete rebuild of Docker images

- `--monitoring` - Enable health monitoring service
- `--logging` - Enable log aggregation service
- `--dry-run` - Show what would be done without executing
- `--status` - Show system status and exit
- `--quiet` - Minimal output (errors only)
- `--verbose` - Detailed output and debugging
- `--help` - Displays usage information and options

### stop.sh options:

- `--uninstall` - Complete uninstallation (removes images and cleans Docker)

- `--all` - Stop all services including monitoring and logging
- `--dry-run` - Show what would be done without executing
- `--force` - Skip confirmation prompts
- `--quiet` - Minimal output (errors only)
- `--verbose` - Detailed output and debugging
- `--help` - Show help message

> **⚠️ Important**: The `data/` directory (user database) is always preserved and never deleted automatically.

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

## Enhanced Script Features

The management scripts include advanced features for better operational experience:

### Dry-Run Mode
Preview what actions will be performed without executing them:
```bash
# Preview installation
./scripts/run.sh --dry-run --install --monitoring

# Preview uninstallation
./scripts/stop.sh --dry-run --uninstall
```

### Action Logging
All operations are logged to `logs/actions.log` for audit trail:
```bash
# View recent actions
tail -f logs/actions.log

# Check action history
grep "SUCCESS\|ERROR" logs/actions.log
```

### Interactive Confirmations
Dangerous operations require explicit confirmation:
```bash
./scripts/stop.sh --uninstall
# ⚠️  WARNING: This action may result in data loss!
# Are you sure you want to proceed? (y/N):
```

### Comprehensive Status Reporting
Get detailed system information:
```bash
./scripts/run.sh --status
# Shows: containers, images, data directories, recent actions, installation status
```

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
./scripts/stop.sh --uninstall
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
./scripts/run.sh --verbose --force-rebuild --token YOUR_TOKEN
./scripts/run.sh --verbose --install
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


├── scripts/                        # Shell scripts for operations
│   ├── modules/                    # Common script modules
│   │   ├── actions.sh             # Action logging and dry-run functionality
│   │   ├── args.sh                # Argument parsing utilities
│   │   ├── conflicts.sh           # Bot conflict detection
│   │   ├── docker.sh              # Docker management functions
│   │   ├── environment.sh         # Environment setup and validation
│   │   ├── errors.sh              # Error handling utilities
│   │   ├── filesystem.sh          # File system operations
│   │   ├── health.sh              # Health checking utilities
│   │   ├── output.sh              # Output formatting and messaging
│   │   ├── service.sh             # Service management functions
│   │   ├── system.sh              # System detection and setup

│   ├── bootstrap.sh               # Script initialization and module loading
│   ├── check-service.sh           # Service status check and diagnostics
│   ├── entrypoint.sh              # Container entrypoint script

│   ├── run.sh                     # Universal start/install script
│   ├── stop.sh                    # Universal stop/uninstall script

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

For comprehensive usage guide of the management scripts, see [SCRIPT_USAGE.md](SCRIPT_USAGE.md).

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

For local development:

### Using Docker (Recommended)

The easiest way to develop is using the existing Docker setup:

```bash
# Start development environment
./scripts/run.sh --token YOUR_DEV_TOKEN



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


```

This approach is useful for:
- IDE integration and debugging
- Faster iteration during development
- Direct access to Python debugging tools

## Future Development Plans

### Migration from Bash to Python

There is a planned migration to rewrite operational scripts from Bash to Python. This will provide several advantages:

- **Code Consistency**: Using Python for both application and operational scripts maintains a single language across the codebase
- **Better Error Handling**: Python's exception handling is more robust than Bash error processing
- **Improved Maintainability**: Python scripts are easier to maintain than Bash scripts
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

- `build`: Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)
- `ci`: Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)
- `chore`: Other changes that don't modify src files

### Enforcement

Commit message formatting can be enforced using Git hooks or CI/CD pipelines to maintain consistency across the project.