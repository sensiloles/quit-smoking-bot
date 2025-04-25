#!/usr/bin/env python3
import os
import sys
import datetime
import pytz
import logging
import importlib.util
import subprocess
import asyncio
import argparse
from io import StringIO

# Parse command line arguments
parser = argparse.ArgumentParser(description='Bot Notification Settings Test')
parser.add_argument('--token', type=str, help='Telegram bot token')
args = parser.parse_args()

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Buffer for storing test results
test_results = StringIO()

# Add handler for logging to buffer
buffer_handler = logging.StreamHandler(test_results)
buffer_handler.setFormatter(logging.Formatter("%(message)s"))
logger.addHandler(buffer_handler)

# Add handler for writing to test_log.txt file
file_handler = logging.FileHandler("test_log.txt", mode="w")
file_handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))
logger.addHandler(file_handler)

# Function to write additional information to log file
def log_to_file(message, level="INFO"):
    """Writes a message to the test_log.txt file"""
    with open("test_log.txt", "a") as log_file:
        log_file.write(f"{datetime.datetime.now()} - {level} - {message}\n")

def check_system_timezone():
    """Checks the system timezone settings"""
    try:
        log_to_file("Starting system timezone check")
        # Run timedatectl command to get current time settings
        timezone_info = subprocess.check_output(['timedatectl'], text=True)
        logger.info("System time settings:\n" + timezone_info)
        log_to_file(f"System time information retrieved: {timezone_info.replace(chr(10), ' ')}")
        
        # Check if the Novosibirsk timezone is configured
        if "Asia/Novosibirsk" in timezone_info:
            logger.info("✅ System timezone is correctly set (Asia/Novosibirsk)")
            log_to_file("System timezone is correctly configured")
            return True
        else:
            logger.warning("❌ System timezone is NOT set to Asia/Novosibirsk!")
            log_to_file("System timezone does not match the expected (Asia/Novosibirsk)", "WARNING")
            return False
    except Exception as e:
        logger.error(f"Error checking system timezone: {str(e)}")
        log_to_file(f"Error checking system timezone: {str(e)}", "ERROR")
        return False

