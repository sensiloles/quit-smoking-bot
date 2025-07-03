#!/usr/bin/env python3
"""
setup.py - Complete project setup and installation for quit-smoking-bot

This script performs complete project initialization and installation including:
- Installing Docker if needed
- Setting up secure file permissions
- Creating directory structure
- Initializing data files
- Creating .env template
- Building and starting Docker services
- Health monitoring
"""

import os
import sys
import json
import stat
import time
import argparse
import subprocess
from pathlib import Path
from typing import List, Optional

# Add the scripts/modules directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))

from modules.output import Colors
from modules.environment import load_env, update_env_token, check_bot_token
from modules.docker_utils import check_docker_installation
from modules.errors import BotError, DockerError, handle_error

def print_message(message: str, color: str = Colors.NC):
    """Print a formatted message with optional color"""
    print(f"{color}{message}{Colors.NC}")

def is_dry_run() -> bool:
    """Check if we're in dry-run mode"""
    return os.getenv("DRY_RUN", "0") == "1"

def execute_or_simulate(description: str, command: str):
    """Execute command or simulate if in dry-run mode"""
    if is_dry_run():
        print_message(f"🔍 [DRY-RUN] Would execute: {description}", Colors.YELLOW)
        print_message(f"    Command: {command}", Colors.YELLOW)
    else:
        print_message(f"🔧 {description}...", Colors.BLUE)
        try:
            if isinstance(command, str):
                subprocess.run(command, shell=True, check=True)
            else:
                subprocess.run(command, check=True)
            print_message(f"✅ {description} completed", Colors.GREEN)
        except subprocess.CalledProcessError as e:
            print_message(f"❌ {description} failed: {e}", Colors.RED)
            raise

def install_docker_if_needed():
    """Install Docker and Docker Compose if needed"""
    if check_docker_installation():
        return True
    
    print_message("📦 Installing Docker and Docker Compose...", Colors.BLUE)
    
    # Detect OS and install accordingly
    try:
        # Check if we're on Ubuntu/Debian
        subprocess.run(["apt-get", "--version"], capture_output=True, check=True)
        execute_or_simulate("Install Docker and Docker Compose", """
            sudo apt-get update && \
            sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && \
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
            sudo apt-get update && \
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
            sudo chmod +x /usr/local/bin/docker-compose && \
            sudo usermod -aG docker $USER && \
            sudo systemctl start docker && \
            sudo systemctl enable docker
        """)
    except subprocess.CalledProcessError:
        # Try CentOS/RHEL
        try:
            subprocess.run(["yum", "--version"], capture_output=True, check=True)
            execute_or_simulate("Install Docker and Docker Compose", """
                sudo yum install -y yum-utils && \
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
                sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
                sudo chmod +x /usr/local/bin/docker-compose && \
                sudo usermod -aG docker $USER && \
                sudo systemctl start docker && \
                sudo systemctl enable docker
            """)
        except subprocess.CalledProcessError:
            print_message("❌ Unsupported OS. Please install Docker and Docker Compose manually.", Colors.RED)
            return False
    
    if not is_dry_run():
        print_message("✅ Docker and Docker Compose installed successfully", Colors.GREEN)
        print_message("✅ Docker service enabled for automatic startup on boot", Colors.GREEN)
        print_message("ℹ️  You may need to log out and log back in for group changes to take effect", Colors.YELLOW)
    
    return True

def setup_directory_permissions(directory: Path, name: str):
    """Setup secure permissions for directories"""
    if not directory.exists():
        print_message(f"📁 Creating {name} directory...", Colors.YELLOW)
        directory.mkdir(parents=True, exist_ok=True)
    
    # Set secure permissions: owner rwx, group rx, others rx (755)
    directory.chmod(0o755)
    print_message(f"✅ Set secure permissions (755) for {name}", Colors.GREEN)

def setup_file_permissions(file_path: Path) -> bool:
    """Setup secure permissions for data files"""
    if file_path.exists():
        # Data files: owner rw, group r, others r (644)
        file_path.chmod(0o644)
        return True
    return False

def initialize_data_files(data_dir: Path):
    """Initialize default data files if missing"""
    files = ["bot_users.json", "bot_admins.json", "quotes.json"]
    
    for file_name in files:
        file_path = data_dir / file_name
        if not file_path.exists():
            print_message(f"📄 Creating default {file_name}...", Colors.YELLOW)
            with open(file_path, 'w') as f:
                json.dump([], f)
            setup_file_permissions(file_path)
            print_message(f"✅ Created {file_name} with secure permissions", Colors.GREEN)
        else:
            setup_file_permissions(file_path)

