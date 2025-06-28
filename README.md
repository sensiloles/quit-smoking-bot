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
SYSTEM_NAME="quit-smoking-bot"            # For Docker containers and systemd service
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
- Systemd (for service management on Linux)
- curl (for token validation and conflict detection)

## Running as a Service

> **Compatibility Note:** Running as a systemd service is fully supported only on **Linux distributions** that use systemd (like Ubuntu).
> On macOS and other systems, the `install-service.sh` script will build the Docker image and run tests (if `--tests` is used), but it cannot install or manage a systemd service. The bot container will be started directly using `docker-compose`.

Install and start as a systemd service (Linux only):
```bash
sudo ./scripts/install-service.sh
```

Manage the service (Linux only):
```bash
sudo systemctl start|stop|restart|status quit-smoking-bot.service
sudo journalctl -u quit-smoking-bot.service -f  # View logs (Linux only)
```

Uninstall the service (Linux only):
```bash
sudo ./scripts/uninstall-service.sh
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BOT_TOKEN` | Yes | - | Your Telegram bot token from BotFather |
| `SYSTEM_NAME` | Yes | quit-smoking-bot | Name for Docker containers and systemd service |
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

# Check service status
sudo ./scripts/check-service.sh

# Run tests
./scripts/test.sh

# Run tests using Docker Compose
docker-compose run --rm test

# View logs
docker-compose logs -f bot
```

## Command-Line Options

All `run.sh` and `install-service.sh` scripts support these options:

- `--token YOUR_BOT_TOKEN` - Specify the Telegram bot token
- `--force-rebuild` - Forces a complete rebuild of Docker images
- `--cleanup` - Performs additional cleanup of Docker resources
- `--tests` - Runs the test suite after building the image. If tests fail, the script will stop (won't start the bot or install the service).
- `--help` - Displays usage information and options

*Note:* Test configuration is managed by `pytest.ini` located in the `tests/` directory.

## Troubleshooting

### Bot doesn't start or reports conflicts

1. Check if another bot is running with the same token:
```bash
./scripts/check-service.sh # Can be run with sudo on Linux for more details
```

2. If conflict persists (and you are on Linux):
```bash
sudo systemctl stop quit-smoking-bot.service
# Wait 2 minutes
sudo systemctl start quit-smoking-bot.service
```
If not on Linux, ensure no other `docker-compose` instance is running the bot.

3. If all else fails, create a new bot token with BotFather.

### Docker build issues

Force a complete rebuild:
```bash
./scripts/run.sh --force-rebuild
```

If you encounter errors like `error getting credentials - err: exit status 1, out: \`\` when pulling base images (e.g., `python:3.9-slim`), it might be due to Docker Hub authentication issues. Try the following:
- Ensure you are logged into Docker Hub (`docker login`).
- Restart Docker Desktop or the Docker daemon.
- Check your network connection.

### Debugging Scripts

If the operational scripts (`run.sh`, `install-service.sh`, etc.) are not behaving as expected or exiting prematurely, you can enable verbose debug output by prefixing the command with `DEBUG=1`

```bash
DEBUG=1 ./scripts/run.sh --force-rebuild --token YOUR_TOKEN
DEBUG=1 sudo ./scripts/install-service.sh --tests
```

This will print detailed step-by-step information (lines starting with `DEBUG:`) to help pinpoint where the script is failing.

## Project Structure

```
quit-smoking-bot/
├── src/                            # Source code directory
│   ├── __init__.py                 # Python package initialization
│   ├── bot.py                      # Main bot class and handlers (323 lines)
│   ├── config.py                    # Configuration and constants (85 lines)
│   ├── quotes.py                   # Quotes management (34 lines)
│   ├── status.py                   # Status information and calculations (85 lines)
│   ├── users.py                    # User management and storage (63 lines)
│   ├── utils.py                    # Utility functions and helpers (68 lines)
│   └── send_results.py             # Test results notification system (73 lines)
├── tests/                          # Tests directory
│   ├── __init__.py                 # Tests package initialization
│   ├── integration/                # Integration tests
│   │   ├── __init__.py             # Integration tests package initialization
│   │   └── test_notifications.py    # Notification system tests
│   └── unit/                       # Unit tests
│       ├── __init__.py             # Unit tests package initialization
│       └── test_utils.py           # Utility functions tests
├── development/                    # Development environment (see development/README.md)
│   ├── README.md                   # Development environment documentation
│   ├── start-dev.sh                # Quick start script for dev environment
│   ├── Dockerfile                  # Ubuntu 22.04 development image
│   ├── docker-compose.yml          # Development container orchestration
│   ├── Makefile                    # Development commands
│   └── scripts/                    # Development helper scripts
│       ├── setup-env.sh            # Environment setup inside container
│       └── test-scripts.sh         # Comprehensive script testing
├── scripts/                        # Shell scripts for operations
│   ├── check-service.sh            # Comprehensive service status check (418 lines)
│   ├── common.sh                   # Common functions used by other scripts (832 lines)
│   ├── entrypoint.sh               # Container entrypoint script (223 lines)
│   ├── healthcheck.sh              # Container health check (185 lines)
│   ├── install-service.sh          # Systemd service installation (255 lines)
│   ├── run.sh                      # Start bot script (75 lines)
│   ├── stop.sh                     # Stop bot script (60 lines)
│   ├── test.sh                     # Run tests script (40 lines)
│   └── uninstall-service.sh        # Service removal script (125 lines)
├── data/                           # Data storage directory (persistent)
│   ├── bot_users.json              # Registered users data
│   ├── bot_admins.json             # Admin users data
│   └── quotes.json                 # Motivational quotes data
├── logs/                           # Log files directory
│   └── bot.log                     # Main bot log file
├── main.py                         # Legacy entry point (redirects to src/bot.py)
├── setup.py                        # Python package configuration (18 lines)
├── Dockerfile                       # Docker container configuration (60 lines)
├── docker-compose.yml              # Docker Compose services definition (68 lines)
├── .dockerignore                   # Docker build exclude patterns (65 lines)
├── .gitignore                      # Git exclude patterns (40 lines)
└── README.md                       # This documentation file
```

The project follows a modular structure with clear separation of concerns:

- **Core Bot Logic** (`src/`): Handles bot commands, user management, and status calculations
- **Testing** (`tests/`): Contains both unit and integration tests
- **Development Environment** (`development/`): Docker-based cross-platform development tools
- **Operations** (`scripts/`): Shell scripts for running, installing, and managing the bot
- **Configuration** (`Dockerfile`, `docker-compose.yml`): Docker container setup
- **Persistence** (`data/`): Stores user data and quotes

## Development Environment

For cross-platform development and testing, this project includes a complete Docker-based development environment. This is particularly useful for:

- **Testing on any OS**: Run Linux environment on macOS, Windows, or any system with Docker
- **systemd testing**: Test service installation and management without affecting your host system
- **Consistent environment**: Ensure all developers work in the same environment
- **Safe experimentation**: Test scripts and configurations in isolated containers

**Quick Start:**
```bash
# Interactive Linux development environment
./development/start-dev.sh