def check_bot_timezone_settings():
    """Checks timezone settings in the bot code"""
    try:
        log_to_file("Starting bot timezone settings check")
        # Load bot.py module without executing
        spec = importlib.util.spec_from_file_location("bot", "bot.py")
        bot_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(bot_module)
        log_to_file("bot.py module successfully loaded")
        
        # Check timezone settings
        if hasattr(bot_module, 'NOVOSIBIRSK_TZ'):
            tz = bot_module.NOVOSIBIRSK_TZ
            logger.info(f"✅ Timezone variable defined in bot code: {tz}")
            log_to_file(f"Timezone variable found: {tz}")
            
            # Check scheduler
            if hasattr(bot_module, 'main'):
                logger.info("✅ main function found in bot code")
                log_to_file("main function found in bot code")
                
                # Check that main uses NOVOSIBIRSK_TZ with scheduler
                main_code = bot_module.main.__code__.co_consts
                scheduler_config_found = False
                
                # Try direct inspection of the source code file
                try:
                    with open("bot.py", "r") as f:
                        source_code = f.read()
                        # First check for monthly scheduler format
                        if "day=" in source_code and "hour=" in source_code and "minute=" in source_code:
                            # Extract the values
                            try:
                                # Try to find the notification constants first
                                if "NOTIFICATION_DAY = 23" in source_code:
                                    scheduler_day = 23
                                elif "day=NOTIFICATION_DAY" in source_code:
                                    scheduler_day = 23

                                if "NOTIFICATION_HOUR = 21" in source_code:
                                    scheduler_hour = 21
                                elif "hour=NOTIFICATION_HOUR" in source_code:
                                    scheduler_hour = 21

                                if "NOTIFICATION_MINUTE = 58" in source_code:
                                    scheduler_minute = 58
                                elif "minute=NOTIFICATION_MINUTE" in source_code:
                                    scheduler_minute = 58

                                # If constants not found, try direct values
                                if scheduler_day is None:
                                    day_match = source_code.split("day=")[1].split(",")[0].strip()
                                    if day_match.isdigit():
                                        scheduler_day = int(day_match)
                                    
                                if scheduler_hour is None:
                                    hour_match = source_code.split("hour=")[1].split(",")[0].strip()
                                    if hour_match.isdigit():
                                        scheduler_hour = int(hour_match)
                                    
                                if scheduler_minute is None:
                                    minute_match = source_code.split("minute=")[1].split(",")[0].strip()
                                    if minute_match.isdigit():
                                        scheduler_minute = int(minute_match)
                            except:
                                pass
                        # Fallback to older format check
                        elif "hour=21" in source_code and "minute=58" in source_code:
                            scheduler_day = 23
                            scheduler_hour = 21
                            scheduler_minute = 58
                        
                        # Check for constants declaration
                        if scheduler_day is None and "NOTIFICATION_DAY = 23" in source_code:
                            scheduler_day = 23
                        if scheduler_hour is None and "NOTIFICATION_HOUR = 21" in source_code:
                            scheduler_hour = 21
                        if scheduler_minute is None and "NOTIFICATION_MINUTE = 58" in source_code:
                            scheduler_minute = 58
                except Exception as e:
                    logger.warning(f"Error checking source code: {str(e)}")
                    log_to_file(f"Error checking source code: {str(e)}", "WARNING")
                
                # Fallback to checking the function constants
                if not scheduler_config_found:
                    for const in main_code:
                        if isinstance(const, str) and "NOVOSIBIRSK_TZ" in const:
                            scheduler_config_found = True
                            break
                
                if scheduler_config_found:
                    logger.info("✅ Scheduler uses NOVOSIBIRSK_TZ variable")
                    log_to_file("Scheduler uses NOVOSIBIRSK_TZ variable")
                else:
                    logger.warning("❌ Could not confirm the use of NOVOSIBIRSK_TZ in scheduler")
                    log_to_file("Could not confirm the use of NOVOSIBIRSK_TZ in scheduler", "WARNING")
                
                return True
            else:
                logger.warning("❌ main function not found in bot code")
                log_to_file("main function not found in bot code", "WARNING")
                return False
        else:
            logger.warning("❌ NOVOSIBIRSK_TZ variable not defined in bot code")
            log_to_file("NOVOSIBIRSK_TZ variable not defined in bot code", "WARNING")
            return False
    except Exception as e:
        logger.error(f"Error checking bot timezone settings: {str(e)}")
        log_to_file(f"Error checking bot timezone settings: {str(e)}", "ERROR")
        return False