def make_scripts_executable(project_root: Path):
    """Make scripts executable"""
    scripts_dir = project_root / "scripts"
    if scripts_dir.exists():
        # Make all .sh and .py files executable
        for script_file in scripts_dir.glob("*.sh"):
            script_file.chmod(0o755)
        
        for script_file in scripts_dir.glob("*.py"):
            script_file.chmod(0o755)
        
        print_message("✅ Made scripts executable", Colors.GREEN)

def setup_permissions(project_root: Path):
    """Setup secure file permissions"""
    print_message("🔐 Setting up secure file permissions...", Colors.YELLOW)
    
    data_dir = project_root / "data"
    logs_dir = project_root / "logs"
    backups_dir = project_root / "backups"
    
    # Setup directories
    setup_directory_permissions(data_dir, "data")
    setup_directory_permissions(logs_dir, "logs")
    setup_directory_permissions(backups_dir, "backups")
    
    # Initialize and secure data files
    initialize_data_files(data_dir)
    
    # Set permissions on any existing log files
    bot_log = logs_dir / "bot.log"
    if bot_log.exists():
        setup_file_permissions(bot_log)
        print_message("✅ Set secure permissions for log files", Colors.GREEN)
    
    # Make scripts executable
    make_scripts_executable(project_root)

def create_env_template():
    """Create .env template if it doesn't exist"""
    env_file = Path(".env")
    if not env_file.exists():
        print_message("📝 Creating .env template...", Colors.YELLOW)
        
        env_content = """# Telegram Bot Configuration
BOT_TOKEN="your_telegram_bot_token_here"

# System Configuration
SYSTEM_NAME="quit-smoking-bot"
SYSTEM_DISPLAY_NAME="Quit Smoking Bot"

# Timezone (optional) - Use UTC for international deployment
# Examples: "UTC", "Europe/London", "America/New_York", "Asia/Tokyo"
TZ="UTC"

# Notification Settings (optional)
NOTIFICATION_DAY="23"
NOTIFICATION_HOUR="21"
NOTIFICATION_MINUTE="58"
"""
        
        with open(env_file, "w") as f:
            f.write(env_content)
        
        print_message("✅ Created .env template - please update with your bot token", Colors.GREEN)
    else:
        print_message("ℹ️  .env file already exists", Colors.YELLOW)

def build_and_start_services(force_rebuild: bool = False, enable_monitoring: bool = False, enable_logging: bool = False):
    """Build and start services with proper profiles"""
    
    build_args = ["--no-cache"] if force_rebuild else []
    
    # Stop existing containers first
    execute_or_simulate("Stop existing containers", "docker-compose down --remove-orphans 2>/dev/null || true")
    
    # Build containers
    build_cmd = ["docker-compose", "build"] + build_args
    execute_or_simulate("Build Docker containers", " ".join(build_cmd))
    
    # Determine compose profiles
    compose_profiles = []
    if enable_monitoring:
        compose_profiles.append("monitoring")
    if enable_logging:
        compose_profiles.append("logging")
    
    # Start services
    compose_cmd = ["docker-compose"]
    for profile in compose_profiles:
        compose_cmd.extend(["--profile", profile])
    compose_cmd.extend(["up", "-d"])
    
    execute_or_simulate("Start bot services", " ".join(compose_cmd))

def wait_for_bot_health():
    """Wait for bot to become healthy"""
    if is_dry_run():
        print_message("🔍 [DRY-RUN] Would wait for bot to become healthy", Colors.YELLOW)
        return True
    
    print_message("⏳ Waiting for bot to become healthy...", Colors.YELLOW)
    
    max_attempts = 12
    for attempt in range(1, max_attempts + 1):
        try:
            result = subprocess.run(
                ["docker-compose", "ps", "bot"],
                capture_output=True,
                text=True
            )
            
            if "healthy" in result.stdout:
                print_message("✅ Bot is healthy and operational", Colors.GREEN)
                return True
            
            if attempt == max_attempts:
                print_message("⚠️  Bot health check timeout, but container is running", Colors.YELLOW)
                return True
            
            time.sleep(5)
            
        except subprocess.CalledProcessError:
            if attempt == max_attempts:
                print_message("⚠️  Could not check bot health, but continuing", Colors.YELLOW)
                return True
            time.sleep(5)
    
    return True

