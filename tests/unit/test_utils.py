#!/usr/bin/env python3
"""
Test utilities for bot testing

This module provides helper functions for loading the bot module, accessing
bot instances, and performing common test operations.
"""

import os
import sys
import logging
import importlib.util
from datetime import datetime

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)

# Cache for bot module and instance
_bot_module = None
_bot_instance = None


def setup_logging():
    """
    Sets up logging configuration for tests

    Creates file handlers and configures log formatting for test runs
    """
    # Add handler for writing to test_log.txt file
    file_handler = logging.FileHandler("test_log.txt", mode="w")
    file_handler.setFormatter(
        logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    )
    logger.addHandler(file_handler)

    # Set level to INFO
    logger.setLevel(logging.INFO)

    logger.info("Logging configuration initialized")


def log_to_file(message, level="INFO"):
    """
    Writes a message to the test_log.txt file

    Args:
        message (str): Message to log
        level (str): Log level (default: INFO)
    """
    with open("test_log.txt", "a") as log_file:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_file.write(f"{timestamp} - {level} - {message}\n")


def load_bot_module():
    """
    Loads the bot module and returns it

    Returns:
        module: The loaded bot module

    Raises:
        ImportError: If the bot module cannot be loaded
    """
    global _bot_module

    if _bot_module is not None:
        return _bot_module

    try:
        # Check if running in Docker
        in_container = (
            os.path.exists("/.dockerenv") or os.environ.get("IN_CONTAINER") == "true"
        )

        if in_container:
            bot_path = "/app/src/bot.py"
        else:
            # Try to find the bot.py file in the src directory
            if os.path.exists("src/bot.py"):
                bot_path = "src/bot.py"
            else:
                # Fall back to relative path from test directory
                bot_path = os.path.abspath(
                    os.path.join(
                        os.path.dirname(os.path.dirname(__file__)), "src/bot.py"
                    )
                )

                if not os.path.exists(bot_path):
                    raise ImportError(f"Could not find bot.py at {bot_path}")

        # Add the parent directory to Python path
        parent_dir = os.path.dirname(os.path.dirname(bot_path))
        if parent_dir not in sys.path:
            sys.path.insert(0, parent_dir)

        # Import the module using importlib
        spec = importlib.util.spec_from_file_location("bot", bot_path)
        if spec is None:
            raise ImportError(f"Could not create spec for {bot_path}")

        _bot_module = importlib.util.module_from_spec(spec)
        sys.modules["bot"] = _bot_module
        spec.loader.exec_module(_bot_module)

        logger.info("✅ bot.py module successfully loaded")
        return _bot_module
    except Exception as e:
        logger.error(f"Error loading bot.py module: {e}")
        raise


def get_bot_instance():
    """
    Gets a single instance of the bot

    Returns:
        QuitSmokingBot: An instance of the QuitSmokingBot class

    Raises:
        RuntimeError: If the bot instance cannot be created
    """
    global _bot_instance

    if _bot_instance is not None:
        return _bot_instance

    try:
        bot_module = load_bot_module()
        _bot_instance = bot_module.QuitSmokingBot()
        logger.info("✅ Bot instance created successfully")
        return _bot_instance
    except Exception as e:
        logger.error(f"Error creating bot instance: {e}")
        raise RuntimeError(f"Failed to create bot instance: {e}")


def get_bot_token(args):
    """
    Gets the bot token from various sources

    Args:
        args: Argument namespace containing optional token value

    Returns:
        str: The bot token

    Raises:
        ValueError: If the bot token is not found
    """
    try:
        # Use provided token if available
        if hasattr(args, "token") and args.token:
            logger.info("Using token provided via command line")
            return args.token

        # Try environment variable
        if os.environ.get("BOT_TOKEN"):
            logger.info("Using token from environment variable")
            return os.environ["BOT_TOKEN"]

        # Try bot module
        try:
            bot_module = load_bot_module()
            if hasattr(bot_module, "BOT_TOKEN") and bot_module.BOT_TOKEN:
                logger.info("Token retrieved from bot module")
                return bot_module.BOT_TOKEN
        except Exception as e:
            logger.warning(f"Could not get token from bot module: {e}")

        # No token found
        raise ValueError(
            "Bot token not found in command line args, environment variables, or bot module"
        )
    except Exception as e:
        logger.error(f"Error getting bot token: {e}")
        raise


def get_admin_users():
    """
    Gets the list of admin users from the bot module

    Returns:
        list: List of admin user IDs

    Raises:
        RuntimeError: If the admin list cannot be retrieved
    """
    try:
        bot = get_bot_instance()
        admins = bot.user_manager.get_all_admins()

        if not admins:
            logger.warning("Retrieved empty admin list")
        else:
            logger.info(f"Admin list retrieved: {admins}")

        return admins
    except Exception as e:
        logger.error(f"Error getting admin users: {e}")
        raise RuntimeError(f"Failed to get admin users: {e}")


def check_system_timezone():
    """
    Checks if the system timezone is set correctly to Asia/Novosibirsk

    Returns:
        bool: True if timezone is correct, False otherwise

    Raises:
        ValueError: If the timezone is incorrect
    """
    try:
        # Check if we're in a container environment
        in_container = os.environ.get("IN_CONTAINER") == "true"

        if in_container:
            # In container, check TZ environment variable
            container_tz = os.environ.get("TZ")
            logger.info(
                f"Container environment detected, using TZ environment variable: {container_tz}"
            )

            if container_tz != "Asia/Novosibirsk":
                raise ValueError(
                    f"Container timezone is {container_tz}, expected Asia/Novosibirsk"
                )

            logger.info("✅ Container timezone is correctly set (Asia/Novosibirsk)")
        else:
            # On host, check system timezone
            system_tz = datetime.now().astimezone().tzinfo
            logger.info(f"Host system timezone: {system_tz}")

            if "Novosibirsk" not in str(system_tz):
                raise ValueError(
                    f"System timezone is {system_tz}, expected Asia/Novosibirsk"
                )

            logger.info("✅ System timezone is correctly set (Asia/Novosibirsk)")

        return True
    except Exception as e:
        logger.error(f"Error checking system timezone: {e}")
        raise


def get_scheduler_settings():
    """
    Gets the scheduler settings from the bot module

    Returns:
        tuple: (notification_day, notification_hour, notification_minute)

    Raises:
        AttributeError: If scheduler settings are not found in the bot module
    """
    try:
        bot_module = load_bot_module()

        # Check each setting attribute exists
        required_settings = [
            "NOTIFICATION_DAY",
            "NOTIFICATION_HOUR",
            "NOTIFICATION_MINUTE",
        ]
        for setting in required_settings:
            if not hasattr(bot_module, setting):
                raise AttributeError(f"Missing required scheduler setting: {setting}")

        # Get the settings
        day = bot_module.NOTIFICATION_DAY
        hour = bot_module.NOTIFICATION_HOUR
        minute = bot_module.NOTIFICATION_MINUTE

        logger.info(f"Scheduler settings: day={day}, hour={hour}, minute={minute}")

        return (day, hour, minute)
    except Exception as e:
        logger.error(f"Error getting scheduler settings: {e}")
        raise
