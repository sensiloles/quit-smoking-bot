import datetime
import os
from pathlib import Path
from zoneinfo import ZoneInfo

# Timezone settings - configurable via environment variable
DEFAULT_TIMEZONE = os.getenv("TZ", "UTC")
TIMEZONE = ZoneInfo(DEFAULT_TIMEZONE)

# Main timezone variable for the bot
BOT_TIMEZONE = TIMEZONE

# Start date components
START_YEAR = 2025
START_MONTH = 1

# Notification schedule - 23rd of each month at 21:58
NOTIFICATION_DAY = 23  # day of month
NOTIFICATION_HOUR = 21  # hour (24-hour format)
NOTIFICATION_MINUTE = 58  # minute

# Start date - January 23, 2025 at 21:58 (timezone-aware)
START_DATE = datetime.datetime(
    START_YEAR,
    START_MONTH,
    NOTIFICATION_DAY,
    NOTIFICATION_HOUR,
    NOTIFICATION_MINUTE,
    tzinfo=BOT_TIMEZONE,
)

# Prize fund settings
MONTHLY_AMOUNT = 5000  # amount in rubles
PRIZE_FUND_INCREASE = 5000  # increase amount per month
MAX_PRIZE_FUND = 100000  # maximum prize fund amount

# Bot settings
BOT_NAME = "Quit Smoking Bot"
USER_COMMANDS = ["/start", "/status", "/my_id"]
ADMIN_COMMANDS = [
    "/notify_all",
    "/list_users",
    "/list_admins",
    "/add_admin",
    "/remove_admin",
    "/decline_admin",
] + USER_COMMANDS

# Message templates
WELCOME_MESSAGE = (
    "👋 Welcome to {bot_name}!\n\n"
    "I'll help you track your smoke-free period and motivate you with quotes. "
    "You'll also get a prize fund that increases every month!\n\n"
    "Use /start to begin tracking your progress."
)

STATUS_MESSAGE = (
    "📊 Your current status:\n\n"
    "🚭 Smoke-free period: {years} years, {months} months, {days} days\n"
    "💰 Current prize fund: {prize_fund} rubles\n"
    "📅 Next increase: {next_increase_date} at {next_increase_time} {timezone}\n"
    "➕ Next increase amount: +{increase_amount} rubles\n\n"
    "💭 {quote}"
)

# File paths - автоматическое определение окружения
if Path("/app").exists():
    # Docker environment
    BASE_DIR = Path("/app")
else:
    # Local environment
    BASE_DIR = Path(__file__).parent.parent.absolute()

DATA_DIR = BASE_DIR / "data"

USERS_FILE = DATA_DIR / "bot_users.json"
ADMINS_FILE = DATA_DIR / "bot_admins.json"
QUOTES_FILE = DATA_DIR / "quotes.json"

# Logging configuration
LOG_DIR = BASE_DIR / "logs"
LOG_FILE = LOG_DIR / "bot.log"

# Создаем необходимые директории при импорте модуля
LOG_DIR.mkdir(exist_ok=True)
DATA_DIR.mkdir(exist_ok=True)

LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {"format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s"},
    },
    "handlers": {
        "file": {
            "class": "logging.FileHandler",
            "filename": str(LOG_FILE),
            "formatter": "default",
        },
        "console": {"class": "logging.StreamHandler", "formatter": "default"},
    },
    "root": {"handlers": ["file", "console"], "level": "INFO"},
}