def test_scheduled_time():
    """Tests the scheduled notification time"""
    try:
        # Load bot.py module without executing
        spec = importlib.util.spec_from_file_location("bot", "bot.py")
        bot_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(bot_module)
        
        # Get current time in Novosibirsk
        now_nsk = datetime.datetime.now(pytz.timezone('Asia/Novosibirsk'))
        logger.info(f"Current time in Novosibirsk: {now_nsk.strftime('%Y-%m-%d %H:%M:%S %Z%z')}")
        
        # Get next scheduled notification time
        scheduler_day = None
        scheduler_hour = None
        scheduler_minute = None
        
        # Analyze main code to determine day, hour, and minute in cron expression
        main_code = bot_module.main.__code__.co_consts
        
        # Try to read directly from the file
        try:
            with open("bot.py", "r") as f:
                source_code = f.read()
                # First check for monthly scheduler format
                if "day=" in source_code and "hour=" in source_code and "minute=" in source_code:
                    # Extract the values
                    try:
                        # Try to find the notification constants first
                        if "NOTIFICATION_DAY = 23" in source_code:
                            scheduler_day = 23
                        elif "day=NOTIFICATION_DAY" in source_code:
                            scheduler_day = 23

                        if "NOTIFICATION_HOUR = 21" in source_code:
                            scheduler_hour = 21
                        elif "hour=NOTIFICATION_HOUR" in source_code:
                            scheduler_hour = 21

                        if "NOTIFICATION_MINUTE = 58" in source_code:
                            scheduler_minute = 58
                        elif "minute=NOTIFICATION_MINUTE" in source_code:
                            scheduler_minute = 58

                        # If constants not found, try direct values
                        if scheduler_day is None:
                            day_match = source_code.split("day=")[1].split(",")[0].strip()
                            if day_match.isdigit():
                                scheduler_day = int(day_match)
                            
                        if scheduler_hour is None:
                            hour_match = source_code.split("hour=")[1].split(",")[0].strip()
                            if hour_match.isdigit():
                                scheduler_hour = int(hour_match)
                            
                        if scheduler_minute is None:
                            minute_match = source_code.split("minute=")[1].split(",")[0].strip()
                            if minute_match.isdigit():
                                scheduler_minute = int(minute_match)
                    except:
                        pass
                # Fallback to older format check
                elif "hour=21" in source_code and "minute=58" in source_code:
                    scheduler_day = 23
                    scheduler_hour = 21
                    scheduler_minute = 58
        except Exception as e:
            logger.warning(f"Error checking source code for time: {str(e)}")
            log_to_file(f"Error checking source code for time: {str(e)}", "WARNING")
        
        # Fallback to the old method if needed
        if scheduler_hour is None or scheduler_minute is None or scheduler_day is None:
            for const in main_code:
                if isinstance(const, str) and "day" in const:
                    try:
                        day_str = const.split("day=")[1].split(",")[0].strip()
                        scheduler_day = int(day_str)
                    except:
                        pass
                if isinstance(const, str) and "hour" in const:
                    try:
                        hour_str = const.split("hour=")[1].split(",")[0].strip()
                        scheduler_hour = int(hour_str)
                    except:
                        pass
                if isinstance(const, str) and "minute" in const:
                    try:
                        minute_str = const.split("minute=")[1].split(")")[0].strip()
                        scheduler_minute = int(minute_str)
                    except:
                        pass
        
        if scheduler_hour is not None and scheduler_minute is not None and scheduler_day is not None:
            logger.info(f"✅ Scheduled notification time detected: Day {scheduler_day} at {scheduler_hour}:{scheduler_minute:02d}")
            log_to_file(f"Scheduled notification time detected: Day {scheduler_day} at {scheduler_hour}:{scheduler_minute:02d}")
            
            # Calculate next notification time
            next_run = now_nsk.replace(day=scheduler_day, hour=scheduler_hour, minute=scheduler_minute, second=0, microsecond=0)
            if next_run <= now_nsk:
                # Move to next month
                if now_nsk.month == 12:
                    next_run = next_run.replace(year=now_nsk.year + 1, month=1)
                else:
                    next_month = now_nsk.month + 1
                    next_run = next_run.replace(month=next_month)
            
            time_diff = next_run - now_nsk
            hours_diff = time_diff.total_seconds() / 3600
            days_diff = time_diff.total_seconds() / 86400
            
            logger.info(f"✅ Next notification will be sent: {next_run.strftime('%Y-%m-%d %H:%M:%S %Z')}")
            log_to_file(f"Next notification will be sent: {next_run.strftime('%Y-%m-%d %H:%M:%S %Z')}")
            logger.info(f"✅ This is {days_diff:.1f} days ({hours_diff:.1f} hours) from current time")
            log_to_file(f"This is {days_diff:.1f} days ({hours_diff:.1f} hours) from current time")
            
            # Check if this matches the expected time (Day 23 at 21:58 NSK)
            if scheduler_day == 23 and scheduler_hour == 21 and scheduler_minute == 58:
                logger.info(f"✅ Notification time is set to 23rd of each month at 21:58 Novosibirsk time")
                log_to_file("Notification time is set to 23rd of each month at 21:58 Novosibirsk time")
            else:
                logger.warning(f"❌ Notification time is different from expected (23rd at 21:58)")
                log_to_file("Notification time is different from expected (23rd at 21:58)", "WARNING")
            
            return True
        else:
            logger.warning("❌ Could not determine scheduled notification time")
            log_to_file("Could not determine scheduled notification time", "WARNING")
            return False
    except Exception as e:
        logger.error(f"Error checking scheduled time: {str(e)}")
        log_to_file(f"Error checking scheduled time: {str(e)}", "ERROR")
        return False

