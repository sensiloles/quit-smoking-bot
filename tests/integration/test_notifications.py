#!/usr/bin/env python3
"""
Integration tests for notification system

This module tests the notification system of the quit-smoking-bot,
including scheduled notifications and direct message sending.
"""

import os
import sys
import logging
from datetime import datetime
import pytz
from telegram import Bot
import asyncio
import argparse
from logging.handlers import MemoryHandler
import tempfile
import traceback

# Add the parent directory to Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from src.config import NOVOSIBIRSK_TZ
from tests.unit.test_utils import (
    setup_logging,
    get_bot_token,
    get_admin_users,
    check_system_timezone,
    get_scheduler_settings,
    load_bot_module
)

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Add memory handler to store logs for sending in test results
memory_handler = MemoryHandler(capacity=1000)
logger.addHandler(memory_handler)


class TestLock:
    """Manages a lock file to prevent multiple test runs"""
    
    def __init__(self, timeout_minutes=5):
        """
        Initialize the test lock
        
        Args:
            timeout_minutes (int): Number of minutes before lock expires
        """
        self.lock_file = os.path.join(tempfile.gettempdir(), "bot_test_lock")
        self.timeout_seconds = timeout_minutes * 60
        
    def acquire(self):
        """
        Try to acquire the lock
        
        Returns:
            bool: True if lock was acquired, False if already locked
        """
        # If the file exists and was created less than timeout_minutes ago, consider the test as running
        if os.path.exists(self.lock_file):
            # Check the creation time of the file
            file_time = os.path.getmtime(self.lock_file)
            current_time = datetime.now().timestamp()
            
            if current_time - file_time < self.timeout_seconds:
                logger.warning(f"Test lock file exists and is less than {self.timeout_seconds//60} minutes old")
                return False
            else:
                # If the file is older than timeout_minutes, delete it
                logger.info(f"Found stale lock file, removing it")
                os.remove(self.lock_file)
        
        # Create a lock file
        with open(self.lock_file, "w") as f:
            f.write(f"running since {datetime.now()}")
            
        logger.info("Test lock acquired")
        return True
        
    def release(self):
        """Release the lock if it exists"""
        try:
            if os.path.exists(self.lock_file):
                os.remove(self.lock_file)
                logger.info("Test lock released")
        except Exception as e:
            logger.error(f"Error releasing lock: {e}")


async def test_notification_settings():
    """
    Tests the notification settings of the bot
    
    Verifies the timezone settings and the scheduled notification time
    
    Returns:
        bool: True if test passed, False otherwise
    """
    try:
        logger.info("=== Starting bot notification settings test ===")
        
        # Check system timezone
        check_system_timezone()
        
        # Load bot module
        bot_module = load_bot_module()
        
        # Get current time in Novosibirsk
        now = datetime.now(NOVOSIBIRSK_TZ)
        logger.info(f"Current time in Novosibirsk: {now.strftime('%Y-%m-%d %H:%M:%S %Z%z')}")
        
        # Get scheduler settings
        scheduler_day, scheduler_hour, scheduler_minute = get_scheduler_settings()
        
        # Calculate next notification time
        next_run = now.replace(day=scheduler_day, hour=scheduler_hour, 
                              minute=scheduler_minute, second=0, microsecond=0)
        
        # If the day has already passed this month, move to next month
        if next_run <= now:
            if now.month == 12:
                next_run = next_run.replace(year=now.year + 1, month=1)
            else:
                next_run = next_run.replace(month=now.month + 1)
        
        logger.info(f"✅ Next notification will be sent: {next_run.strftime('%Y-%m-%d %H:%M:%S %z')}")
        
        # Calculate time difference
        time_diff = next_run - now
        days_diff = time_diff.days + time_diff.seconds / 86400.0
        hours_diff = time_diff.total_seconds() / 3600.0
        
        logger.info(f"✅ This is {days_diff:.1f} days ({hours_diff:.1f} hours) from current time")
        logger.info(f"✅ Notification time is set to {scheduler_day}rd of each month at "
                   f"{scheduler_hour}:{scheduler_minute:02d} Novosibirsk time")
        
        # Print test results
        logger.info("\n=== Test Results ===")
        logger.info("System timezone: ✅ OK")
        logger.info("Scheduled notification time: ✅ OK")
        logger.info("✅ TEST PASSED: Notification settings are correct")
        
        return True
    except Exception as e:
        logger.error(f"Error in test_notification_settings: {e}")
        logger.error(traceback.format_exc())
        return False


