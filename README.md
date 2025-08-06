# Quit Smoking Telegram Bot

A specialized Telegram bot to track your smoke-free journey with a progressive prize fund system and motivational support.

## 🌟 Features

### 🎯 Core Bot Features
- 📊 **Progress Tracking**: Monitor your smoke-free period (years, months, days)
- 💰 **Prize Fund System**: Growing monthly reward system (starts at 5,000₽, increases by 5,000₽ monthly)
- 📅 **Monthly Notifications**: Automated motivational messages every 23rd of the month
- 💭 **Motivational Quotes**: Random inspirational quotes to keep you motivated
- 👥 **Admin System**: Multi-admin support for bot management

### 🛡️ Production-Grade Infrastructure  
- 🐳 **Docker-Ready**: Advanced production containerization with entrypoint
- ⚡ **Optimized Caching**: Docker layer caching for faster rebuilds
- 🔧 **Unified Management**: Single-command interface via `manager.py`
- 📊 **Health Monitoring**: Real-time health checks and continuous monitoring
- 🔄 **Log Management**: Automatic log rotation and archiving
- 🔄 **Auto-Recovery**: Process management and graceful restarts
- 🛠️ **Environment Setup**: Automated initialization and permission management
- 📦 **Modern Packaging**: pyproject.toml-based dependency management

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd quit-smoking-bot

# Complete setup with bot token
python3 manager.py setup --token "YOUR_BOT_TOKEN_HERE"
```

### 2. Start the Bot
```bash
# Start the bot (recommended)
python3 manager.py start

# Or start with advanced monitoring
python3 manager.py start --monitoring

# Or use convenient shortcuts
make install              # Complete setup and start
```

### 3. Verify Everything Works
```bash
# Check bot status
python3 manager.py status

# View logs
python3 manager.py logs --follow
```

That's it! Your quit smoking bot is now running with comprehensive monitoring and ready to help users track their smoke-free journey.

## 📖 How It Works

### Starting Date Configuration
The bot tracks progress from a predefined start date (January 23, 2025 at 21:58 by default).
Configure this in `src/config.py`:

```python
START_YEAR = 2025
START_MONTH = 1
NOTIFICATION_DAY = 23  # day of month
NOTIFICATION_HOUR = 21  # hour (24-hour format)
NOTIFICATION_MINUTE = 58  # minute
```

### Prize Fund System
- **Initial Amount**: 5,000₽ per month
- **Monthly Increase**: +5,000₽ each month
- **Maximum Cap**: 100,000₽
- **Calculation**: Based on completed months since start date

Example progression:
- Month 1: 5,000₽
- Month 2: 10,000₽
- Month 3: 15,000₽
- ...
- Month 20: 100,000₽ (maximum)

### Automated Notifications
The bot sends monthly motivational messages to all users on the 23rd of each month at 21:58 (configurable timezone).

## 🤖 Bot Commands

### User Commands
- `/start` - Register with the bot and get welcome message
- `/status` - View current smoke-free progress and prize fund
- `/my_id` - Get your Telegram user ID

### Admin Commands
- `/notify_all` - Manually send notifications to all users
- `/list_users` - View all registered users
- `/list_admins` - View all administrators
- `/add_admin USER_ID` - Add a new administrator
- `/remove_admin USER_ID` - Remove an administrator
- `/decline_admin` - Decline your own admin privileges

## 🛠️ Management Commands

### Primary Interface (manager.py)
```bash
# 📦 Setup & Configuration
python3 manager.py setup                    # Basic setup
python3 manager.py setup --token TOKEN      # Setup with bot token

# 🚀 Service Management  
python3 manager.py start                    # Start the bot (production)
python3 manager.py start --env dev          # Start in development mode
python3 manager.py start --monitoring       # Start with health monitoring
python3 manager.py start --rebuild          # Start with container rebuild
python3 manager.py stop                     # Stop the bot
python3 manager.py restart                  # Restart the bot

# 📊 Monitoring & Status
python3 manager.py status                   # Show comprehensive status
python3 manager.py logs                     # Show recent logs
python3 manager.py logs --follow            # Follow logs in real-time

