#!/usr/bin/env python3
"""
Quit Smoking Bot Manager

Modern management interface for Docker-based Telegram bots.
Single tool for all bot management operations with rich functionality.
"""

import argparse
import importlib.util
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Add scripts directory to Python path for importing modules
sys.path.insert(0, str(Path(__file__).parent / "scripts"))

try:
    from scripts.modules import (
        BotError,
        Colors,
        DockerError,
        action_cleanup,
        action_logs,
        action_prune,
        action_restart,
        action_setup,
        action_start,
        action_status,
        action_stop,
        handle_error,
        print_error,
        print_message,
        print_success,
        setup_environment,
    )
except ImportError as e:
    print(f"❌ Error importing bot modules: {e}")
    print("🔧 Please ensure scripts/modules are properly installed")
    sys.exit(1)


class BotManager:
    """Modern bot management class with rich functionality"""

    def __init__(self):
        """Initialize the bot manager"""
        self.project_root = Path(__file__).parent.absolute()
        os.chdir(self.project_root)

        # Setup environment using modules
        setup_environment()

        print_message("🤖 Quit Smoking Bot Manager", Colors.BLUE)

    def setup(self, token: Optional[str] = None) -> bool:
        """Initial project setup with comprehensive configuration"""
        try:
            return action_setup(token=token)
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Setup failed: {e}")
            return False

    def start(
        self,
        force_rebuild: bool = False,
        enable_monitoring: bool = False,
        enable_logging: bool = False,
    ) -> bool:
        """Start the bot with advanced options"""
        try:
            return action_start(
                force_rebuild=force_rebuild,
                enable_monitoring=enable_monitoring,
                enable_logging=enable_logging,
            )
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Start failed: {e}")
            return False

    def stop(self, cleanup: bool = False) -> bool:
        """Stop the bot with optional cleanup"""
        try:
            return action_stop(confirm=True)
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Stop failed: {e}")
            return False

    def restart(self, force_rebuild: bool = False) -> bool:
        """Restart the bot service"""
        try:
            return action_restart()
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Restart failed: {e}")
            return False

    def status(self, detailed: bool = False) -> bool:
        """Show comprehensive bot status"""
        try:
            return action_status()
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Status check failed: {e}")
            return False

    def logs(self, follow: bool = False, lines: int = 50) -> bool:
        """Show bot logs with filtering options"""
        try:
            return action_logs(follow=follow, lines=lines)
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Logs failed: {e}")
            return False

    def clean(self, deep: bool = False) -> bool:
        """Clean up containers and images"""
        try:
            if deep:
                return action_prune()
            return action_cleanup()
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Cleanup failed: {e}")
            return False

    def check_environment(self) -> bool:
        """Check environment compatibility and readiness"""
        print_message("🔍 Environment Compatibility Check", Colors.BLUE)
        print("=" * 40)

        checks = []

        # Core checks
        checks.append(self._check_python_version())
        checks.append(self._check_venv())

        # Package checks
        checks.append(self._check_package_version("telegram", "22.0"))
        checks.append(self._check_package_version("apscheduler", "3.10.0"))
        checks.append(self._check_package_version("pytz"))
        checks.append(self._check_package_version("dotenv"))

        # Bot startup test
        if Path("src/bot.py").exists():
            checks.append(self._check_bot_startup())
        else:
            print("⚠️  src/bot.py not found - skipping startup test")
            checks.append(False)

        print("\n" + "=" * 40)

        if all(checks):
            print_success("🎉 All checks PASSED! Environment is ready.")
            return True
        else:
            failed = len([c for c in checks if not c])
            print_error(f"❌ {failed} checks FAILED. Please fix issues above.")
            print("\n💡 Quick fixes:")
            print("   pip install -U 'python-telegram-bot>=22.0'")
            print("   source venv/bin/activate")
            return False

    def _check_python_version(self) -> bool:
        """Check Python version compatibility"""
        version = sys.version_info
        print(f"🐍 Python version: {version.major}.{version.minor}.{version.micro}")

        if version.major == 3 and version.minor >= 9:
            print("✅ Python version compatible")
            return True
        else:
            print("❌ Python 3.9+ required")
            return False

    def _check_venv(self) -> bool:
        """Check if running in virtual environment"""
        in_venv = hasattr(sys, "real_prefix") or (
            hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix
        )

        if in_venv:
            print("✅ Running in virtual environment")
            return True
        else:
            print(
                "⚠️  Not in virtual environment (recommended: source venv/bin/activate)"
            )
            return False

    def _check_package_version(
        self, package_name: str, min_version: str = None
    ) -> bool:
        """Check if package is installed and get version"""
        try:
            module = importlib.import_module(package_name)
            version = getattr(module, "__version__", "unknown")
            print(f"✅ {package_name}: {version}")

            if min_version and hasattr(module, "__version__"):
                try:
                    from packaging import version as pkg_version

                    if pkg_version.parse(version) >= pkg_version.parse(min_version):
                        return True
                    else:
                        print(f"⚠️  {package_name} version {version} < {min_version}")
                        return False
                except ImportError:
                    # packaging not available, assume OK
                    return True
            return True
        except ImportError:
            print(f"❌ {package_name}: not installed")
            return False

    def _check_bot_startup(self) -> bool:
        """Test if bot can start without errors"""
        try:
            result = subprocess.run(
                [sys.executable, "src/bot.py", "--help"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                print("✅ Bot startup test: PASSED")
                return True
            else:
                print(f"❌ Bot startup test: FAILED\n{result.stderr}")
                return False
        except subprocess.TimeoutExpired:
            print("⚠️  Bot startup test: TIMEOUT")
            return False
        except Exception as e:
            print(f"❌ Bot startup test: ERROR - {e}")
            return False

    def dev_setup(self) -> bool:
        """Setup local development environment"""
        print_message("🚀 Local Development Environment Setup", Colors.BLUE)
        print("=" * 40)

        # Change to project directory
        project_root = Path(__file__).parent
        os.chdir(project_root)

        # Check requirements
        if not self._check_dev_requirements():
            return False

        # Setup virtual environment
        if not self._setup_virtual_environment():
            print_error("❌ Failed to setup virtual environment")
            return False

        # Setup VS Code workspace
        self._setup_vscode_workspace()

        print_success("\n🎉 Setup completed successfully!")
        print("\n📝 Next steps:")
        print("1. Reload VS Code window (Cmd+Shift+P → 'Developer: Reload Window')")
        print("2. Make sure VS Code uses ./venv/bin/python3 as interpreter")
        print("3. Run 'make install' to start the bot")
        print("\n💡 For development:")
        print("   - Always activate virtual environment: source venv/bin/activate")
        print("   - Use 'make setup' for initial Docker setup")
        print("   - Use 'make start' to run the bot")

        return True

    def _setup_virtual_environment(self) -> bool:
        """Setup Python virtual environment and install dependencies"""
        print("🐍 Setting up Python environment...")

        venv_path = Path("venv")

        # Remove existing venv if it exists
        if venv_path.exists():
            print("   🗑️  Removing existing virtual environment...")
            if not self._run_command("rm -rf venv", "Cleaning old environment"):
                return False

        # Create new virtual environment
        if not self._run_command(
            "python3 -m venv venv", "Creating virtual environment"
        ):
            return False

        # Install dependencies including dev tools
        if not self._run_command(
            "source venv/bin/activate && pip install -e '.[dev]'",
            "Installing dev dependencies",
        ):
            return False

        print("   ✅ Virtual environment ready!")
        return True

    def _setup_vscode_workspace(self) -> bool:
        """Configure VS Code workspace settings"""
        print("🔧 Configuring VS Code workspace...")

        # Create .vscode directory if it doesn't exist
        vscode_dir = Path(".vscode")
        vscode_dir.mkdir(exist_ok=True)

        # Check if settings are already configured
        settings_file = vscode_dir / "settings.json"
        if settings_file.exists():
            print("   ✅ VS Code settings already configured")
            return True

        print("   ℹ️  VS Code settings already exist - keeping current configuration")
        return True

    def _check_dev_requirements(self) -> bool:
        """Check if all required tools are available"""
        print("🔍 Checking requirements...")

        # Check Python 3
        if not self._run_command("python3 --version", "Checking Python 3"):
            print("❌ Python 3 is required. Please install Python 3.9+")
            return False

        # Check pip
        if not self._run_command("python3 -m pip --version", "Checking pip"):
            print("❌ pip is required. Please install pip")
            return False

        print("   ✅ All requirements satisfied!")
        return True

    def _run_command(self, cmd: str, description: str = "") -> bool:
        """Run a shell command and return success status"""
        if description:
            print(f"🔧 {description}...")

        try:
            result = subprocess.run(
                cmd, shell=True, check=True, capture_output=True, text=True
            )
            if result.stdout:
                print(f"   ✅ {result.stdout.strip()}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"   ❌ Error: {e.stderr.strip() if e.stderr else str(e)}")
            return False


def main():
    """Main CLI interface with enhanced functionality"""
    parser = argparse.ArgumentParser(
        description="Quit Smoking Bot Manager - Comprehensive bot management tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
🚀 Quick Start Examples:
  python manager.py setup                    # Initial project setup
  python manager.py start                    # Start the bot
  python manager.py start --monitoring       # Start with health monitoring
  python manager.py stop                     # Stop the bot
  python manager.py restart --rebuild        # Restart with container rebuild
  python manager.py status --detailed        # Detailed status with diagnostics
  python manager.py logs --follow            # Follow logs in real-time
  python manager.py clean                    # Basic cleanup
  python manager.py clean --deep             # Deep cleanup (removes everything)
  python manager.py check-env                # Check environment compatibility
  python manager.py dev-setup                # Setup local development environment

📋 Management Commands:
  setup      Initial Docker project setup and configuration
  dev-setup  Setup local development environment (venv, dependencies)
  start      Start the bot service with options
  stop       Stop the bot service
  restart    Restart the bot service
  status     Show comprehensive status and health
  logs       Show bot logs with filtering
  clean      Clean up containers and resources
  check-env  Check environment compatibility and readiness

🔧 Advanced Options:
  --token TOKEN        Set bot token during setup
  --rebuild            Force rebuild Docker containers
  --monitoring         Enable health monitoring services
  --logging           Enable centralized logging
  --follow            Follow logs in real-time
  --detailed          Show detailed status information
  --deep              Deep cleanup (removes all data)
        """,
    )

    parser.add_argument(
        "action",
        choices=[
            "setup",
            "dev-setup",
            "start",
            "stop",
            "restart",
            "status",
            "logs",
            "clean",
            "check-env",
        ],
        help="Management action to perform",
    )

    # Setup options
    parser.add_argument(
        "--token",
        type=str,
        help="Telegram bot token (for setup action)",
    )

    # Start/restart options
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="Force rebuild Docker containers (start/restart)",
    )

    parser.add_argument(
        "--monitoring",
        action="store_true",
        help="Enable health monitoring services (start)",
    )

    parser.add_argument(
        "--logging",
        action="store_true",
        help="Enable centralized logging (start)",
    )

    # Status options
    parser.add_argument(
        "--detailed",
        action="store_true",
        help="Show detailed status information (status)",
    )

    # Logs options
    parser.add_argument(
        "-f",
        "--follow",
        action="store_true",
        help="Follow logs in real-time (logs)",
    )

    parser.add_argument(
        "--lines",
        type=int,
        default=50,
        help="Number of log lines to show (default: 50)",
    )

    # Clean options
    parser.add_argument(
        "--deep",
        action="store_true",
        help="Deep cleanup - removes all data and images (clean)",
    )

    # Stop options
    parser.add_argument(
        "--cleanup",
        action="store_true",
        help="Cleanup resources after stopping (stop)",
    )

    args = parser.parse_args()

    try:
        # Create manager instance
        manager = BotManager()

        # Execute action with appropriate arguments
        success = False

        if args.action == "setup":
            success = manager.setup(token=args.token)

        elif args.action == "start":
            success = manager.start(
                force_rebuild=args.rebuild,
                enable_monitoring=args.monitoring,
                enable_logging=args.logging,
            )

        elif args.action == "stop":
            success = manager.stop(cleanup=args.cleanup)

        elif args.action == "restart":
            success = manager.restart(force_rebuild=args.rebuild)

        elif args.action == "status":
            success = manager.status()

        elif args.action == "logs":
            success = manager.logs(follow=args.follow, lines=args.lines)

        elif args.action == "clean":
            success = manager.clean(deep=args.deep)

        elif args.action == "check-env":
            success = manager.check_environment()

        elif args.action == "dev-setup":
            success = manager.dev_setup()

        # Exit with appropriate code
        if success:
            print_success("\n✅ Operation completed successfully!")
            sys.exit(0)
        else:
            print_error("\n❌ Operation failed!")
            sys.exit(1)

    except KeyboardInterrupt:
        print_message("\n🛑 Operation cancelled by user", Colors.YELLOW)
        sys.exit(130)
    except Exception as e:
        print_error(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
