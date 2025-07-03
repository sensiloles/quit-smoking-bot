"""
actions.py - Action handlers and core operations

This module provides action handlers for bot management operations.
"""

import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Optional, Dict, Any, List

from .output import print_error, print_message, print_warning, debug_print, Colors, print_success
from .environment import get_system_name, check_bot_token, update_env_token, is_dry_run
from .docker_utils import check_docker_installation, run_docker_command, get_container_status, cleanup_docker_resources
from .health import check_bot_status, is_bot_operational
from .errors import BotError, DockerError, handle_error, ErrorContext

def action_setup(token: Optional[str] = None) -> bool:
    """Setup the bot environment"""
    debug_print("Starting setup action")
    
    with ErrorContext("Bot setup"):
        print_message("🚀 Setting up Quit Smoking Bot...", Colors.BLUE)
        
        # Step 1: Check Docker installation
        print_message("Step 1: Checking Docker installation...", Colors.YELLOW)
        if not check_docker_installation():
            raise DockerError("Docker is not properly installed or running")
        print_success("✅ Docker is ready")
        
        # Step 2: Setup environment
        print_message("Step 2: Setting up environment...", Colors.YELLOW)
        if token:
            debug_print(f"Token provided, updating .env file")
            if not update_env_token(token):
                raise BotError("Failed to update BOT_TOKEN")
            print_success("✅ BOT_TOKEN configured")
        elif not check_bot_token():
            raise BotError("BOT_TOKEN is not configured. Please provide a token.")
        else:
            print_success("✅ BOT_TOKEN already configured")
        
        # Step 3: Create necessary directories
        print_message("Step 3: Creating directories...", Colors.YELLOW)
        for dir_name in ["data", "logs", "backups"]:
            dir_path = Path(dir_name)
            dir_path.mkdir(exist_ok=True)
            debug_print(f"Created directory: {dir_name}")
        print_success("✅ Directories created")
        
        # Step 4: Set permissions
        print_message("Step 4: Setting up permissions...", Colors.YELLOW)
        from .system import setup_permissions
        if not setup_permissions():
            print_warning("⚠️  Permission setup had issues, but continuing...")
        else:
            print_success("✅ Permissions configured")
        
        print_success("🎉 Setup completed successfully!")
        print_message("You can now start the bot with: python scripts/start.py start", Colors.GREEN)
        
        return True

def action_start(profile: str = "prod", dry_run: bool = False, force_rebuild: bool = False, enable_monitoring: bool = False, enable_logging: bool = False) -> bool:
    """Start the bot service"""
    debug_print(f"Starting bot with profile: {profile}, dry_run: {dry_run}")
    
    with ErrorContext("Bot start"):
        print_message(f"🚀 Starting {get_system_name()} (profile: {profile})...", Colors.BLUE)
        
        # Check if already running
        status = get_container_status()
        if status["running"]:
            print_warning("Bot is already running!")
            print_message("Container status:", Colors.YELLOW)
            subprocess.run(["docker-compose", "ps"], capture_output=False)
            return True
        
        # Check Docker
        if not check_docker_installation():
            raise DockerError("Docker is not properly installed or running")
        
        # Check environment
        if not check_bot_token():
            raise BotError("BOT_TOKEN is not configured")
        
        # Build containers if needed
        if force_rebuild:
            print_message("Force rebuilding Docker containers...", Colors.YELLOW)
            build_cmd = ["docker-compose", "build", "--no-cache"]
            if dry_run or is_dry_run():
                print_message(f"DRY RUN: Would execute: {' '.join(build_cmd)}", Colors.YELLOW)
            else:
                result = subprocess.run(build_cmd, capture_output=False)
                if result.returncode != 0:
                    raise DockerError("Failed to rebuild containers")
        
        # Determine compose profiles
        compose_profiles = []
        if enable_monitoring:
            compose_profiles.append("monitoring")
        if enable_logging:
            compose_profiles.append("logging")
        
        # Prepare environment variables for docker-compose
        env = os.environ.copy()
        
        if dry_run or is_dry_run():
            profiles_str = " ".join(f"--profile {p}" for p in compose_profiles)
            print_message("DRY RUN: Would start bot with the following command:", Colors.YELLOW)
            print_message(f"docker-compose {profiles_str} up -d --build", Colors.YELLOW)
            return True
        
        # Start the service
        print_message("Starting bot container...", Colors.YELLOW)
        cmd = ["docker-compose"]
        for profile in compose_profiles:
            cmd.extend(["--profile", profile])
        cmd.extend(["up", "-d", "--build"])
        
        result = subprocess.run(cmd, env=env, capture_output=False)
        if result.returncode != 0:
            raise DockerError("Failed to start bot container", " ".join(cmd))
        
        # Check status after startup
        print_message("Checking bot status after startup...", Colors.YELLOW)
        status = check_bot_status()
        
        if status["bot_operational"]:
            print_success("🎉 Bot started successfully!")
            return True
        else:
            print_warning("⚠️  Bot started but may not be fully operational")
            print_message("Check logs with: docker-compose logs bot", Colors.YELLOW)
            return False

