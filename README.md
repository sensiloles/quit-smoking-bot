# Quit Smoking Telegram Bot

A specialized Telegram bot to track your smoke-free journey with a progressive prize fund system and motivational support.

## 🌟 Features

- 📊 **Progress Tracking**: Monitor your smoke-free period (years, months, days)
- 💰 **Prize Fund System**: Growing monthly reward system (starts at 5,000₽, increases by 5,000₽ monthly)
- 📅 **Monthly Notifications**: Automated motivational messages every 23rd of the month
- 💭 **Motivational Quotes**: Random inspirational quotes to keep you motivated
- 👥 **Admin System**: Multi-admin support for bot management
- 🐳 **Docker-Ready**: Production containerized deployment
- 🔧 **Simple Management**: One-command interface via `manager.py`
- 📊 **Health Monitoring**: Built-in health checks and logging

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd quit-smoking-bot

# Initial setup (creates .env template and directories)
python3 manager.py setup
```

### 2. Configure Your Bot
```bash
# Edit .env file with your bot token
# Get token from @BotFather on Telegram
nano .env
```

Set your configuration in `.env`:
```env
BOT_TOKEN="your_bot_token_here"
SYSTEM_NAME="quit-smoking-bot"
TZ="UTC"
```

### 3. Start the Bot
```bash
# Start with Docker (recommended)
python3 manager.py start

# Or use Makefile
make start
```

That's it! Your quit smoking bot is now running and ready to help users track their smoke-free journey.

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

### Using manager.py (Recommended)
```bash
python3 manager.py setup     # Initial setup
python3 manager.py start     # Start the bot
python3 manager.py stop      # Stop the bot
python3 manager.py restart   # Restart the bot
python3 manager.py status    # Show status
python3 manager.py logs      # Show logs
python3 manager.py logs -f   # Follow logs
python3 manager.py clean     # Clean up
```

### Using Makefile
```bash
make setup          # Initial setup
make install        # Setup + start
make start          # Start the bot  
make stop           # Stop the bot
make restart        # Restart the bot
make status         # Show status
make logs           # Show logs
make logs-follow    # Follow logs
make clean          # Clean up
make dev            # Run locally (without Docker)
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
├── data/                  # Persistent data (auto-created)
│   ├── bot_users.json     # Registered users
│   ├── bot_admins.json    # Administrator list
│   └── quotes.json        # Motivational quotes
├── logs/                  # Application logs (auto-created)
├── scripts/               # Monitoring and utility scripts
├── manager.py             # Simple management tool
├── main.py               # Entry point
├── pyproject.toml        # Python project configuration
├── requirements.txt      # Dependencies
├── docker-compose.yml    # Docker orchestration
├── Dockerfile           # Container definition
├── Makefile            # Command shortcuts
└── README.md          # This file
```

## 📚 Development

### Local Development (without Docker)
```bash
# Install dependencies
pip install -e .

# Run locally
make dev
# or
python3 main.py
```

### Docker Development
```bash
# Build and start
make start

# View logs
make logs-follow

# Shell into container
docker exec -it quit-smoking-bot bash

# Restart after changes
make restart
```

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

# Setup and configure
python3 manager.py setup
# Edit .env with your production bot token
python3 manager.py start
```

### Updates
```bash
git pull
python3 manager.py restart
```

### Monitoring
```bash
# Check status
python3 manager.py status

# View logs
python3 manager.py logs

# Follow logs in real-time
python3 manager.py logs -f
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

## 🔍 Troubleshooting

### Bot won't start
```bash
# Check status and logs
python3 manager.py status
python3 manager.py logs

# Common issues:
# 1. BOT_TOKEN not set in .env
# 2. Docker not running
# 3. Invalid start date configuration
```

### Docker issues
```bash
# Clean up and rebuild
python3 manager.py clean
python3 manager.py start
```

### Development issues
```bash
# Run locally to debug
make dev
```

### Notifications not working
- Check timezone configuration in `.env`
- Verify notification schedule in `src/config.py`
- Check logs for scheduler errors: `python3 manager.py logs`

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