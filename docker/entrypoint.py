#!/usr/bin/env python3
"""
entrypoint.py - Docker entrypoint script for the Telegram bot

This script initializes the bot environment, runs startup checks,
and launches the bot application.
"""

import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# Add scripts directory to Python path
scripts_dir = os.path.join(os.path.dirname(__file__), "..", "scripts")
sys.path.insert(0, scripts_dir)

try:
    from scripts import (
        Colors,
        debug_print,
        print_error,
        print_message,
        quick_health_check,
        setup_permissions,
    )
except ImportError as e:
    print(f"Failed to import scripts: {e}")
    print(f"Scripts directory: {scripts_dir}")
    print(f"Python path: {sys.path[:3]}")
    sys.exit(1)

# Configuration
DATA_DIR = Path("/app/data")
LOGS_DIR = Path("/app/logs")
DEFAULT_JSON_FILES = ["bot_admins.json", "bot_users.json", "quotes.json"]

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
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


def cleanup_unused_images():
    """Clean up dangling Docker images belonging only to this project"""
    log_message("INFO", "Cleaning up project-specific dangling Docker images")

    try:
        system_name = os.getenv("SYSTEM_NAME")
        if not system_name:
            log_message("WARN", "SYSTEM_NAME not found, cannot filter project images")
            return

        log_message(
            "INFO", f"Looking for dangling images related to project: {system_name}"
        )

        # Strategy 1: Find dangling images with project name label
        result_project_labeled = subprocess.run(
            [
                "docker",
                "images",
                "-f",
                "dangling=true",
                "-f",
                f"label=project.name={system_name}",
                "-q",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        # Strategy 2: Find dangling images with Docker Compose project label (fallback)
        result_compose_labeled = subprocess.run(
            [
                "docker",
                "images",
                "-f",
                "dangling=true",
                "-f",
                f"label=com.docker.compose.project={system_name}",
                "-q",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        # Strategy 2: Find all dangling images and filter by name pattern
        result_all_dangling = subprocess.run(
            [
                "docker",
                "images",
                "-f",
                "dangling=true",
                "--format",
                "{{.ID}} {{.Repository}}",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        project_dangling_images = set()

        # Collect images from project name labeled strategy
        if (
            result_project_labeled.returncode == 0
            and result_project_labeled.stdout.strip()
        ):
            project_labeled_images = [
                img_id.strip()
                for img_id in result_project_labeled.stdout.strip().split("\n")
                if img_id.strip()
            ]
            project_dangling_images.update(project_labeled_images)
            log_message(
                "INFO",
                f"Found {len(project_labeled_images)} dangling images with project.name label",
            )

        # Collect images from Docker Compose labeled strategy (fallback)
        if (
            result_compose_labeled.returncode == 0
            and result_compose_labeled.stdout.strip()
        ):
            compose_labeled_images = [
                img_id.strip()
                for img_id in result_compose_labeled.stdout.strip().split("\n")
                if img_id.strip()
            ]
            project_dangling_images.update(compose_labeled_images)
            log_message(
                "INFO",
                f"Found {len(compose_labeled_images)} dangling images with Docker Compose project label",
            )

        # Collect images from name pattern strategy
        if result_all_dangling.returncode == 0 and result_all_dangling.stdout.strip():
            lines = result_all_dangling.stdout.strip().split("\n")
            for line in lines:
                if line.strip():
                    parts = line.strip().split(" ", 1)
                    if len(parts) >= 2:
                        img_id, repo = parts[0], parts[1]
                        # Check if repository name contains our system name
                        if system_name.lower() in repo.lower() or repo.startswith(
                            system_name
                        ):
                            project_dangling_images.add(img_id)
                            log_message(
                                "INFO",
                                f"Found dangling image by name pattern: {img_id} ({repo})",
                            )

        if not project_dangling_images:
            log_message("INFO", f"No dangling images found for project: {system_name}")
            return

        project_dangling_list = list(project_dangling_images)
        log_message(
            "INFO",
            f"Removing {len(project_dangling_list)} dangling images for project '{system_name}'",
        )

        # Remove project-specific dangling images
        if project_dangling_list:
            result = subprocess.run(
                ["docker", "rmi"] + project_dangling_list,
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode == 0:
                log_message("INFO", "Successfully cleaned up project dangling images")
            else:
                log_message("WARN", "Failed to remove some project dangling images")

    except Exception as e:
        log_message("WARN", f"Error during project image cleanup: {e}")


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
        subprocess.run(["cp", str(bot_log), str(backup_file)], check=False)

        # Reset current log file (create new empty file)
        with open(bot_log, "w") as f:
            f.write(
                f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Log file rotated - new session started\n",
            )

        # Clean up old archives (keep last 5)
        archive_files = sorted(
            backup_dir.glob("bot_*.log"),
            key=lambda x: x.stat().st_mtime,
            reverse=True,
        )
        if len(archive_files) > 5:
            log_message(
                "INFO",
                "Cleaning up old log archives, keeping only the 5 most recent",
            )
            for old_file in archive_files[5:]:
                old_file.unlink()
    else:
        # Create new log file if it doesn't exist
        with open(bot_log, "w") as f:
            f.write(
                f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] New log file created - session started\n",
            )

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
            mtime = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M")
            print_message(
                f"    {permissions} {size:>8} {mtime} {item.name}",
                Colors.CYAN,
            )
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
                    f.write(
                        f"{datetime.now()}: Running health check monitoring cycle\n",
                    )

                # Check if the bot process is running using our health check module
                is_healthy = quick_health_check()

                with open(health_log, "a") as f:
                    if is_healthy:
                        f.write(f"{datetime.now()}: Bot process is healthy\n")
                    else:
                        f.write(
                            f"{datetime.now()}: WARNING - Bot health check failed\n",
                        )

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
        check=False,
        capture_output=True,
        text=True,
    )

    if result.returncode == 0:
        log_message("WARN", "Detected existing bot process, terminating it")
        subprocess.run(["pkill", "-f", "python.*src.*bot"], check=False)

        # Wait for process to terminate
        time.sleep(2)

        # Check if it's still running
        result = subprocess.run(
            ["pgrep", "-f", "python.*src.*bot"],
            check=False,
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            log_message("WARN", "Process did not terminate gracefully, sending SIGKILL")
            subprocess.run(["pkill", "-9", "-f", "python.*src.*bot"], check=False)
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
        log_message(
            "INFO",
            "No BOT_TOKEN provided in environment, using config from code",
        )
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
    cleanup_unused_images()  # Clean up dangling images before starting
    setup_health_system()
    setup_data_directory()
    rotate_logs()

    start_health_monitor()

    # Start the bot (this will exec, replacing the current process)
    start_bot()


if __name__ == "__main__":
    main()