def action_stop(confirm: bool = False) -> bool:
    """Stop the bot service"""
    debug_print("Stopping bot service")
    
    with ErrorContext("Bot stop"):
        # Check if running
        status = get_container_status()
        if not status["running"]:
            print_message("Bot is not running", Colors.YELLOW)
            return True
        
        if not confirm:
            print_message("This will stop the bot service.", Colors.YELLOW)
            response = input("Are you sure? (y/N): ").strip().lower()
            if response not in ['y', 'yes']:
                print_message("Operation cancelled", Colors.YELLOW)
                return True
        
        print_message("🛑 Stopping bot...", Colors.YELLOW)
        
        result = subprocess.run(["docker-compose", "down"], capture_output=False)
        if result.returncode != 0:
            raise DockerError("Failed to stop bot container")
        
        print_success("✅ Bot stopped successfully")
        return True

def action_restart(profile: str = "prod") -> bool:
    """Restart the bot service"""
    debug_print(f"Restarting bot with profile: {profile}")
    
    print_message("🔄 Restarting bot...", Colors.BLUE)
    
    # Stop first
    if not action_stop(confirm=True):
        return False
    
    # Wait a moment
    time.sleep(2)
    
    # Start again
    return action_start(profile)

def action_status() -> bool:
    """Show bot status"""
    debug_print("Checking bot status")
    
    print_message("📊 Bot Status Check", Colors.BLUE)
    
    # Check container status
    status = get_container_status()
    
    if not status["exists"]:
        print_message("❌ No bot containers found", Colors.RED)
        print_message("Run 'python scripts/start.py start' to start the bot", Colors.YELLOW)
        return False
    
    if status["running"]:
        print_message("✅ Bot container is running", Colors.GREEN)
        
        # Show container info
        print_message("\nContainer status:", Colors.BLUE)
        subprocess.run(["docker-compose", "ps"], capture_output=False)
        
        # Check operational status
        if is_bot_operational():
            print_message("\n✅ Bot is operational", Colors.GREEN)
        else:
            print_message("\n⚠️  Bot is running but may not be operational", Colors.YELLOW)
        
        # Show recent logs
        print_message("\nRecent logs:", Colors.BLUE)
        subprocess.run(["docker-compose", "logs", "--tail", "10", "bot"], capture_output=False)
        
    else:
        print_message("❌ Bot container is not running", Colors.RED)
        print_message("Run 'python scripts/start.py start' to start the bot", Colors.YELLOW)
    
    return status["running"]

def action_logs(follow: bool = False, lines: int = 50) -> bool:
    """Show bot logs"""
    debug_print(f"Showing logs, follow: {follow}, lines: {lines}")
    
    # Check if container exists
    status = get_container_status()
    if not status["exists"]:
        print_error("No bot containers found")
        return False
    
    print_message(f"📋 Bot Logs (last {lines} lines):", Colors.BLUE)
    
    cmd = ["docker-compose", "logs", "--tail", str(lines)]
    if follow:
        cmd.append("-f")
    cmd.append("bot")
    
    try:
        subprocess.run(cmd, capture_output=False)
        return True
    except KeyboardInterrupt:
        print_message("\n🛑 Log viewing interrupted", Colors.YELLOW)
        return True