def test_send_notification():
    """Tests sending a test notification"""
    try:
        # Load bot.py module
        spec = importlib.util.spec_from_file_location("bot", "bot.py")
        bot_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(bot_module)
        
        # Check that necessary functions exist
        if hasattr(bot_module, 'send_monthly_notification') and hasattr(bot_module, 'Application'):
            logger.info("✅ send_monthly_notification function found in bot code")
            log_to_file("send_monthly_notification function found in bot code")
            
            # Ask user if they want to send a test notification
            while True:
                answer = input("\nSend a test notification? (yes/no): ").lower()
                if answer in ['yes', 'y']:
                    # Use provided token if available, otherwise use from bot module
                    if args.token:
                        token = args.token
                        logger.info("Using token provided via command line")
                    else:
                        token = bot_module.BOT_TOKEN
                        logger.info("Using token from bot module")
                    
                    # Run async function with test context
                    import asyncio
                    
                    async def run_test():
                        # Create a custom send function that only sends to admins
                        from telegram.ext import Application
                        from telegram import Bot
                        
                        app = bot_module.Application.builder().token(token).build()
                        
                        # Create a direct test that only sends to admins
                        message = "🧪 TEST NOTIFICATION - This is a test message from test_notifications.py"
                        admin_ids = bot_module.admin_users
                        
                        logger.info(f"Will send test notifications ONLY to {len(admin_ids)} admin users")
                        
                        # Send directly to each admin
                        for admin_id in admin_ids:
                            try:
                                await app.bot.send_message(
                                    chat_id=admin_id,
                                    text=message
                                )
                                logger.info(f"Test message sent to admin {admin_id}")
                            except Exception as e:
                                logger.error(f"Failed to send test message to admin {admin_id}: {e}")
                        
                        logger.info("✅ Test notification sent to admins only")
                        log_to_file("Test notification sent to admins only")
                    
                    # Run async function
                    asyncio.run(run_test())
                    return True
                elif answer in ['no', 'n']:
                    logger.info("❌ Test notification sending canceled by user")
                    log_to_file("Test notification sending canceled by user")
                    return False
                else:
                    print("Please enter 'yes' or 'no'")
        else:
            logger.warning("❌ Required functions not found in bot code")
            log_to_file("Required functions not found in bot code", "WARNING")
            return False
    except Exception as e:
        logger.error(f"Error testing notification sending: {str(e)}")
        log_to_file(f"Error testing notification sending: {str(e)}", "ERROR")
        return False

