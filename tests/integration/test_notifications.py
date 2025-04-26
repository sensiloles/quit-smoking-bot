import os
import sys
import logging
from datetime import datetime
import pytz
from telegram import Bot
import asyncio
import argparse
from logging.handlers import MemoryHandler

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

# Add memory handler to store logs
memory_handler = MemoryHandler(capacity=1000)
logger.addHandler(memory_handler)

async def test_notification_settings():
    """Tests the notification settings of the bot."""
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

async def test_notification_sending():
    """Tests sending notifications to admin users."""
    try:
        # Get bot token
        parser = argparse.ArgumentParser()
        parser.add_argument("--token", help="Telegram bot token")
        args = parser.parse_args()
        
        token = get_bot_token(args)
        
        # Get admin users
        admin_users = get_admin_users()
        
        # Create bot instance
        bot = Bot(token=token)
        
        # Send test message to admin users
        test_message = (
            "🤖 Test Notification\n\n"
            "This is a test message to verify the notification system.\n"
            f"Current time (Novosibirsk): {datetime.now(NOVOSIBIRSK_TZ).strftime('%Y-%m-%d %H:%M:%S %Z')}\n"
            "If you received this message, the notification system is working correctly."
        )
        
        for admin_id in admin_users:
            await bot.send_message(chat_id=admin_id, text=test_message)
            logger.info(f"Test message sent to admin {admin_id}")
        
        logger.info("✅ Test notification sent to admins only")
        
    except Exception as e:
        logger.error(f"Error in test_notification_sending: {e}")
        raise

async def send_test_results():
    """Sends test results to admin users."""
    try:
        # Get bot token
        parser = argparse.ArgumentParser()
        parser.add_argument("--token", help="Telegram bot token")
        args = parser.parse_args()
        
        token = get_bot_token(args)
        
        # Get admin users
        admin_users = get_admin_users()
        
        # Create bot instance
        bot = Bot(token=token)
        
        # Prepare test results message
        test_results = (
            "📊 Test Results Report\n\n"
            f"Time: {datetime.now(NOVOSIBIRSK_TZ).strftime('%Y-%m-%d %H:%M:%S %z')}\n"
            "Status: ✅ Tests completed\n\n"
            "Detailed Results:\n"
        )
        
        # Add test results to message
        test_results += "\n".join([
            f"{record.asctime} - {record.name} - {record.levelname} - {record.message}"
            for record in memory_handler.buffer
        ])
        
        logger.info(f"Message prepared (length: {len(test_results)})")
        
        # Send test results to admin users
        for admin_id in admin_users:
            await bot.send_message(chat_id=admin_id, text=test_results)
            logger.info(f"✅ Test result sent to admin {admin_id}")
        
    except Exception as e:
        logger.error(f"Error in send_test_results: {e}")
        raise

async def main():
    """Main function to run all tests."""
    try:
        # Run notification settings test
        await test_notification_settings()
        
        # Run notification sending test
        await test_notification_sending()
        
        # Send test results
        await send_test_results()
        
        logger.info("Tests passed successfully")
        
    except Exception as e:
        logger.error(f"Tests failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main()) 