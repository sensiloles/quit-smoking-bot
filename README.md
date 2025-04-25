# Quit Smoking Assistant Bot

This Telegram bot helps track your smoke-free period and sends monthly progress notifications.

## Features

- Tracking of smoke-free period (years/months/days)
- Prize fund calculation (5000 rubles × number of months)
- Monthly motivational messages
- Automatic notifications daily at 16:00 Novosibirsk time
- Command to check current status
- Dynamic user tracking (notifications are sent to everyone who started a dialog with the bot)
- Administrator system for bot management
- Random motivational quotes that don't repeat consecutively

## Setup and Launch

### Local Development

1. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Launch the bot with your Telegram bot token (required):
   ```
   python bot.py --token=YOUR_BOT_TOKEN
   ```

   Alternatively, you can set the BOT_TOKEN environment variable: 
   ```
   export BOT_TOKEN=YOUR_BOT_TOKEN
   python bot.py
   ```

3. The first user to interact with the bot will automatically become an admin

### Server Deployment

For deployment on a server, you can use the included `deploy.sh` script:

1. Transfer all files to your server (e.g., using scp or git)
2. Make the script executable:
   ```
   chmod +x deploy.sh
   ```
3. Run the deployment script as root with your bot token (required):
   ```
   sudo ./deploy.sh --token=YOUR_BOT_TOKEN
   ```

By default, the deployment runs in automated mode without any prompts.

#### Interactive Deployment

If you prefer to be prompted for confirmations during deployment, use the interactive mode:

```
sudo ./deploy.sh --token=YOUR_BOT_TOKEN --interactive
```

This mode will:
- Prompt you for confirmation at each key step
- Ask if you want to run notification tests
- Ask if you want to send test messages to admins

The deployment script will:
- Configure Git settings
- Install required packages
- Set up a virtual environment
- Install dependencies
- Create a systemd service with the provided token
- Configure timezone to Asia/Novosibirsk
- Start the bot service
- Run optional tests

After deployment, you can manage the bot with:
- `systemctl start/stop/restart telegrambot` - Control the bot service
- `journalctl -u telegrambot -f` - View bot logs

## Configuration Options

### Start Date
The default start date is January 24, 2025. To change it, edit the `START_DATE` variable in bot.py.

### Timezone
The bot uses the Asia/Novosibirsk timezone. The deployment script sets the server to this timezone automatically.

## Configuration Files

The bot uses several data files:
- `quotes.json` - List of motivational quotes
- `quotes_history.json` - Tracks last used quotes to prevent repetition
- `bot_users.json` - List of registered users
- `bot_admins.json` - List of admin users

## Commands

- `/start` - Start using the bot
- `/status` - Check current status
- `/notify_all` - Send notifications to all users (admin only)
- `/list_users` - Show list of all users (admin only)
- `/list_admins` - Show list of administrators (admin only)
