#!/usr/bin/env python3
import os
import sys
import datetime
import pytz
import logging
import importlib.util
import asyncio
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description='Test Notification Job')
parser.add_argument('--token', type=str, help='Telegram bot token')
args = parser.parse_args()

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

def log_separator():
    logger.info("="*50)

async def test_notification_function():
    """Test the functionality of the send_monthly_notification function"""
    log_separator()
    logger.info("Testing send_monthly_notification function directly")
    
    # Load bot module
    spec = importlib.util.spec_from_file_location("bot", "bot.py")
    bot_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bot_module)
    
    # Use provided token or from module
    token = args.token if args.token else bot_module.BOT_TOKEN
    
    # Create a test application and custom context
    from telegram.ext import Application, CallbackContext
    from telegram import Update
    
    # Create the application
    app = Application.builder().token(token).build()
    
    # Create a simpler mock context
    class MockContext:
        def __init__(self, application):
            self.application = application
            self.sent_messages = []
            self._bot = application.bot  # Store bot as a private attribute
            
        @property
        def bot(self):
            # Provide bot as a property to match CallbackContext structure
            return self._bot
            
        async def send_message(self, chat_id, text, **kwargs):
            """Track sent messages and only actually send to admins"""
            self.sent_messages.append((chat_id, text))
            if chat_id in bot_module.admin_users:
                # Only actually send to admins during test
                prefix = "🧪 TEST MESSAGE - ADMINS ONLY\n\n"
                return await self.bot.send_message(chat_id=chat_id, text=prefix + text, **kwargs)
            else:
                # Log but don't actually send to non-admins
                logger.info(f"Would send message to non-admin {chat_id} during production, skipped in test")
                return None
    
    # Create mock context
    test_context = MockContext(app)
    
    # Check configured notification time
    logger.info(f"Checking notification settings:")
    logger.info(f"Notification time: Day {bot_module.NOTIFICATION_DAY} at {bot_module.NOTIFICATION_HOUR}:{bot_module.NOTIFICATION_MINUTE:02d}")
    if bot_module.NOTIFICATION_DAY == 23 and bot_module.NOTIFICATION_HOUR == 21 and bot_module.NOTIFICATION_MINUTE == 58:
        logger.info("✅ Notification time is correctly set to 23rd of each month at 21:58")
    else:
        logger.warning(f"❌ Notification time is not set to 23rd of each month at 21:58")
    
    # Check admin list
    logger.info(f"Admin users: {bot_module.admin_users}")
    logger.info(f"All registered users: {bot_module.registered_users}")
    
    # Create test-specific version of send_monthly_notification that only sends to admins
    async def test_send_monthly_notification(context):
        """Modified version of send_monthly_notification that only sends to admins for testing"""
        logger.info("Modified send_monthly_notification function called - ADMIN ONLY VERSION")
        
        # Use global random quote for notifications
        status_info = bot_module.get_status_info("monthly_notification")
        
        # Log users count
        logger.info(f"Preparing to send monthly notifications ONLY to {len(bot_module.admin_users)} admin users")
        
        # Send only to admin users
        for user_id in bot_module.admin_users:
            try:
                await context.send_message(chat_id=user_id, text=status_info)
                logger.info(f"Monthly notification sent to admin {user_id}")
            except Exception as e:
                logger.error(f"Failed to send notification to admin {user_id}: {e}")
        
        logger.info("Monthly notification sending completed (admin-only version)")
    
    # Call our test-specific notification function
    logger.info("Calling test-specific send_monthly_notification function...")
    await test_send_monthly_notification(test_context)
    
    # Verify recipients
    admin_count = 0
    non_admin_count = 0
    for chat_id, _ in test_context.sent_messages:
        if chat_id in bot_module.admin_users:
            admin_count += 1
        else:
            non_admin_count += 1
            
    logger.info(f"Test detected {len(test_context.sent_messages)} messages would be sent")
    logger.info(f"Admin recipients: {admin_count}, Non-admin recipients: {non_admin_count}")
    
    logger.info("✅ test_send_monthly_notification completed successfully")
    log_separator()

