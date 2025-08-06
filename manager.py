#!/usr/bin/env python3
"""
Telegram Bot Framework Manager

Simple management interface for Docker-based Telegram bots.
Single tool for all bot management operations.
"""

import os
import sys
import argparse
import subprocess
import json
from pathlib import Path
from typing import Dict, Optional


class BotManager:
    """Simple bot management class"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.absolute()
        self.env_file = self.project_root / ".env"
        self.compose_file = self.project_root / "docker-compose.yml"
        os.chdir(self.project_root)
        
        # Load SYSTEM_NAME from .env file
        self.system_name = "telegram-bot"  # default
        if self.env_file.exists():
            with open(self.env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('SYSTEM_NAME='):
                        self.system_name = line.split('=', 1)[1].strip('"\'')
                        break
    
    def _run_command(self, cmd: list, capture_output: bool = False) -> subprocess.CompletedProcess:
        """Run shell command with proper error handling"""
        try:
            result = subprocess.run(cmd, capture_output=capture_output, text=True, check=False)
            if not capture_output and result.returncode != 0:
                print(f"❌ Command failed: {' '.join(cmd)}")
            return result
        except Exception as e:
            print(f"❌ Error running command: {e}")
            return subprocess.CompletedProcess(cmd, 1, "", str(e))
    
    def _ensure_env_file(self) -> bool:
        """Create .env file if it doesn't exist"""
        if not self.env_file.exists():
            print("📝 Creating .env template...")
            template = '''# Telegram Bot Configuration
BOT_TOKEN="your_bot_token_here"
SYSTEM_NAME="telegram-bot"
TZ="UTC"
'''
            self.env_file.write_text(template)
            print("✅ Created .env template. Please update BOT_TOKEN!")
            return False
        return True
    
    def _ensure_directories(self):
        """Create necessary directories"""
        for dir_name in ["data", "logs"]:
            dir_path = self.project_root / dir_name
            dir_path.mkdir(exist_ok=True)
            
            # Create basic data files
            if dir_name == "data":
                for file_name in ["bot_users.json", "bot_admins.json"]:
                    file_path = dir_path / file_name
                    if not file_path.exists():
                        file_path.write_text("[]")
    
    def setup(self) -> bool:
        """Initial project setup"""
        print("🚀 Setting up Telegram Bot Framework...")
        
        # Create directories and files
        self._ensure_directories()
        
        # Create .env if needed
        if not self._ensure_env_file():
            return False
        
        print("✅ Setup completed!")
        print("\n📋 Next steps:")
        print("1. Edit .env file and set your BOT_TOKEN")
        print("2. Run: python manager.py start")
        return True
    
    def start(self) -> bool:
        """Start the bot"""
        print("🚀 Starting Telegram bot...")
        
        if not self.env_file.exists():
            print("❌ .env file not found. Run setup first!")
            return False
        
        # Check if Docker is available
        result = self._run_command(["docker", "--version"], capture_output=True)
        if result.returncode != 0:
            print("❌ Docker not found. Please install Docker first.")
            return False
        
        # Start with Docker Compose
        result = self._run_command(["docker-compose", "up", "-d", "--build"])
        if result.returncode == 0:
            print("✅ Bot started successfully!")
            print("📊 Check status: python manager.py status")
            print("📝 View logs: python manager.py logs")
            return True
        else:
            print("❌ Failed to start bot")
            return False
    
    def stop(self) -> bool:
        """Stop the bot"""
        print("🛑 Stopping Telegram bot...")
        result = self._run_command(["docker-compose", "down"])
        if result.returncode == 0:
            print("✅ Bot stopped successfully!")
            return True
        else:
            print("❌ Failed to stop bot")
            return False
    
    def restart(self) -> bool:
        """Restart the bot"""
        print("🔄 Restarting Telegram bot...")
        if self.stop() and self.start():
            return True
        return False
    
    def status(self) -> bool:
        """Show bot status"""
        print("📊 Bot Status:")
        print("=" * 40)
        
        # Check Docker Compose services
        result = self._run_command(["docker-compose", "ps"], capture_output=True)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print("❌ No services found or Docker Compose not available")
        
        # Check container health
        result = self._run_command(["docker", "ps", "--filter", f"name={self.system_name}"], capture_output=True)
        if result.returncode == 0 and self.system_name in result.stdout:
            print("\n✅ Bot container is running")
        else:
            print("\n❌ Bot container is not running")
        
        return True
    
    def logs(self, follow: bool = False) -> bool:
        """Show bot logs"""
        print("📝 Bot Logs:")
        print("=" * 40)
        
        cmd = ["docker-compose", "logs"]
        if follow:
            cmd.append("-f")
        
        result = self._run_command(cmd)
        return result.returncode == 0
    
    def clean(self) -> bool:
        """Clean up containers and images"""
        print("🧹 Cleaning up...")
        
        # Stop and remove containers
        self._run_command(["docker-compose", "down", "--rmi", "local", "--volumes"])
        
        # Clean up unused resources
        self._run_command(["docker", "system", "prune", "-f"])
        
        print("✅ Cleanup completed!")
        return True


def main():
    """Main CLI interface"""
    parser = argparse.ArgumentParser(
        description="Telegram Bot Framework Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python manager.py setup     # Initial project setup
  python manager.py start     # Start the bot
  python manager.py stop      # Stop the bot
  python manager.py status    # Show status
  python manager.py logs      # Show logs
  python manager.py logs -f   # Follow logs
  python manager.py restart   # Restart the bot
  python manager.py clean     # Clean up
        """
    )
    
    parser.add_argument(
        'action',
        choices=['setup', 'start', 'stop', 'restart', 'status', 'logs', 'clean'],
        help='Action to perform'
    )
    
    parser.add_argument(
        '-f', '--follow',
        action='store_true',
        help='Follow logs (only for logs action)'
    )
    
    args = parser.parse_args()
    
    # Create manager instance
    manager = BotManager()
    
    # Execute action
    action_map = {
        'setup': manager.setup,
        'start': manager.start,
        'stop': manager.stop,
        'restart': manager.restart,
        'status': manager.status,
        'logs': lambda: manager.logs(args.follow),
        'clean': manager.clean,
    }
    
    try:
        success = action_map[args.action]()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main() 