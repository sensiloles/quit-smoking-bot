#!/usr/bin/env python3
"""
entrypoint.py - Docker entrypoint script for the Telegram bot

This script initializes the bot environment, runs startup checks,
and launches the bot application.
"""

import os
import sys
import time
import json
import logging
import subprocess
import signal
from pathlib import Path
from datetime import datetime
from typing import List

# Add scripts directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from modules import (
    print_message, print_error, print_success, debug_print, Colors,
    setup_permissions, get_system_info, quick_health_check
)

# Configuration
DATA_DIR = Path("/app/data")
LOGS_DIR = Path("/app/logs")
DEFAULT_JSON_FILES = ["bot_admins.json", "bot_users.json", "quotes.json"]

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def log_message(level: str, message: str):
    """Log message to console with timestamp"""
    if level.upper() == "INFO":
        logger.info(message)
        print_message(message, Colors.GREEN)
    elif level.upper() == "WARN":
        logger.warning(message)
        print_message(f"⚠️  {message}", Colors.YELLOW)
    elif level.upper() == "ERROR":
        logger.error(message)
        print_error(f"❌ {message}")
    else:
        logger.info(f"[{level}] {message}")
        print_message(f"[{level}] {message}", Colors.BLUE)
    
    # Also debug print if DEBUG mode is enabled
    debug_print(f"[entrypoint.py] [{level}] {message}")

def setup_health_system():
    """Initialize the health monitoring system"""
    log_message("INFO", "Initializing health monitoring system")
    
    # Create simple health status in logs
    health_log = LOGS_DIR / "health.log"
    with open(health_log, "a") as f:
        f.write(f"{datetime.now()}: Bot is starting up\n")
    
    log_message("INFO", "Health monitoring system initialized")

def rotate_logs():
    """Rotate logs to prevent accumulation of old errors"""
    log_message("INFO", "Setting up log rotation")

    # Create logs directory if it doesn't exist
    LOGS_DIR.mkdir(parents=True, exist_ok=True)

    bot_log = LOGS_DIR / "bot.log"
    
    # If log file exists and is not empty, rotate it
    if bot_log.exists() and bot_log.stat().st_size > 0:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = LOGS_DIR / "archive"
        backup_dir.mkdir(parents=True, exist_ok=True)

        # Move current log to archive with timestamp
        log_message("INFO", "Rotating existing log file to archive")
        backup_file = backup_dir / f"bot_{timestamp}.log"
        subprocess.run(["cp", str(bot_log), str(backup_file)])

        # Reset current log file (create new empty file)
        with open(bot_log, "w") as f:
            f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Log file rotated - new session started\n")

        # Clean up old archives (keep last 5)
        archive_files = sorted(backup_dir.glob("bot_*.log"), key=lambda x: x.stat().st_mtime, reverse=True)
        if len(archive_files) > 5:
            log_message("INFO", "Cleaning up old log archives, keeping only the 5 most recent")
            for old_file in archive_files[5:]:
                old_file.unlink()
    else:
        # Create new log file if it doesn't exist
        with open(bot_log, "w") as f:
            f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] New log file created - session started\n")

    # Ensure proper permissions
    bot_log.chmod(0o644)
    log_message("INFO", "Log rotation completed")

def setup_data_directory():
    """Initialize data directory and create default files if missing"""
    log_message("INFO", "Checking data directory and files")

    # Create data directory if it doesn't exist
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Create default JSON files if they don't exist
    for file_name in DEFAULT_JSON_FILES:
        file_path = DATA_DIR / file_name
        if not file_path.exists():
            log_message("WARN", f"{file_name} not found, creating empty file")
            with open(file_path, "w") as f:
                json.dump([], f)
            file_path.chmod(0o644)

    # Setup permissions using the new module
    log_message("INFO", "Setting up permissions")
    if setup_permissions():
        log_message("INFO", "Permissions setup completed")
    else:
        log_message("WARN", "Permission setup had issues")

    # List data directory contents for logging
    log_message("INFO", "Data directory contents:")
    try:
        for item in DATA_DIR.iterdir():
            stat = item.stat()
            permissions = oct(stat.st_mode)[-3:]
            size = stat.st_size
            mtime = datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M')
            print_message(f"    {permissions} {size:>8} {mtime} {item.name}", Colors.CYAN)
    except Exception as e:
        log_message("WARN", f"Could not list directory contents: {e}")

def start_health_monitor():
    """Start the health monitoring daemon in the background"""
    log_message("INFO", "Starting health monitor daemon")

    def health_monitor_daemon():
        """Health monitor daemon function"""
        # Wait for the bot to start up before first check
        time.sleep(10)

        health_log = LOGS_DIR / "health.log"
        
        # Check every 30 seconds if the bot is operational
        while True:
            try:
                with open(health_log, "a") as f:
                    f.write(f"{datetime.now()}: Running health check monitoring cycle\n")

                # Check if the bot process is running using our health check module
                is_healthy = quick_health_check()
                
                with open(health_log, "a") as f:
                    if is_healthy:
                        f.write(f"{datetime.now()}: Bot process is healthy\n")
                    else:
                        f.write(f"{datetime.now()}: WARNING - Bot health check failed\n")

                time.sleep(30)
            except Exception as e:
                with open(health_log, "a") as f:
                    f.write(f"{datetime.now()}: ERROR in health monitor: {e}\n")
                time.sleep(30)

    # Start daemon in background
    import threading
    daemon_thread = threading.Thread(target=health_monitor_daemon, daemon=True)
    daemon_thread.start()
    
    log_message("INFO", "Health monitor daemon started")

def terminate_existing_processes():
    """Check for and terminate existing bot processes"""
    result = subprocess.run(
        ["pgrep", "-f", "python.*src.*bot"],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        log_message("WARN", "Detected existing bot process, terminating it")
        subprocess.run(["pkill", "-f", "python.*src.*bot"])

        # Wait for process to terminate
        time.sleep(2)

        # Check if it's still running
        result = subprocess.run(
            ["pgrep", "-f", "python.*src.*bot"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            log_message("WARN", "Process did not terminate gracefully, sending SIGKILL")
            subprocess.run(["pkill", "-9", "-f", "python.*src.*bot"])
            time.sleep(1)

        log_message("INFO", "Existing process terminated")

def start_bot():
    """Start the bot application"""
    log_message("INFO", "Starting Telegram bot")

    os.chdir("/app")

    bot_token = os.getenv("BOT_TOKEN")
    if bot_token:
        log_message("INFO", "Using BOT_TOKEN from environment variable")
        os.execvp("python", ["python", "-m", "src.bot", "--token", bot_token])
    else:
        log_message("INFO", "No BOT_TOKEN provided in environment, using config from code")
        os.execvp("python", ["python", "-m", "src.bot"])

def main():
    """Main execution flow"""
    log_message("INFO", "Starting bot container initialization")

    # Create logs directory if it doesn't exist
    LOGS_DIR.mkdir(parents=True, exist_ok=True)

    # Check if we can write to the log directory
    if not os.access(LOGS_DIR, os.W_OK):
        log_message("WARN", f"Cannot write to {LOGS_DIR} directory, fixing permissions")
        LOGS_DIR.chmod(0o755)

    # Set Python path to include the app directory
    python_path = os.getenv("PYTHONPATH", "")
    os.environ["PYTHONPATH"] = f"/app:{python_path}"

    # Initialize all systems
    terminate_existing_processes()
    setup_health_system()
    setup_data_directory()
    rotate_logs()

    start_health_monitor()

    # Start the bot (this will exec, replacing the current process)
    start_bot()

if __name__ == "__main__":
    main() 