# With systemd support for service testing
./development/start-dev.sh --systemd
```

**See [development/README.md](development/README.md) for complete documentation including:**
- Detailed usage instructions for `start-dev.sh`
- Available development environments (standard vs systemd)
- Testing workflows and best practices
- Makefile commands and Docker Compose usage
- Troubleshooting common issues

The `entrypoint.sh` script is used as the container's entry point and handles:
- Environment variable setup
- Log directory creation
- Prevention of multiple bot processes
- Bot startup with proper configuration
- Signal handling for graceful shutdown

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

While the current implementation has limited support for macOS and primarily targets Linux, future versions will include:

- **Full macOS Support**: Improved service management and native integration
- **Windows Support**: Adding Windows compatibility for broader user adoption
- **Cross-platform Abstractions**: Using Python to create OS-independent operational scripts

This extended platform support will primarily be enabled by the migration to Python-based scripts, which offer better cross-platform capabilities than Bash.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Development Environment Setup

To set up the development environment for this project:

```bash
# Install development dependencies
python3 -m pip install -r requirements-dev.txt
```

This will install all necessary libraries, including setuptools, and configure the project for development.

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

Commit message formatting is enforced using a Git hook managed by `pre-commit`. See the "Pre-commit Hooks" section below.

## Pre-commit Hooks

This project uses `pre-commit` to manage Git hooks that run checks before commits are made. This helps maintain code quality and consistency.

**Installation:**

1. Ensure you have set up the [Development Environment](#development-environment-setup).
2. Install the Git hooks:
   ```bash
   pre-commit install --hook-type commit-msg --hook-type pre-commit
   ```

Now, the configured checks (like commit message linting) will run automatically when you run `git commit`.
