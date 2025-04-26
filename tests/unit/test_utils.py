#!/usr/bin/env python3
import os
import sys
import logging
import importlib.util
import argparse
from datetime import datetime
import pytz

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Cache for bot module and instance
_bot_module = None
_bot_instance = None

def setup_logging():
    """Sets up logging configuration for tests"""
    # Add handler for writing to test_log.txt file
    file_handler = logging.FileHandler("test_log.txt", mode="w")
    file_handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))
    logger.addHandler(file_handler)

def log_to_file(message, level="INFO"):
    """Writes a message to the test_log.txt file"""
    with open("test_log.txt", "a") as log_file:
        log_file.write(f"{datetime.now()} - {level} - {message}\n")

def load_bot_module():
    """Loads the bot module and returns it"""
    global _bot_module
    
    if _bot_module is not None:
        return _bot_module
        
    try:
        # Check if running in Docker
        in_container = os.path.exists('/.dockerenv')
        if in_container:
            bot_path = "/app/src/bot.py"
        else:
            bot_path = "src/bot.py"

        # Add the parent directory to Python path
        parent_dir = os.path.dirname(os.path.dirname(bot_path))
        if parent_dir not in sys.path:
            sys.path.insert(0, parent_dir)

        # Import the module using importlib
        spec = importlib.util.spec_from_file_location("bot", bot_path)
        _bot_module = importlib.util.module_from_spec(spec)
        sys.modules["bot"] = _bot_module
        spec.loader.exec_module(_bot_module)
        
        logger.info("✅ bot.py module successfully loaded")
        return _bot_module
    except Exception as e:
        logger.error(f"Error loading bot.py module: {e}")
        raise

def get_bot_instance():
    """Gets a single instance of the bot"""
    global _bot_instance
    
    if _bot_instance is not None:
        return _bot_instance
        
    try:
        bot_module = load_bot_module()
        _bot_instance = bot_module.QuitSmokingBot()
        return _bot_instance
    except Exception as e:
        logger.error(f"Error creating bot instance: {e}")
        raise

def get_bot_token(args):
    """Gets the bot token from various sources"""
    try:
        # Use provided token if available
        if args.token:
            logger.info("Using token provided via command line")
            return args.token
        
        # Try environment variable
        if os.environ.get('BOT_TOKEN'):
            logger.info("Using token from environment variable")
            return os.environ['BOT_TOKEN']
        
        # Try bot module
        bot_module = load_bot_module()
        token = bot_module.BOT_TOKEN
        logger.info("Token retrieved from bot module")
        return token
    except Exception as e:
        logger.error(f"Error getting bot token: {e}")
        raise

def get_admin_users():
    """Gets the list of admin users from the bot module"""
    try:
        bot = get_bot_instance()
        admins = bot.user_manager.get_all_admins()
        logger.info(f"Admin list retrieved: {admins}")
        return admins
    except Exception as e:
        logger.error(f"Error getting admin users: {e}")
        raise

def check_system_timezone():
    """Checks if the system timezone is set correctly to Asia/Novosibirsk"""
    try:
        # Check if we're in a container environment
        in_container = os.environ.get("IN_CONTAINER") == "true"
        
        if in_container:
            # In container, check TZ environment variable
            container_tz = os.environ.get("TZ")
            logger.info(f"Container environment detected, using TZ environment variable: {container_tz}")
            
            if container_tz != "Asia/Novosibirsk":
                raise ValueError(f"Container timezone is {container_tz}, expected Asia/Novosibirsk")
            
            logger.info("✅ Container timezone is correctly set (Asia/Novosibirsk)")
        else:
            # On host, check system timezone
            system_tz = datetime.now().astimezone().tzinfo
            if str(system_tz) != "Asia/Novosibirsk":
                raise ValueError(f"System timezone is {system_tz}, expected Asia/Novosibirsk")
            
            logger.info("✅ System timezone is correctly set (Asia/Novosibirsk)")
    except Exception as e:
        logger.error(f"Error checking system timezone: {e}")
        raise

def get_scheduler_settings():
    """Gets the scheduler settings from the bot module"""
    try:
        bot_module = load_bot_module()
        return (
            bot_module.NOTIFICATION_DAY,
            bot_module.NOTIFICATION_HOUR,
            bot_module.NOTIFICATION_MINUTE
        )
    except Exception as e:
        logger.error(f"Error getting scheduler settings: {e}")
        raise 