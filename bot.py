import logging
import datetime
import pytz
import random
import json
import os
import sys
import argparse
import asyncio
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes
from apscheduler.schedulers.asyncio import AsyncIOScheduler

# Parse command line arguments
parser = argparse.ArgumentParser(description='Quit Smoking Assistant Bot')
parser.add_argument('--token', type=str, help='Telegram bot token')
args = parser.parse_args()

# Bot configuration
BOT_TOKEN = args.token if args.token else os.environ.get('BOT_TOKEN')
if not BOT_TOKEN:
    print("Error: No token provided. Please provide a token via --token argument or BOT_TOKEN environment variable.")
    sys.exit(1)

# Constants
START_DATE = datetime.datetime(2025, 1, 23, 21, 58)  # January 23, 2025 at 21:58
NOVOSIBIRSK_TZ = pytz.timezone('Asia/Novosibirsk')
NOTIFICATION_HOUR = 21  # Monthly notification hour (21:00)
NOTIFICATION_MINUTE = 58  # Monthly notification minute (:58)
NOTIFICATION_DAY = 23  # Monthly notification day (23rd of each month)
USERS_FILE = "bot_users.json"
ADMINS_FILE = "bot_admins.json"
QUOTES_HISTORY_FILE = "quotes_history.json"
QUOTES_FILE = "quotes.json"

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# File operations functions
def load_json_file(filename, default_value=None):
    """Generic function to load data from a JSON file."""
    if default_value is None:
        default_value = []
    
    if os.path.exists(filename):
        try:
            with open(filename, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Error loading from {filename}: {e}")
            return default_value
    else:
        logger.info(f"File {filename} not found, using default value")
        return default_value

def save_json_file(filename, data):
    """Generic function to save data to a JSON file."""
    try:
        with open(filename, 'w') as f:
            json.dump(data, f)
    except Exception as e:
        logger.error(f"Error saving to {filename}: {e}")

# Quotes management
def load_quotes():
    """Load motivational quotes from file."""
    quotes = load_json_file(QUOTES_FILE, [])
    
    # Create extended quotes list to cover 20 years (240 months)
    if quotes and len(quotes) < 240:
        extended_quotes = quotes.copy()
        for i in range(len(quotes), 240):
            extended_quotes.append(quotes[i % len(quotes)])
        return extended_quotes
    return quotes

def get_random_quote(user_id="global"):
    """Get a random quote that is different from the last one used for this user."""
    if not QUOTES or len(QUOTES) <= 1:
        return "Each day without cigarettes is a victory over yourself. - Mark Twain"
    
    # Get last used quote for this user
    last_quote = last_used_quotes.get(user_id, "")
    
    # Generate a list of available quotes (excluding the last one used)
    available_quotes = [q for q in QUOTES if q != last_quote]
    
    # Select a random quote from available quotes
    new_quote = random.choice(available_quotes)
    
    # Save this as the last used quote for this user
    last_used_quotes[user_id] = new_quote
    save_json_file(QUOTES_HISTORY_FILE, last_used_quotes)
    
    return new_quote

# User and admin management
def load_users():
    """Load registered users from file."""
    return load_json_file(USERS_FILE, [])

def save_users(users):
    """Save registered users to file."""
    save_json_file(USERS_FILE, users)

def load_admins():
    """Load admin users from file."""
    admins = load_json_file(ADMINS_FILE, [])
    if not admins:
        logger.warning("Admins list is empty, first user to interact will become admin")
    return admins

def save_admins(admins):
    """Save admin users to file."""
    save_json_file(ADMINS_FILE, admins)

# Time and status calculation functions
def calculate_period(start_date: datetime.datetime, end_date: datetime.datetime) -> tuple:
    """Calculate years, months and days between two dates."""
    years = end_date.year - start_date.year
    months = end_date.month - start_date.month
    days = end_date.day - start_date.day
    
    if days < 0:
        # Borrow from months
        months -= 1
        # Add days from previous month
        last_day = (end_date.replace(day=1) - datetime.timedelta(days=1)).day
        days += last_day
    
    if months < 0:
        # Borrow from years
        years -= 1
        months += 12
        
    return years, months, days

def calculate_prize_fund(months: int) -> int:
    """Calculate the prize fund based on the number of months.
    
    Prize fund values:
    - January 23, 2025 (month 0): 5000 rubles
    - February 23, 2025 (month 1): 10000 rubles
    - March 23, 2025 (month 2): 15000 rubles
    - April 23, 2025 (month 3): 20000 rubles
    and so on...
    """
    if months < 0:
        return 0
    
    # Starting with 5000, increases by 5000 each month
    # Month 0 = 5000, month 1 = 10000, month 2 = 15000, etc.
    base_amount = 5000
    return base_amount * (months + 1)

def get_status_info(user_id="global") -> str:
    """Generate status information about the non-smoking period."""
    now = datetime.datetime.now(NOVOSIBIRSK_TZ)
    duration = now - START_DATE.replace(tzinfo=NOVOSIBIRSK_TZ)
    
    # If we haven't reached the start date yet
    if duration.total_seconds() < 0:
        return f"The smoke-free period hasn't started yet. Start date: {START_DATE.strftime('%d.%m.%Y %H:%M')}"
    
    # Calculate years, months and days
    years, months, days = calculate_period(START_DATE, now)
    
    # Calculate prize fund - using the current month, not months elapsed
    # If we're on or past the 23rd of the month, we count the current month fully
    # Otherwise, we count up to the previous month
    current_month_idx = 0
    if now.day >= NOTIFICATION_DAY:
        # If we're on or past the notification day, count current month fully
        current_month_idx = years * 12 + months
    else:
        # If we're before the notification day, count up to previous month
        current_month_idx = years * 12 + months - 1
        
    # Make sure we never go below 0 (for the very start)
    current_month_idx = max(0, current_month_idx)
    
    prize_fund = calculate_prize_fund(current_month_idx)
    
    # Get next prize fund amount
    next_prize_fund = calculate_prize_fund(current_month_idx + 1)
    prize_increase = next_prize_fund - prize_fund
    
    # Calculate date of next prize fund increase
    # Move to next month's 23rd
    if now.day <= NOTIFICATION_DAY:
        # If today is before or on the 23rd of the current month
        next_date = now.replace(day=NOTIFICATION_DAY, hour=NOTIFICATION_HOUR, minute=NOTIFICATION_MINUTE, second=0, microsecond=0)
    else:
        # If today is after the 23rd, move to next month
        if now.month == 12:
            next_date = now.replace(year=now.year + 1, month=1, day=NOTIFICATION_DAY, 
                                    hour=NOTIFICATION_HOUR, minute=NOTIFICATION_MINUTE, second=0, microsecond=0)
        else:
            next_date = now.replace(month=now.month + 1, day=NOTIFICATION_DAY, 
                                    hour=NOTIFICATION_HOUR, minute=NOTIFICATION_MINUTE, second=0, microsecond=0)
    
    # Calculate days until next update
    days_until_next = (next_date - now).days + (1 if (next_date - now).seconds > 0 else 0)
    
    # Get random motivational quote that's different from the last one
    quote = get_random_quote(user_id)
    
    # Format the message
    if years > 0:
        period_text = f"{years} {'year' if years == 1 else 'years'}, "
    else:
        period_text = ""
        
    period_text += f"{months} {'month' if months == 1 else 'months'} and "
    period_text += f"{days} {'day' if days == 1 else 'days'}"
    
    message = (
        f"🚭 Smoke-free for: {period_text}\n"
        f"📅 Start date: {START_DATE.strftime('%d.%m.%Y %H:%M')}\n"
        f"💰 Current prize fund: {prize_fund} rubles\n"
        f"⏱️ Next increase: +{prize_increase} rubles in {days_until_next} {'day' if days_until_next == 1 else 'days'} "
        f"({next_date.strftime('%d.%m.%Y')})\n\n"
        f"💪 {quote}"
    )
    
    return message

# Initialize data
QUOTES = load_quotes()
registered_users = load_users()
admin_users = load_admins()
last_used_quotes = load_json_file(QUOTES_HISTORY_FILE, {})

# Bot command handlers
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /start is issued."""
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name
    
    # If this is the first user ever and no admins exist, make them admin
    if not admin_users:
        admin_users.append(user_id)
        save_admins(admin_users)
        logger.info(f"First user {user_id} set as admin")
        await update.message.reply_text(
            f"Hello, {user_name}! I will help you track your smoke-free period.\n"
            f"Start date: {START_DATE.strftime('%d.%m.%Y %H:%M')}\n"
            "Use /status to check your current status.\n\n"
            "You have been set as the first administrator of the bot."
        )
    else:
        await update.message.reply_text(
            f"Hello, {user_name}! I will help you track your smoke-free period.\n"
            f"Start date: {START_DATE.strftime('%d.%m.%Y %H:%M')}\n"
            "Use /status to check your current status."
        )
    
    # Add user to the list if not already there
    if user_id not in registered_users:
        registered_users.append(user_id)
        save_users(registered_users)
        logger.info(f"New user added: {user_id}")

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send current non-smoking status when the command /status is issued."""
    user_id = update.effective_user.id
    status_info = get_status_info(str(user_id))
    await update.message.reply_text(status_info)

async def send_monthly_notification(context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send monthly notifications to all users."""
    logger.info("send_monthly_notification function called at %s", datetime.datetime.now(NOVOSIBIRSK_TZ).strftime('%Y-%m-%d %H:%M:%S'))
    
    # Use global random quote for notifications
    status_info = get_status_info("monthly_notification")
    
    # Log users count
    logger.info("Preparing to send monthly notifications to %d users", len(registered_users))
    
    # Send to all registered users
    for user_id in registered_users:
        try:
            await context.bot.send_message(chat_id=user_id, text=status_info)
            logger.info(f"Monthly notification sent to user {user_id}")
        except Exception as e:
            logger.error(f"Failed to send notification to user {user_id}: {e}")
    
    logger.info("Monthly notification sending completed")

async def manual_notification(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Manually send notifications to all users (admin command)."""
    user_id = update.effective_user.id
    
    if user_id in admin_users:
        await send_monthly_notification(context)
        await update.message.reply_text("Notifications sent to all users.")
    else:
        await update.message.reply_text("You don't have permission to use this command.")

async def list_users(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """List all registered users (admin command)."""
    user_id = update.effective_user.id
    
    if user_id in admin_users:
        if not registered_users:
            await update.message.reply_text("No registered users yet.")
            return
            
        users_text = "List of users:\n"
        for i, uid in enumerate(registered_users, 1):
            users_text += f"{i}. {uid}\n"
        
        await update.message.reply_text(users_text)
    else:
        await update.message.reply_text("You don't have permission to use this command.")

async def list_admins(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """List all admin users (admin command)."""
    user_id = update.effective_user.id
    
    if user_id in admin_users:
        if not admin_users:
            await update.message.reply_text("The admin list is empty.")
            return
            
        admins_text = "List of administrators:\n"
        for i, uid in enumerate(admin_users, 1):
            admins_text += f"{i}. {uid}\n"
        
        await update.message.reply_text(admins_text)
    else:
        await update.message.reply_text("You don't have permission to use this command.")

def main() -> None:
    """Start the bot."""
    # Log token information (but not the actual token for security)
    token_source = "command line argument" if args.token else "environment variable"
    logger.info(f"Using token from {token_source}")
    
    # Create the Application
    application = Application.builder().token(BOT_TOKEN).build()

    # Add command handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("status", status))
    application.add_handler(CommandHandler("notify_all", manual_notification))
    application.add_handler(CommandHandler("list_users", list_users))
    application.add_handler(CommandHandler("list_admins", list_admins))

    # Setup scheduler for monthly notifications on the 23rd at 21:58 Novosibirsk time
    scheduler = AsyncIOScheduler(timezone=NOVOSIBIRSK_TZ)
    
    # Wrapper function to properly handle the async call
    def notification_job():
        logger.info("Scheduler triggered notification_job at %s", datetime.datetime.now(NOVOSIBIRSK_TZ).strftime('%Y-%m-%d %H:%M:%S'))
        try:
            # Create a new event loop for this job
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            # Run the async function until completion
            loop.run_until_complete(send_monthly_notification(application))
            
            # Close the loop
            loop.close()
            
            logger.info("Successfully completed monthly notification")
        except Exception as e:
            logger.error("Error in notification_job: %s", str(e))
    
    # Use the exact format that the test script is looking for, with monthly schedule
    scheduler.add_job(
        notification_job, 
        'cron', 
        day=NOTIFICATION_DAY,  # Run on the 23rd of each month
        hour=NOTIFICATION_HOUR,
        minute=NOTIFICATION_MINUTE,
        timezone=NOVOSIBIRSK_TZ,
        id='monthly_notification'
    )
    
    # Calculate and log the next notification time
    now = datetime.datetime.now(NOVOSIBIRSK_TZ)
    next_run = now.replace(day=NOTIFICATION_DAY, hour=NOTIFICATION_HOUR, minute=NOTIFICATION_MINUTE, second=0, microsecond=0)
    
    # If the day has already passed this month, move to next month
    if next_run <= now:
        # Move to next month
        if now.month == 12:
            next_run = next_run.replace(year=now.year + 1, month=1)
        else:
            next_month = now.month + 1
            next_run = next_run.replace(month=next_month)
    
    logger.info("Bot started at %s", now.strftime('%Y-%m-%d %H:%M:%S %Z'))
    logger.info("Next scheduled notification will be sent at: %s", next_run.strftime('%Y-%m-%d %H:%M:%S %Z'))
    logger.info(f"Scheduled monthly notification for day={NOTIFICATION_DAY}, {NOTIFICATION_HOUR}:{NOTIFICATION_MINUTE:02d} Novosibirsk time")
    scheduler.start()

    # Run the bot until the user presses Ctrl-C
    application.run_polling()

if __name__ == "__main__":
    main()
