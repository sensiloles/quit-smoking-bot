import logging
import logging.config
import datetime
import asyncio
import argparse
import os
import sys
import signal
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from src.config import (
    NOVOSIBIRSK_TZ, NOTIFICATION_DAY,
    NOTIFICATION_HOUR, NOTIFICATION_MINUTE, LOGGING_CONFIG,
    START_DATE, BOT_NAME, WELCOME_MESSAGE
)
from src.quotes import QuotesManager
from src.users import UserManager
from src.status import StatusManager

# Configure logging only if not already configured
if not logging.getLogger().handlers:
    logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger(__name__)

class QuitSmokingBot:
    def __init__(self):
        self.user_manager = UserManager()
        self.quotes_manager = QuotesManager()
        self.status_manager = StatusManager(self.quotes_manager)
        self.scheduler = None
        self.application = None
        self._running = False
        self._shutdown_event = asyncio.Event()
        
    async def start(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        """Send a message when the command /start is issued."""
        user_id = update.effective_user.id
        user_name = update.effective_user.first_name
        
        # If this is the first user ever and no admins exist, make them admin
        if not self.user_manager.get_all_admins():
            self.user_manager.add_admin(user_id)
            logger.info(f"First user {user_id} set as admin")
            await update.message.reply_text(
                WELCOME_MESSAGE.format(bot_name=BOT_NAME) + "\n\n"
                "You have been set as the first administrator of the bot."
            )
        else:
            await update.message.reply_text(
                WELCOME_MESSAGE.format(bot_name=BOT_NAME)
            )
        
        # Add user to the list if not already there
        self.user_manager.add_user(user_id)
    
    async def status(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        """Send current non-smoking status when the command /status is issued."""
        user_id = update.effective_user.id
        
        # Get status info with a quote
        status_info = self.status_manager.get_status_info("status")
        
        # Send status message
        await update.message.reply_text(status_info)
        logger.info(f"Status sent to user {user_id}")
        
    async def _send_notifications_to_users(self, bot, status_info):
        """Helper method to send notifications to all users with provided bot instance."""
        # Log users count
        users = self.user_manager.get_all_users()
        logger.info(f"Preparing to send notifications to {len(users)} users")
        
        # Send to all registered users
        for user_id in users:
            try:
                await bot.send_message(chat_id=user_id, text=status_info)
                logger.info(f"Notification sent to user {user_id}")
            except Exception as e:
                logger.error(f"Failed to send notification to user {user_id}: {e}")
        
        logger.info("Notification sending completed")

    async def send_monthly_notification(self, context: ContextTypes.DEFAULT_TYPE) -> None:
        """Send monthly notifications to all users."""
        logger.info("Starting monthly notification process")
        
        # Use global random quote for notifications
        status_info = self.status_manager.get_status_info("monthly_notification")
        
        # Send notifications to all users
        await self._send_notifications_to_users(context.bot, status_info)
    
    # This method is called by the scheduler without context
    async def scheduled_notification_job(self):
        """Job for scheduler to send monthly notifications."""
        logger.info("Scheduled notification job triggered")
        
        # Use global random quote for notifications
        status_info = self.status_manager.get_status_info("monthly_notification")
        
        # Send notifications to all users
        await self._send_notifications_to_users(self.application.bot, status_info)
    
    async def manual_notification(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        """Manually send notifications to all users (admin command)."""
        user_id = update.effective_user.id
        
        if self.user_manager.is_admin(user_id):
            try:
                await self.send_monthly_notification(context)
                await update.message.reply_text("Notifications sent to all users.")
                logger.info(f"Manual notification triggered by admin {user_id}")
            except Exception as e:
                await update.message.reply_text(f"Error sending notifications: {str(e)}")
                logger.error(f"Error in manual notification: {e}")
        else:
            await update.message.reply_text("You don't have permission to use this command.")
            logger.warning(f"Unauthorized manual notification attempt by user {user_id}")
    
    async def list_users(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        """List all registered users (admin command)."""
        user_id = update.effective_user.id
        
        if self.user_manager.is_admin(user_id):
            users = self.user_manager.get_all_users()
            if not users:
                await update.message.reply_text("No registered users yet.")
                return
                
            users_text = "List of users:\n"
            for i, uid in enumerate(users, 1):
                users_text += f"{i}. {uid}\n"
            
            await update.message.reply_text(users_text)
        else:
            await update.message.reply_text("You don't have permission to use this command.")
    
    async def list_admins(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        """List all admin users (admin command)."""
        user_id = update.effective_user.id
        
        if self.user_manager.is_admin(user_id):
            admins = self.user_manager.get_all_admins()
            if not admins:
                await update.message.reply_text("The admin list is empty.")
                return
                
            admins_text = "List of administrators:\n"
            for i, uid in enumerate(admins, 1):
                admins_text += f"{i}. {uid}\n"
            
            await update.message.reply_text(admins_text)
        else:
            await update.message.reply_text("You don't have permission to use this command.")
    
    async def shutdown(self, signal_type=None):
        """Cleanup and shutdown the bot gracefully"""
        if not self._running:
            return
            
        self._running = False
        logger.info("Shutting down bot...")
        
        try:
            if self.scheduler and self.scheduler.running:
                logger.info("Stopping scheduler...")
                self.scheduler.shutdown(wait=True)
                
            if self.application:
                logger.info("Stopping application...")
                await self.application.stop()
                await self.application.shutdown()
                
            logger.info("Shutdown complete")
            self._shutdown_event.set()
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")
            
    async def setup(self):
        """Setup the bot and scheduler"""
        # Get token from command line arguments or environment variable
        parser = argparse.ArgumentParser(description="Quit Smoking Telegram Bot")
        parser.add_argument("--token", type=str, help="Telegram bot token")
        args = parser.parse_args()

        # Get token from args or environment
        bot_token = args.token or os.environ.get("BOT_TOKEN")
        if not bot_token:
            logger.error("No token provided. Please provide a token via --token argument or BOT_TOKEN environment variable.")
            return False
            
        # Log token information (but not the actual token for security)
        token_source = "command line argument" if args.token else "environment variable"
        logger.info(f"Using token from {token_source}")
        
        try:
            # Create the Application
            self.application = Application.builder().token(bot_token).build()
            
            # Store bot instance for scheduler use
            self.bot = self.application.bot

            # Add command handlers
            self.application.add_handler(CommandHandler("start", self.start))
            self.application.add_handler(CommandHandler("status", self.status))
            self.application.add_handler(CommandHandler("notify_all", self.manual_notification))
            self.application.add_handler(CommandHandler("list_users", self.list_users))
            self.application.add_handler(CommandHandler("list_admins", self.list_admins))

            # Setup scheduler for monthly notifications
            self.scheduler = AsyncIOScheduler(timezone=NOVOSIBIRSK_TZ)
            
            # Add monthly notification job
            self.scheduler.add_job(
                self.scheduled_notification_job,
                'cron',
                day=NOTIFICATION_DAY,
                hour=NOTIFICATION_HOUR,
                minute=NOTIFICATION_MINUTE
            )
            
            return True
        except Exception as e:
            logger.error(f"Error during setup: {e}")
            return False

    async def run(self):
        """Run the bot"""
        if not await self.setup():
            return
            
        self._running = True
        
        try:
            # Start the scheduler
            self.scheduler.start()
            logger.info(f"Bot started at {datetime.datetime.now(NOVOSIBIRSK_TZ)}")
            
            # Calculate and log next notification time
            next_run = self.scheduler.get_jobs()[0].next_run_time
            logger.info(f"Next scheduled notification will be sent at: {next_run}")
            logger.info(f"Scheduled monthly notification for day={NOTIFICATION_DAY}, {NOTIFICATION_HOUR:02d}:{NOTIFICATION_MINUTE:02d} Novosibirsk time")

            # Start the bot with polling
            await self.application.initialize()
            await self.application.start()
            await self.application.updater.start_polling()
            
            # Keep the bot running until shutdown is requested
            while self._running:
                await asyncio.sleep(1)
            
        except Exception as e:
            logger.error(f"Error running bot: {e}")
        finally:
            if self._running:
                await self.shutdown()

def main():
    """Main function to run the bot"""
    bot = QuitSmokingBot()
    
    async def async_shutdown(signum):
        logger.info(f"Received signal {signum}")
        bot._running = False
        await bot.shutdown()
    
    def signal_handler(signum, frame):
        # Create a new event loop for the signal handler
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(async_shutdown(signum))
        finally:
            loop.close()
    
    # Setup signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Run the bot
    try:
        # Create a new event loop
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(bot.run())
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
        # Create a new event loop for keyboard interrupt handling
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(async_shutdown("SIGINT"))
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"Error in main: {e}")
    finally:
        # Clean up the event loop
        loop = asyncio.get_event_loop()
        if loop.is_running():
            loop.stop()
        loop.close()

if __name__ == "__main__":
    main()