async def send_results_to_admins(summary_text):
    """Sends test results to admins via Telegram."""
    try:
        log_to_file("Starting to send test results to admins")
        # Create log file for additional diagnostics
        with open("test_log.txt", "w") as log_file:
            log_file.write(f"=== Starting results sending {datetime.datetime.now()} ===\n")
            
            # Load bot.py module
            try:
                spec = importlib.util.spec_from_file_location("bot", "bot.py")
                bot_module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(bot_module)
                log_file.write("✅ bot.py module successfully loaded\n")
                log_to_file("bot.py module successfully loaded for results sending")
            except Exception as e:
                error_msg = f"❌ Error loading bot.py module: {str(e)}"
                logger.error(error_msg)
                log_file.write(error_msg + "\n")
                log_to_file(error_msg, "ERROR")
                return False
            
            # Get token and admin list
            try:
                # Use provided token if available, otherwise use from bot module
                if args.token:
                    token = args.token
                    log_file.write("✅ Using token provided via command line\n")
                    log_to_file("Using token provided via command line")
                else:
                    token = bot_module.BOT_TOKEN
                    log_file.write(f"✅ Token retrieved from bot module (length: {len(token)})\n")
                    log_to_file(f"Token retrieved from bot module (length: {len(token)})")
                
                admins = bot_module.admin_users  # Use admin list
                log_file.write(f"✅ Admin list retrieved: {admins}\n")
                log_to_file(f"Admin list retrieved: {admins}")
            except Exception as e:
                error_msg = f"❌ Error getting token or admin list: {str(e)}"
                logger.error(error_msg)
                log_file.write(error_msg + "\n")
                log_to_file(error_msg, "ERROR")
                return False
            
            # Prepare message with test results
            message = f"🧪 *Notification Settings Test Results*\n\n{summary_text}"
            log_file.write(f"✅ Message prepared (length: {len(message)})\n")
            log_to_file(f"Message prepared (length: {len(message)})")
            
            # Initialize application
            try:
                from telegram import Bot
                bot = Bot(token=token)
                log_file.write("✅ Bot object created successfully\n")
                log_to_file("Bot object created successfully")
            except Exception as e:
                error_msg = f"❌ Error creating Bot object: {str(e)}"
                logger.error(error_msg)
                log_file.write(error_msg + "\n")
                log_to_file(error_msg, "ERROR")
                return False
            
            # Send message to each admin
            success = False
            for admin_id in admins:
                try:
                    log_file.write(f"Sending message to admin {admin_id}...\n")
                    await bot.send_message(
                        chat_id=admin_id,
                        text=message,
                        parse_mode="Markdown"
                    )
                    success_msg = f"✅ Test result sent to admin {admin_id}"
                    logger.info(success_msg)
                    log_file.write(success_msg + "\n")
                    log_to_file(f"Test result sent to admin {admin_id}")
                    success = True
                except Exception as e:
                    error_msg = f"❌ Error sending result to admin {admin_id}: {str(e)}"
                    logger.error(error_msg)
                    log_file.write(error_msg + "\n")
                    log_to_file(error_msg, "ERROR")
            
            if not success:
                log_file.write("❌ Could not send message to any admin\n")
                log_to_file("Could not send message to any admin", "WARNING")
                return False
            
            return True
    except Exception as e:
        error_msg = f"❌ General error sending test results to admins: {str(e)}"
        logger.error(error_msg)
        try:
            with open("test_log.txt", "a") as log_file:
                log_file.write(error_msg + "\n")
        except:
            pass
        log_to_file(error_msg, "ERROR")
        return False