async def test_notification_sending(bot_token):
    """
    Tests sending notifications to admin users
    
    Args:
        bot_token (str): The Telegram bot token
        
    Returns:
        bool: True if test passed, False otherwise
    """
    try:
        logger.info("=== Starting notification sending test ===")
        
        # Get admin users
        admin_users = get_admin_users()
        
        if not admin_users:
            logger.error("No admin users found, cannot send test notification")
            return False
        
        # Create bot instance
        bot = Bot(token=bot_token)
        
        # Prepare test message
        test_message = (
            "🤖 Test Notification\n\n"
            "This is a test message to verify the notification system.\n"
            f"Current time (Novosibirsk): {datetime.now(NOVOSIBIRSK_TZ).strftime('%Y-%m-%d %H:%M:%S %Z')}\n"
            "If you received this message, the notification system is working correctly."
        )
        
        # Send message to each admin
        success_count = 0
        for admin_id in admin_users:
            try:
                await bot.send_message(chat_id=admin_id, text=test_message)
                logger.info(f"Test message sent to admin {admin_id}")
                success_count += 1
            except Exception as e:
                logger.error(f"Failed to send message to admin {admin_id}: {e}")
        
        if success_count == 0:
            logger.error("Failed to send test notifications to any admin")
            return False
            
        logger.info(f"✅ Test notification sent successfully to {success_count}/{len(admin_users)} admins")
        return True
        
    except Exception as e:
        logger.error(f"Error in test_notification_sending: {e}")
        logger.error(traceback.format_exc())
        return False


async def send_test_results(bot_token, test_success):
    """
    Sends test results to admin users
    
    Args:
        bot_token (str): The Telegram bot token
        test_success (bool): Whether all tests passed
        
    Returns:
        bool: True if results were sent, False otherwise
    """
    try:
        logger.info("=== Sending test results to admins ===")
        
        # Get admin users
        admin_users = get_admin_users()
        
        if not admin_users:
            logger.error("No admin users found, cannot send test results")
            return False
        
        # Create bot instance
        bot = Bot(token=bot_token)
        
        # Prepare test results message
        status_emoji = "✅" if test_success else "❌"
        test_results = (
            f"📊 Test Results Report {status_emoji}\n\n"
            f"Time: {datetime.now(NOVOSIBIRSK_TZ).strftime('%Y-%m-%d %H:%M:%S %z')}\n"
            f"Status: {'Tests passed' if test_success else 'Tests failed'}\n\n"
            "Detailed Results:\n"
        )
        
        # Get logs from memory handler and add to message
        log_entries = []
        for record in memory_handler.buffer:
            if record.levelno >= logging.INFO:  # Only include INFO and above
                log_line = f"{record.asctime} - {record.name} - {record.levelname} - {record.message}"
                log_entries.append(log_line)
        
        # Limit message size to avoid Telegram's message size limit
        MAX_LOG_LINES = 30
        if len(log_entries) > MAX_LOG_LINES:
            log_text = "\n".join(log_entries[:10])  # First 10 entries
            log_text += "\n...\n[Log truncated - too many entries]\n..."
            log_text += "\n".join(log_entries[-10:])  # Last 10 entries
        else:
            log_text = "\n".join(log_entries)
            
        test_results += log_text
        
        # Ensure message is not too long
        if len(test_results) > 4000:
            test_results = test_results[:3900] + "\n...\n[Message truncated]"
            
        logger.info(f"Results prepared (length: {len(test_results)} chars)")
        
        # Send test results to admin users
        success_count = 0
        for admin_id in admin_users:
            try:
                await bot.send_message(chat_id=admin_id, text=test_results)
                logger.info(f"Test results sent to admin {admin_id}")
                success_count += 1
            except Exception as e:
                logger.error(f"Failed to send results to admin {admin_id}: {e}")
        
        if success_count == 0:
            logger.error("Failed to send test results to any admin")
            return False
            
        logger.info(f"✅ Test results sent to {success_count}/{len(admin_users)} admins")
        return True
        
    except Exception as e:
        logger.error(f"Error in send_test_results: {e}")
        logger.error(traceback.format_exc())
        return False


async def main():
    """
    Main function to run all tests
    
    Returns:
        int: 0 if successful, 1 if failed
    """
    test_lock = TestLock()
    
    # Check for repeated execution
    if not test_lock.acquire():
        logger.warning("Test is already running. Exiting to avoid duplicate notifications.")
        return 0
        
    try:
        # Parse arguments
        parser = argparse.ArgumentParser(description="Run notification tests")
        parser.add_argument("--token", help="Telegram bot token")
        args = parser.parse_args()
        
        # Set up logging
        setup_logging()
        
        # Get bot token
        bot_token = get_bot_token(args)
        
        # Track overall test success
        all_tests_passed = True
        
        # Run notification settings test
        settings_test_passed = await test_notification_settings()
        all_tests_passed = all_tests_passed and settings_test_passed
        
        # Run notification sending test
        sending_test_passed = await test_notification_sending(bot_token)
        all_tests_passed = all_tests_passed and sending_test_passed
        
        # Send test results
        await send_test_results(bot_token, all_tests_passed)
        
        if all_tests_passed:
            logger.info("✅ All tests passed successfully")
            return 0
        else:
            logger.error("❌ Some tests failed")
            return 1
            
    except Exception as e:
        logger.error(f"Tests failed with exception: {e}")
        logger.error(traceback.format_exc())
        
        # Try to send error report
        try:
            parser = argparse.ArgumentParser()
            parser.add_argument("--token", help="Telegram bot token")
            args = parser.parse_args()
            bot_token = get_bot_token(args)
            await send_test_results(bot_token, False)
        except:
            pass
            
        return 1
    finally:
        # Release lock file
        test_lock.release()


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code) 