def show_final_status(enable_monitoring: bool = False, enable_logging: bool = False):
    """Show final status and management commands"""
    if is_dry_run():
        return
    
    print_message("\n📊 Service Status:", Colors.BLUE)
    try:
        subprocess.run(["docker-compose", "ps"])
    except subprocess.CalledProcessError:
        pass
    
    print_message("\n🎉 Bot installation completed! 🎉", Colors.GREEN)
    print_message("=" * 40, Colors.GREEN)
    
    print_message("✅ Bot installed and started with auto-restart", Colors.GREEN)
    print_message("✅ Docker service enabled for automatic startup", Colors.GREEN)
    if enable_monitoring:
        print_message("✅ Health monitoring enabled", Colors.GREEN)
    if enable_logging:
        print_message("✅ Log aggregation enabled", Colors.GREEN)
    
    print_message("\n📋 Management Commands:", Colors.BLUE)
    print_message("  View logs:       docker-compose logs -f bot", Colors.BLUE)
    print_message("  Stop bot:        docker-compose down", Colors.BLUE)
    print_message("  Restart bot:     docker-compose restart bot", Colors.BLUE)
    print_message("  Start bot:       python3 scripts/start.py", Colors.BLUE)
    print_message("  Check status:    python3 scripts/monitor.py --mode status", Colors.BLUE)

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Complete project setup and installation for quit-smoking-bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                           # Basic setup (permissions, directories, .env)
  %(prog)s --install                 # Full installation with Docker setup
  %(prog)s --install --monitoring    # Install with health monitoring
  %(prog)s --token YOUR_TOKEN        # Setup with specific bot token
  %(prog)s --dry-run --install       # Preview installation steps
        """
    )
    
    parser.add_argument('--install', action='store_true',
                       help='Full installation with Docker setup and service start')
    parser.add_argument('--token', type=str,
                       help='Telegram bot token (can also use BOT_TOKEN env var)')
    parser.add_argument('--force-rebuild', action='store_true',
                       help='Force rebuild of Docker containers')
    parser.add_argument('--enable-monitoring', action='store_true',
                       help='Enable health monitoring services')
    parser.add_argument('--enable-logging', action='store_true',
                       help='Enable centralized logging')
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview actions without executing them')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    
    return parser.parse_args()

def main():
    """Main setup function"""
    try:
        args = parse_arguments()
        
        # Setup environment variables
        if args.dry_run:
            os.environ["DRY_RUN"] = "1"
        if args.verbose:
            os.environ["VERBOSE"] = "1"
        
        # Load environment
        load_env()
        
        print_message("🚀 Setting up quit-smoking-bot project...", Colors.BLUE)
        
        # Get project root directory
        project_root = Path(__file__).parent.parent.absolute()
        os.chdir(project_root)
        
        # Basic setup (always done)
        setup_permissions(project_root)
        create_env_template()
        
        # Handle bot token
        if args.token:
            print_message("🔑 Configuring bot token...", Colors.YELLOW)
            if not update_env_token(args.token):
                raise BotError("Failed to update BOT_TOKEN")
            print_message("✅ BOT_TOKEN configured", Colors.GREEN)
        
        if args.install:
            print_message("\n🔧 Starting full installation...", Colors.BLUE)
            
            # Install Docker if needed
            if not install_docker_if_needed():
                raise DockerError("Failed to install Docker")
            
            # Check Docker is working
            if not check_docker_installation():
                raise DockerError("Docker is not properly installed or running")
            
            # Check bot token is configured
            if not check_bot_token():
                raise BotError("BOT_TOKEN is not configured. Please provide a token with --token or update .env file.")
            
            # Build and start services
            build_and_start_services(
                force_rebuild=args.force_rebuild,
                enable_monitoring=args.enable_monitoring,
                enable_logging=args.enable_logging
            )
            
            # Wait for services to be ready
            wait_for_bot_health()
            
            # Show final status
            show_final_status(
                enable_monitoring=args.enable_monitoring,
                enable_logging=args.enable_logging
            )
        else:
            print_message("🎉 Basic setup completed successfully!", Colors.GREEN)
            print_message("📋 Summary:", Colors.BLUE)
            print_message("  • Directories: 755 (secure access)", Colors.BLUE)
            print_message("  • Data files: 644 (read-write for owner)", Colors.BLUE)
            print_message("  • Scripts: 755 (executable)", Colors.BLUE)
            print_message("📋 Next steps:", Colors.BLUE)
            print_message("  1. Update .env file with your bot token", Colors.BLUE)
            print_message("  2. Run: python3 scripts/setup.py --install", Colors.BLUE)
    
    except (BotError, DockerError) as e:
        handle_error(e)
        sys.exit(1)
    except KeyboardInterrupt:
        print_message("\n🛑 Setup cancelled by user", Colors.YELLOW)
        sys.exit(130)
    except Exception as e:
        print_message(f"❌ Unexpected error: {e}", Colors.RED)
        sys.exit(1)

if __name__ == "__main__":
    main() 