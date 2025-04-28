import logging
import logging.config
import datetime
import asyncio
import argparse
import os
import signal
from telegram import (
    Update,
    BotCommand,
    BotCommandScopeChat,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
)
from telegram.ext import Application, CommandHandler, ContextTypes, CallbackQueryHandler
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from src.config import (
    NOVOSIBIRSK_TZ,
    NOTIFICATION_DAY,
    NOTIFICATION_HOUR,
    NOTIFICATION_MINUTE,
    LOGGING_CONFIG,
    BOT_NAME,
    WELCOME_MESSAGE,
    USER_COMMANDS,
    ADMIN_COMMANDS,
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
            await update.message.reply_text(WELCOME_MESSAGE.format(bot_name=BOT_NAME))

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
        """Send notifications to all users with the provided status info."""
        logger.info("Starting to send notifications to users")

        users = self.user_manager.get_all_users()
        if not users:
            logger.warning("No users to send notifications to")
            return

        for user_id in users:
            try:
                await bot.send_message(chat_id=user_id, text=status_info)
                logger.info(f"Status sent to user {user_id}")
            except Exception as e:
                logger.error(f"Failed to send notification to user {user_id}: {e}")

        logger.info("Notification sending completed")

    async def send_monthly_notification(self, context=None) -> None:
        """Send monthly notifications to all users."""
        logger.info("Starting monthly notification process")

        # Use global random quote for notifications
        status_info = self.status_manager.get_status_info("monthly_notification")

        # Determine which bot instance to use
        bot_instance = context.bot if context else self.application.bot

        # Send notifications to all users
        await self._send_notifications_to_users(bot_instance, status_info)

    # This method is called by the scheduler without context
    async def scheduled_notification_job(self):
        """Job for scheduler to send monthly notifications."""
        logger.info("Scheduled notification job triggered")

        # Use global random quote for notifications
        status_info = self.status_manager.get_status_info("monthly_notification")

        # Send notifications to all users
        await self._send_notifications_to_users(self.application.bot, status_info)

    async def manual_notification(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE = None
    ) -> None:
        """Manually send notifications to all users (admin command)."""
        user_id = update.effective_user.id

        if self.user_manager.is_admin(user_id):
            try:
                await self.send_monthly_notification(context)
                await update.message.reply_text("Notifications sent to all users.")
                logger.info(f"Manual notification triggered by admin {user_id}")
            except Exception as e:
                await update.message.reply_text(
                    f"Error sending notifications: {str(e)}"
                )
                logger.error(f"Error in manual notification: {e}")
        else:
            await update.message.reply_text(
                "You don't have permission to use this command."
            )
            logger.warning(
                f"Unauthorized manual notification attempt by user {user_id}"
            )

    async def list_users(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
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
            await update.message.reply_text(
                "You don't have permission to use this command."
            )

    async def list_admins(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
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
            await update.message.reply_text(
                "You don't have permission to use this command."
            )

    async def add_admin(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Add a new admin (admin command)."""
        user_id = update.effective_user.id
        admin_name = update.effective_user.first_name

        if not self.user_manager.is_admin(user_id):
            await update.message.reply_text(
                "You don't have permission to use this command."
            )
            logger.warning(f"Unauthorized add_admin attempt by user {user_id}")
            return

        # Check if we have a user ID as an argument
        if not context.args or len(context.args) != 1:
            await update.message.reply_text(
                "Please provide a user ID to add as admin.\nUsage: /add_admin USER_ID"
            )
            return

        try:
            new_admin_id = int(context.args[0])

            # Check if user exists in our database
            if new_admin_id not in self.user_manager.get_all_users():
                await update.message.reply_text(
                    f"User ID {new_admin_id} is not registered with the bot. "
                    f"The user must use /start command first."
                )
                return

            # Check if already an admin
            if self.user_manager.is_admin(new_admin_id):
                await update.message.reply_text(
                    f"User ID {new_admin_id} is already an admin."
                )
                return

            # Add the new admin
            if self.user_manager.add_admin(new_admin_id):
                await update.message.reply_text(
                    f"User ID {new_admin_id} has been added as an admin."
                )
                logger.info(f"New admin {new_admin_id} added by admin {user_id}")

                # Create inline keyboard for declining admin rights
                keyboard = InlineKeyboardMarkup(
                    [
                        [
                            InlineKeyboardButton(
                                "Decline Admin Rights", callback_data="decline_admin"
                            )
                        ]
                    ]
                )

                # Create admin privileges message with detailed information
                admin_capabilities = "\n".join(
                    [
                        f"• {cmd} - Admin command"
                        for cmd in ADMIN_COMMANDS
                        if cmd not in USER_COMMANDS
                    ]
                )

                # Prepare notification message
                admin_message = (
                    f"🔔 You have been given administrator privileges by {admin_name} (ID: {user_id}).\n\n"
                    f"As an admin, you can now use these additional commands:\n"
                    f"{admin_capabilities}\n\n"
                    f"If you don't want to be an admin, you can decline these privileges using the button below "
                    f"or by using the /decline_admin command."
                )

                # Notify the new admin
                try:
                    await context.bot.send_message(
                        chat_id=new_admin_id, text=admin_message, reply_markup=keyboard
                    )

                    # Update commands in Telegram UI for the new admin
                    await self.update_commands_for_user(new_admin_id)
                except Exception as e:
                    logger.error(f"Failed to notify new admin {new_admin_id}: {e}")
            else:
                await update.message.reply_text(
                    f"Failed to add user ID {new_admin_id} as admin."
                )
        except ValueError:
            await update.message.reply_text(
                "Invalid user ID. Please provide a numeric user ID."
            )

    async def remove_admin(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Remove an admin (admin command)."""
        user_id = update.effective_user.id
        admin_name = update.effective_user.first_name

        if not self.user_manager.is_admin(user_id):
            await update.message.reply_text(
                "You don't have permission to use this command."
            )
            logger.warning(f"Unauthorized remove_admin attempt by user {user_id}")
            return

        # Check if we have a user ID as an argument
        if not context.args or len(context.args) != 1:
            await update.message.reply_text(
                "Please provide a user ID to remove from admins.\nUsage: /remove_admin USER_ID"
            )
            return

        try:
            admin_id_to_remove = int(context.args[0])

            # Check if trying to remove themselves
            if admin_id_to_remove == user_id:
                await update.message.reply_text(
                    "You cannot remove yourself from admins. Use /decline_admin instead."
                )
                return

            # Check if the user is an admin
            if not self.user_manager.is_admin(admin_id_to_remove):
                await update.message.reply_text(
                    f"User ID {admin_id_to_remove} is not an admin."
                )
                return

            # Remove the admin
            if self.user_manager.remove_admin(admin_id_to_remove):
                await update.message.reply_text(
                    f"User ID {admin_id_to_remove} has been removed from admins."
                )
                logger.info(f"Admin {admin_id_to_remove} removed by admin {user_id}")

                # Notify the removed admin
                try:
                    await context.bot.send_message(
                        chat_id=admin_id_to_remove,
                        text=f"Your administrator privileges have been revoked by {admin_name} (ID: {user_id}).",
                    )

                    # Update commands in Telegram UI for the removed admin
                    await self.update_commands_for_user(
                        admin_id_to_remove, is_admin=False
                    )
                except Exception as e:
                    logger.error(
                        f"Failed to notify removed admin {admin_id_to_remove}: {e}"
                    )
            else:
                await update.message.reply_text(
                    f"Failed to remove user ID {admin_id_to_remove} from admins. "
                    f"Cannot remove the last admin."
                )
        except ValueError:
            await update.message.reply_text(
                "Invalid user ID. Please provide a numeric user ID."
            )

    async def decline_admin(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Allow an admin to decline their admin privileges."""
        user_id = update.effective_user.id

        if not self.user_manager.is_admin(user_id):
            await update.message.reply_text("You are not an admin.")
            return

        # Get all admins and check if this is the last admin
        admins = self.user_manager.get_all_admins()
        if len(admins) <= 1:
            await update.message.reply_text(
                "You are the last administrator and cannot decline your privileges. "
                "Make someone else an admin first."
            )
            return

        # Remove admin privileges
        if self.user_manager.remove_admin(user_id):
            await update.message.reply_text(
                "You have successfully declined your administrator privileges."
            )
            logger.info(f"Admin {user_id} declined their admin privileges")

            # Update commands in Telegram UI
            await self.update_commands_for_user(user_id, is_admin=False)
        else:
            await update.message.reply_text(
                "Failed to decline administrator privileges."
            )

    async def handle_callback_query(
        self, update: Update, context: ContextTypes.DEFAULT_TYPE
    ) -> None:
        """Handle callback queries from inline keyboards."""
        query = update.callback_query
        user_id = query.from_user.id

        await query.answer()

        if query.data == "decline_admin":
            # Get all admins and check if this is the last admin
            admins = self.user_manager.get_all_admins()
            if len(admins) <= 1 and user_id in admins:
                await query.message.reply_text(
                    "You are the last administrator and cannot decline your privileges. "
                    "Make someone else an admin first."
                )
                return

            # Check if the user is an admin
            if not self.user_manager.is_admin(user_id):
                await query.message.reply_text("You are not an admin.")
                return

            # Remove admin privileges
            if self.user_manager.remove_admin(user_id):
                await query.message.reply_text(
                    "You have successfully declined your administrator privileges."
                )
                logger.info(
                    f"Admin {user_id} declined their admin privileges via inline button"
                )

                # Update commands in Telegram UI
                await self.update_commands_for_user(user_id, is_admin=False)
            else:
                await query.message.reply_text(
                    "Failed to decline administrator privileges."
                )

    async def update_commands_for_user(self, user_id: int, is_admin: bool = True):
        """Update the available commands for a specific user."""
        try:
            if is_admin:
                # Set admin commands for the user
                admin_commands = [
                    BotCommand(
                        command.lstrip("/"), f"Admin command: {command.lstrip('/')}"
                    )
                    for command in ADMIN_COMMANDS
                ]

                await self.application.bot.set_my_commands(
                    admin_commands, scope=BotCommandScopeChat(chat_id=user_id)
                )
                logger.info(f"Updated commands for admin {user_id}")
            else:
                # Set normal user commands
                user_commands = [
                    BotCommand(
                        command.lstrip("/"), f"User command: {command.lstrip('/')}"
                    )
                    for command in USER_COMMANDS
                ]

                await self.application.bot.set_my_commands(
                    user_commands, scope=BotCommandScopeChat(chat_id=user_id)
                )
                logger.info(f"Updated commands for user {user_id}")
        except Exception as e:
            logger.error(f"Failed to update commands for user {user_id}: {e}")

    async def my_id(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        """Send the user their ID when the command /my_id is issued."""
        user_id = update.effective_user.id
        user_name = update.effective_user.first_name

        await update.message.reply_text(
            f"Your user ID: {user_id}\n"
            f"Name: {user_name}\n\n"
            "You can share this ID with an admin if you need admin privileges."
        )
        logger.info(f"User {user_id} requested their ID")

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
            logger.error(
                "No token provided. Please provide a token via --token argument or BOT_TOKEN environment variable."
            )
            return False

        # Log token information (but not the actual token for security)
        token_source = "command line argument" if args.token else "environment variable"
        logger.info(f"Using token from {token_source}")

        try:
            # Create the Application
            self.application = Application.builder().token(bot_token).build()

            # Store bot instance for scheduler use
            self.bot = self.application.bot

            # Mapping of commands to their handlers
            command_handlers = {
                "/start": self.start,
                "/status": self.status,
                "/my_id": self.my_id,
                "/notify_all": self.manual_notification,
                "/list_users": self.list_users,
                "/list_admins": self.list_admins,
                "/add_admin": self.add_admin,
                "/remove_admin": self.remove_admin,
                "/decline_admin": self.decline_admin,
            }

            # Register command handlers based on configuration
            for command, handler in command_handlers.items():
                if command in USER_COMMANDS or command in ADMIN_COMMANDS:
                    self.application.add_handler(
                        CommandHandler(command.lstrip("/"), handler)
                    )
                    logger.info(f"Registered handler for command {command}")

            # Add callback query handler for inline buttons
            self.application.add_handler(
                CallbackQueryHandler(self.handle_callback_query)
            )

            # Setup scheduler for monthly notifications
            self.scheduler = AsyncIOScheduler(timezone=NOVOSIBIRSK_TZ)

            # Add monthly notification job
            self.scheduler.add_job(
                self.scheduled_notification_job,
                "cron",
                day=NOTIFICATION_DAY,
                hour=NOTIFICATION_HOUR,
                minute=NOTIFICATION_MINUTE,
            )

            return True
        except Exception as e:
            logger.error(f"Error during setup: {e}")
            return False

    async def set_bot_commands(self):
        """Set bot commands in Telegram to make them visible in the UI"""
        try:
            # Define user commands with descriptions
            user_commands = [
                BotCommand(command.lstrip("/"), f"User command: {command.lstrip('/')}")
                for command in USER_COMMANDS
            ]

            # Set commands visible to all users
            await self.application.bot.set_my_commands(user_commands)
            logger.info("Set user commands in Telegram")

            # Get all admins
            admins = self.user_manager.get_all_admins()

            # Define admin commands with descriptions
            admin_commands = [
                BotCommand(command.lstrip("/"), f"Admin command: {command.lstrip('/')}")
                for command in ADMIN_COMMANDS
            ]

            # Set admin-specific commands for each admin
            for admin_id in admins:
                try:
                    await self.application.bot.set_my_commands(
                        admin_commands, scope=BotCommandScopeChat(chat_id=admin_id)
                    )
                    logger.info(f"Set admin commands for admin {admin_id}")
                except Exception as e:
                    logger.error(f"Failed to set admin commands for {admin_id}: {e}")

            logger.info("Bot commands updated in Telegram")
        except Exception as e:
            logger.error(f"Error setting bot commands: {e}")

    async def run(self):
        """Run the bot"""
        if not await self.setup():
            return

        self._running = True

        try:
            # Start the scheduler
            self.scheduler.start()

            # Log clear session start marker
            logger.info("=" * 50)
            logger.info("NEW BOT SESSION STARTED")
            logger.info("=" * 50)

            logger.info(f"Bot started at {datetime.datetime.now(NOVOSIBIRSK_TZ)}")

            # Calculate and log next notification time
            next_run = self.scheduler.get_jobs()[0].next_run_time
            logger.info(f"Next scheduled notification will be sent at: {next_run}")
            logger.info(
                f"Scheduled monthly notification for day={NOTIFICATION_DAY}, {NOTIFICATION_HOUR:02d}:{NOTIFICATION_MINUTE:02d} Novosibirsk time"
            )

            # Start the bot with polling
            await self.application.initialize()
            await self.application.start()

            # Update commands in Telegram UI
            await self.set_bot_commands()

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