def action_cleanup(service: str = "", full: bool = False) -> bool:
    """Clean up Docker resources"""
    debug_print(f"Cleaning up resources, service: {service}, full: {full}")
    
    print_message("🧹 Cleaning up Docker resources...", Colors.YELLOW)
    
    if not full:
        response = input("This will remove containers and images. Continue? (y/N): ").strip().lower()
        if response not in ['y', 'yes']:
            print_message("Operation cancelled", Colors.YELLOW)
            return True
    
    return cleanup_docker_resources(service, full)

def action_prune(confirm: bool = False) -> bool:
    """Remove all bot data, logs, and containers"""
    debug_print("Cleaning up all bot data")
    
    if not confirm:
        print_message("⚠️  This will remove all bot data, logs, and containers!", Colors.RED)
        print_message("This action cannot be undone.", Colors.RED)
        response = input("Are you sure you want to continue? (Yes/No): ").strip().lower()
        if response not in ['yes', 'y']:
            print_message("Operation cancelled", Colors.YELLOW)
            return True
    
    with ErrorContext("Bot cleanup"):
        print_message("🧹 Cleaning up bot data...", Colors.YELLOW)
        
        # Stop everything
        print_message("Stopping all services...", Colors.YELLOW)
        subprocess.run(["docker-compose", "down", "-v", "--remove-orphans"], capture_output=False)
        
        # Remove images
        print_message("Removing Docker images...", Colors.YELLOW)
        cleanup_docker_resources(cleanup_all=True)
        
        # Remove data directories
        print_message("Removing data directories...", Colors.YELLOW)
        for dir_name in ["data", "logs"]:
            dir_path = Path(dir_name)
            if dir_path.exists():
                import shutil
                shutil.rmtree(dir_path)
                debug_print(f"Removed directory: {dir_name}")
        
        print_success("✅ Bot data cleanup completed!")
        print_message("Run 'python scripts/start.py --install' to initialize again", Colors.GREEN)
        return True

def action_backup() -> bool:
    """Backup bot data"""
    debug_print("Creating backup")
    
    with ErrorContext("Bot backup"):
        print_message("💾 Creating backup...", Colors.BLUE)
        
        # Create backup directory
        backup_dir = Path("backups")
        backup_dir.mkdir(exist_ok=True)
        
        # Create timestamped backup
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        backup_name = f"bot_backup_{timestamp}.tar.gz"
        backup_path = backup_dir / backup_name
        
        # Create backup archive
        print_message("Creating backup archive...", Colors.YELLOW)
        cmd = [
            "tar", "czf", str(backup_path),
            "--exclude=backups",
            "--exclude=logs/*.log",
            "data", "logs", ".env"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise BotError(f"Failed to create backup: {result.stderr}")
        
        print_success(f"✅ Backup created: {backup_path}")
        return True

def action_restore(backup_file: str) -> bool:
    """Restore bot data from backup"""
    debug_print(f"Restoring from backup: {backup_file}")
    
    backup_path = Path(backup_file)
    if not backup_path.exists():
        raise BotError(f"Backup file not found: {backup_file}")
    
    with ErrorContext("Bot restore"):
        print_message(f"📦 Restoring from backup: {backup_file}...", Colors.BLUE)
        
        # Stop bot if running
        status = get_container_status()
        if status["running"]:
            print_message("Stopping bot for restore...", Colors.YELLOW)
            if not action_stop(confirm=True):
                raise BotError("Failed to stop bot for restore")
        
        # Extract backup
        print_message("Extracting backup...", Colors.YELLOW)
        cmd = ["tar", "xzf", str(backup_path)]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise BotError(f"Failed to restore backup: {result.stderr}")
        
        print_success("✅ Backup restored successfully!")
        print_message("You may need to restart the bot: python scripts/start.py start", Colors.GREEN)
        return True 