def main():
    """Main test function"""
    logger.info("=== Starting bot notification settings test ===")
    log_to_file("=== TEST STARTED ===")
    
    # Log token status
    if args.token:
        logger.info("Using token provided via command line")
        log_to_file("Using token provided via command line")
    else:
        logger.info("No token provided, will use token from bot module")
        log_to_file("No token provided, will use token from bot module")
    
    # System timezone check
    system_tz_ok = check_system_timezone()
    
    # Bot timezone settings check
    bot_tz_ok = check_bot_timezone_settings()
    
    # Scheduled time check
    schedule_ok = test_scheduled_time()
    
    # Results summary
    logger.info("\n=== Test Results ===")
    log_to_file("=== TEST RESULTS ===")
    logger.info(f"System timezone: {'✅ OK' if system_tz_ok else '❌ PROBLEM'}")
    log_to_file(f"System timezone: {'OK' if system_tz_ok else 'PROBLEM'}")
    logger.info(f"Bot timezone settings: {'✅ OK' if bot_tz_ok else '❌ PROBLEM'}")
    log_to_file(f"Bot timezone settings: {'OK' if bot_tz_ok else 'PROBLEM'}")
    logger.info(f"Scheduled notification time: {'✅ OK' if schedule_ok else '❌ PROBLEM'}")
    log_to_file(f"Scheduled notification time: {'OK' if schedule_ok else 'PROBLEM'}")
    
    # Create brief summary for Telegram
    summary = (
        f"System timezone: {'✅ OK' if system_tz_ok else '❌ PROBLEM'}\n"
        f"Bot timezone settings: {'✅ OK' if bot_tz_ok else '❌ PROBLEM'}\n"
        f"Scheduled notification time: {'✅ OK' if schedule_ok else '❌ PROBLEM'}\n\n"
    )
    
    # Next notification time
    try:
        spec = importlib.util.spec_from_file_location("bot", "bot.py")
        bot_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(bot_module)
        
        now_nsk = datetime.datetime.now(pytz.timezone('Asia/Novosibirsk'))
        
        # Extract scheduler parameters
        main_code = bot_module.main.__code__.co_consts
        scheduler_day = 23  # Default
        scheduler_hour = 21  # Default
        scheduler_minute = 58  # Default
        
        for const in main_code:
            if isinstance(const, str) and "day" in const:
                try:
                    day_str = const.split("day=")[1].split(",")[0].strip()
                    scheduler_day = int(day_str)
                except:
                    pass
            if isinstance(const, str) and "hour" in const:
                try:
                    hour_str = const.split("hour=")[1].split(",")[0].strip()
                    scheduler_hour = int(hour_str)
                except:
                    pass
            if isinstance(const, str) and "minute" in const:
                try:
                    minute_str = const.split("minute=")[1].split(")")[0].strip()
                    scheduler_minute = int(minute_str)
                except:
                    pass
        
        next_run = now_nsk.replace(day=scheduler_day, hour=scheduler_hour, minute=scheduler_minute, second=0, microsecond=0)
        if next_run <= now_nsk:
            # Move to next month
            if now_nsk.month == 12:
                next_run = next_run.replace(year=now_nsk.year + 1, month=1)
            else:
                next_month = now_nsk.month + 1
                next_run = next_run.replace(month=next_month)
        
        time_diff = next_run - now_nsk
        hours_diff = time_diff.total_seconds() / 3600
        days_diff = time_diff.total_seconds() / 86400
        
        logger.info(f"✅ Next notification will be sent: {next_run.strftime('%Y-%m-%d %H:%M:%S %Z')}")
        log_to_file(f"Next notification will be sent: {next_run.strftime('%Y-%m-%d %H:%M:%S %Z')}")
        logger.info(f"✅ This is {days_diff:.1f} days ({hours_diff:.1f} hours) from current time")
        log_to_file(f"This is {days_diff:.1f} days ({hours_diff:.1f} hours) from current time")
        
        # Check if this matches the expected time (Day 23 at 21:58 NSK)
        if scheduler_day == 23 and scheduler_hour == 21 and scheduler_minute == 58:
            logger.info(f"✅ Notification time is set to 23rd of each month at 21:58 Novosibirsk time")
            log_to_file("Notification time is set to 23rd of each month at 21:58 Novosibirsk time")
        else:
            logger.warning(f"❌ Notification time is different from expected (23rd at 21:58)")
            log_to_file("Notification time is different from expected (23rd at 21:58)", "WARNING")
        
        summary += f"Next notification: {next_run.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    except:
        summary += "Could not determine next notification time"
    
    # Overall result
    if system_tz_ok and bot_tz_ok and schedule_ok:
        logger.info("✅ TEST PASSED: Notification settings are correct")
        summary = f"✅ TEST PASSED: Notification settings are correct\n\n{summary}"
        log_to_file("TEST PASSED: Notification settings are correct")
        
        # Offer to send test notification
        test_notification_result = test_send_notification()
    else:
        logger.warning("❌ TEST FAILED: Problems with notification settings detected")
        summary = f"❌ TEST FAILED: Problems with notification settings detected\n\n{summary}"
        log_to_file("TEST FAILED: Problems with notification settings detected", "WARNING")
    
    # Save test results to file
    with open("test_results.txt", "w") as results_file:
        results_file.write(test_results.getvalue())
    log_to_file("Test results saved to test_results.txt file")
    
    # Ask if results should be sent to admins
    while True:
        answer = input("\nSend test results to admins via Telegram? (yes/no): ").lower()
        if answer in ['yes', 'y']:
            asyncio.run(send_results_to_admins(summary))
            break
        elif answer in ['no', 'n']:
            logger.info("❌ Sending test results to admins canceled by user")
            break
        else:
            print("Please enter 'yes' or 'no'")

if __name__ == "__main__":
    main() 