# 🧹 Maintenance
python3 manager.py clean                    # Basic cleanup
python3 manager.py clean --deep             # Remove all data and images
```

### Convenient Shortcuts (Makefile)
```bash
# 🎯 Quick Operations
make install        # Complete setup and start with monitoring
make start          # Start the bot (production)
make start-dev      # Start in development mode
make stop           # Stop the bot
make restart        # Restart the bot
make status         # Show status
make logs-follow    # Follow logs in real-time
make clean          # Basic cleanup
make clean-deep     # Deep cleanup

# 🔧 Advanced Operations
make monitor        # Advanced monitoring and diagnostics
make health         # Quick health check
make token          # Set bot token interactively
```

## ⚙️ Configuration

### Environment Variables (.env)
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BOT_TOKEN` | ✅ | - | Your Telegram bot token from BotFather |
| `SYSTEM_NAME` | No | quit-smoking-bot | Container name prefix |
| `TZ` | No | UTC | Timezone for notifications |

### Bot Configuration (src/config.py)
```python
# Start date components
START_YEAR = 2025
START_MONTH = 1

# Notification schedule - 23rd of each month at 21:58
NOTIFICATION_DAY = 23
NOTIFICATION_HOUR = 21
NOTIFICATION_MINUTE = 58

# Prize fund settings
MONTHLY_AMOUNT = 5000       # amount in rubles
PRIZE_FUND_INCREASE = 5000  # increase amount per month
MAX_PRIZE_FUND = 100000     # maximum prize fund amount
```

## 🏗️ Project Structure

```
quit-smoking-bot/
├── src/                    # Bot implementation
│   ├── bot.py             # Main bot logic and handlers
│   ├── config.py          # Configuration settings
│   ├── quotes.py          # Motivational quotes manager
│   ├── status.py          # Progress tracking and prize calculation
│   ├── users.py           # User and admin management
│   └── utils.py           # Utility functions
├── docker/                # 🐳 Production Docker configuration
│   ├── Dockerfile         # Container definition
│   ├── docker-compose.yml # Base orchestration
│   ├── docker-compose.dev.yml # Development environment  
│   ├── docker-compose.prod.yml # Production environment
│   ├── entrypoint.py      # 🚀 Production initialization script
│   └── README.md          # Docker documentation → [see details](docker/README.md)
├── scripts/               # Advanced management system
│   ├── modules/           # Modular management components
│   │   ├── actions.py     # Core bot operations
│   │   ├── docker_utils.py # Docker integration
│   │   ├── health.py      # Health monitoring
│   │   ├── environment.py # Environment management
│   │   └── ...           # Other utility modules
│   └── monitor.py         # Advanced monitoring and diagnostics
├── data/                  # Persistent data (auto-created)
│   ├── bot_users.json     # Registered users
│   ├── bot_admins.json    # Administrator list
│   └── quotes.json        # Motivational quotes
├── logs/                  # Application logs (auto-created)
├── manager.py             # 🎯 Primary management interface
├── main.py               # Bot entry point
├── Makefile              # Convenient command shortcuts
├── pyproject.toml        # Python project configuration and dependencies
└── README.md            # This file
```

## 📚 Development

### Local Development (without Docker)
```bash
# Install dependencies from pyproject.toml
pip install -e .

# Run locally with modern interface
python3 manager.py setup --token "YOUR_TOKEN"
make dev
# or
python3 main.py --token "YOUR_TOKEN"
```

**Note**: Local development automatically uses the project directory for logs and data, while Docker uses `/app/` paths.

### Docker Development
```bash
# Quick start with monitoring
python3 manager.py start --monitoring

# View logs in real-time (includes entrypoint initialization logs)
python3 manager.py logs --follow

# Check detailed status
python3 manager.py status --detailed

# View health monitoring logs
docker exec quit-smoking-bot cat /app/logs/health.log

# Shell into container
docker exec -it quit-smoking-bot bash

# Restart with rebuild after changes (optimized for caching)
python3 manager.py restart --rebuild
```