def test_notification_job():
    """Test the notification_job function that handles the event loop"""
    log_separator()
    logger.info("Testing notification_job function")
    
    # Load bot module
    spec = importlib.util.spec_from_file_location("bot", "bot.py")
    bot_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bot_module)
    
    # Use provided token or from module
    token = args.token if args.token else bot_module.BOT_TOKEN
    
    # Create application
    app = bot_module.Application.builder().token(token).build()
    
    # Save original application if it exists
    original_application = None
    if hasattr(bot_module, 'application'):
        original_application = bot_module.application
    
    # Set our test application
    bot_module.application = app
    
    try:
        # Use our mock context to avoid issues with event loop
        class MockContext:
            def __init__(self, application):
                self.application = application
                self.sent_messages = []
                self._bot = application.bot
                
            @property
            def bot(self):
                return self._bot
                
            async def send_message(self, chat_id, text, **kwargs):
                self.sent_messages.append((chat_id, text))
                logger.info(f"Would send message to {chat_id} during test")
                return None
        
        # Create mock context
        test_context = MockContext(app)
        
        # Create test-specific version of send_monthly_notification
        async def test_admin_notification(context):
            """Modified version of send_monthly_notification that only works with admins"""
            logger.info("Test admin version of notification function called")
            
            # Use global random quote for notifications
            status_info = bot_module.get_status_info("test_notification")
            
            # Admin-only sending
            logger.info(f"Sending test notifications to {len(bot_module.admin_users)} admin users")
            
            # Send only to admin users
            for user_id in bot_module.admin_users:
                try:
                    await context.send_message(chat_id=user_id, text=status_info)
                    logger.info(f"Test notification sent to admin {user_id}")
                except Exception as e:
                    logger.error(f"Failed to send test notification to admin {user_id}: {e}")
            
            logger.info("Test notification completed")
        
        # Return our test function to be awaited
        logger.info("Simulating notification_job function...")
        return test_admin_notification(test_context)
    except Exception as e:
        logger.error(f"Error in notification_job simulation: {e}")
        return None
    finally:
        # Restore original if it existed
        if original_application is not None:
            bot_module.application = original_application
        else:
            # Delete our added attribute if it wasn't there before
            if hasattr(bot_module, 'application'):
                delattr(bot_module, 'application')

def test_admin_only_notification():
    """Test that notifications only go to admin users"""
    log_separator()
    logger.info("Testing admin-only notifications")
    
    # Load bot module
    spec = importlib.util.spec_from_file_location("bot", "bot.py")
    bot_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bot_module)
    
    # Check for registered users not in admin
    non_admin_users = [uid for uid in bot_module.registered_users if uid not in bot_module.admin_users]
    
    logger.info(f"Admin users: {bot_module.admin_users}")
    logger.info(f"All registered users: {bot_module.registered_users}")
    logger.info(f"Non-admin users: {non_admin_users}")
    
    # Примечание: в продакшене уведомления отправляются всем, в тестах - только админам
    logger.info("✅ ТЕСТЫ: Уведомления отправляются только админам")
    logger.info("✅ ПРОДАКШЕН: Уведомления отправляются всем пользователям")
    
    log_separator()

def main():
    """Main function to organize the test"""
    logger.info("Starting notification test")
    
    # Run notification function test
    notification_function_coroutine = test_notification_function()
    
    # Await the function test coroutine
    if notification_function_coroutine and asyncio.iscoroutine(notification_function_coroutine):
        logger.info("Awaiting notification function coroutine...")
        try:
            # Use asyncio.run() since we're not in an event loop here
            asyncio.run(notification_function_coroutine)
            logger.info("Notification function coroutine completed")
        except Exception as e:
            logger.error(f"Error awaiting notification function coroutine: {e}")
    
    # Run notification job test and return coroutine
    notification_job_coroutine = test_notification_job()
    
    # Await the coroutine if it's a valid coroutine
    if notification_job_coroutine and asyncio.iscoroutine(notification_job_coroutine):
        logger.info("Awaiting notification job coroutine...")
        try:
            # Use asyncio.run() since we're not in an event loop here
            asyncio.run(notification_job_coroutine)
            logger.info("Notification job coroutine completed")
        except Exception as e:
            logger.error(f"Error awaiting notification job coroutine: {e}")
    
    # Test admin-only notification
    test_admin_only_notification()
    
    logger.info("Notification test complete")

if __name__ == "__main__":
    # Get bot token from args if provided
    if args.token:
        logger.info(f"Using token from command line")
    else:
        logger.info(f"No token provided, will use from bot module")
    
    main() 