**Docker Optimization**: The Docker setup is optimized for layer caching. When code hasn't changed, existing images are reused automatically, making rebuilds much faster.

📖 **For detailed Docker configuration and advanced usage**, see [docker/README.md](docker/README.md)

### Adding Motivational Quotes
Create or edit `data/quotes.json`:
```json
[
    "Every day without cigarettes is a victory over yourself.",
    "Your health is your wealth - you're investing wisely.",
    "Each smoke-free day adds time to your life."
]
```

## 🚀 Deployment

### Production Deployment
```bash
# On your server
git clone <your-repo-url>
cd quit-smoking-bot

# Complete setup with production token
python3 manager.py setup --token "YOUR_PRODUCTION_BOT_TOKEN"

# Start with monitoring and logging
python3 manager.py start --monitoring
```

### Updates
```bash
git pull
python3 manager.py restart --rebuild
```

**Efficient Updates**: Thanks to Docker layer caching, updates that don't change dependencies will reuse existing layers, making deployments much faster.

### Production Monitoring
```bash
# Comprehensive status check
python3 manager.py status

# Monitor logs continuously
python3 manager.py logs --follow

# Advanced monitoring and diagnostics
make monitor

# Quick health check
make health
```

## 👥 Admin Management

### First Admin Setup
The first user to interact with the bot (using `/start`) automatically becomes an administrator.

### Adding More Admins
1. Users must first register with `/start`
2. Existing admin uses `/add_admin USER_ID`
3. New admin receives notification with decline option
4. Commands are automatically updated in Telegram UI

### Admin Features
- Send manual notifications to all users
- View user and admin lists
- Add/remove administrators
- Access to all user commands plus admin-specific ones

## 🔧 Customization

### Changing the Start Date
Edit `src/config.py`:
```python
START_YEAR = 2025      # Your quit year
START_MONTH = 1        # Your quit month
NOTIFICATION_DAY = 23  # Day of month for notifications
```

### Modifying Prize Fund
Edit `src/config.py`:
```python
MONTHLY_AMOUNT = 5000       # Starting amount
PRIZE_FUND_INCREASE = 5000  # Monthly increase
MAX_PRIZE_FUND = 100000     # Maximum amount
```

### Timezone Configuration
Set in `.env` file:
```env
TZ="Europe/Moscow"  # or your preferred timezone
```

## 📋 Requirements

- Python 3.9+
- Docker and Docker Compose
- Telegram bot token from [@BotFather](https://t.me/BotFather)

### Dependencies Management
This project uses modern Python packaging with `pyproject.toml`:
- **Main dependencies**: Defined in `pyproject.toml`
- **Development tools**: Available via `pip install -e .[dev]`
- **No requirements.txt files**: All managed through pyproject.toml

## 🔍 Troubleshooting

### Bot won't start
```bash
# Check detailed status and diagnostics
python3 manager.py status --detailed

# View logs for errors
python3 manager.py logs

# Run comprehensive diagnostics
make monitor

# Common issues:
# 1. BOT_TOKEN not set - use: python3 manager.py setup --token "TOKEN"
# 2. Docker not running - check Docker service
# 3. Invalid configuration - check .env file
```

### Docker issues
```bash
# Deep cleanup and rebuild
python3 manager.py clean --deep
python3 manager.py start --rebuild

# Or use convenient shortcut
make clean-deep
make start
```

**Performance Tip**: If builds seem slow, the Docker layer cache might be corrupted. Use `docker system prune -f` to clear unused images and restart fresh.

### Development issues
```bash
# Run locally to debug
make dev

# Check health and diagnostics
make health
make monitor
```

### Notifications not working
- Check timezone configuration in `.env`
- Verify notification schedule in `src/config.py`
- Check logs for scheduler errors: `python3 manager.py logs --follow`
- Run diagnostics: `make monitor`

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test with `make dev`
4. Deploy with `make start`
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details.

---

**Stay strong in your smoke-free journey! 🚭💪**