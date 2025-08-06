#!/usr/bin/env python3
"""
Telegram Bot Framework Manager

Modern management interface for Docker-based Telegram bots.
Single tool for all bot management operations with rich functionality.
"""

import os
import sys
import argparse
from pathlib import Path
from typing import Optional

# Add scripts directory to Python path for importing modules
sys.path.insert(0, str(Path(__file__).parent / "scripts"))

try:
    from modules import (
        action_setup, action_start, action_stop, action_restart,
        action_status, action_logs, action_cleanup, action_prune,
        print_message, print_success, print_error, Colors,
        setup_environment, BotError, DockerError, handle_error
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
    
    def start(self, force_rebuild: bool = False, enable_monitoring: bool = False, 
              enable_logging: bool = False, env: str = "prod") -> bool:
        """Start the bot with advanced options"""
        try:
            return action_start(
                profile=env,
                force_rebuild=force_rebuild,
                enable_monitoring=enable_monitoring,
                enable_logging=enable_logging
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
            return action_restart(profile="prod")
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
            else:
                return action_cleanup()
        except (BotError, DockerError) as e:
            handle_error(e)
            return False
        except Exception as e:
            print_error(f"Cleanup failed: {e}")
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

📋 Management Commands:
  setup      Initial project setup and configuration
  start      Start the bot service with options
  stop       Stop the bot service  
  restart    Restart the bot service
  status     Show comprehensive status and health
  logs       Show bot logs with filtering
  clean      Clean up containers and resources

🔧 Advanced Options:
  --token TOKEN        Set bot token during setup
  --rebuild            Force rebuild Docker containers
  --monitoring         Enable health monitoring services
  --logging           Enable centralized logging
  --follow            Follow logs in real-time
  --detailed          Show detailed status information
  --deep              Deep cleanup (removes all data)
        """
    )
    
    parser.add_argument(
        'action',
        choices=['setup', 'start', 'stop', 'restart', 'status', 'logs', 'clean'],
        help='Management action to perform'
    )
    
    # Setup options
    parser.add_argument(
        '--token',
        type=str,
        help='Telegram bot token (for setup action)'
    )
    
    # Start/restart options
    parser.add_argument(
        '--rebuild',
        action='store_true',
        help='Force rebuild Docker containers (start/restart)'
    )
    
    parser.add_argument(
        '--monitoring',
        action='store_true',
        help='Enable health monitoring services (start)'
    )
    
    parser.add_argument(
        '--logging',
        action='store_true',
        help='Enable centralized logging (start)'
    )
    
    parser.add_argument(
        '--env',
        type=str,
        choices=['dev', 'prod'],
        default='prod',
        help='Deployment environment (dev/prod)'
    )
    
    # Status options
    parser.add_argument(
        '--detailed',
        action='store_true',
        help='Show detailed status information (status)'
    )
    
    # Logs options
    parser.add_argument(
        '-f', '--follow',
        action='store_true',
        help='Follow logs in real-time (logs)'
    )
    
    parser.add_argument(
        '--lines',
        type=int,
        default=50,
        help='Number of log lines to show (default: 50)'
    )
    
    # Clean options
    parser.add_argument(
        '--deep',
        action='store_true',
        help='Deep cleanup - removes all data and images (clean)'
    )
    
    # Stop options
    parser.add_argument(
        '--cleanup',
        action='store_true',
        help='Cleanup resources after stopping (stop)'
    )
    
    args = parser.parse_args()
    
    try:
        # Create manager instance
        manager = BotManager()
        
        # Execute action with appropriate arguments
        success = False
        
        if args.action == 'setup':
            success = manager.setup(token=args.token)
            
        elif args.action == 'start':
            success = manager.start(
                force_rebuild=args.rebuild,
                enable_monitoring=args.monitoring,
                enable_logging=args.logging,
                env=args.env
            )
            
        elif args.action == 'stop':
            success = manager.stop(cleanup=args.cleanup)
            
        elif args.action == 'restart':
            success = manager.restart(force_rebuild=args.rebuild)
            
        elif args.action == 'status':
            success = manager.status()
            
        elif args.action == 'logs':
            success = manager.logs(follow=args.follow, lines=args.lines)
            
        elif args.action == 'clean':
            success = manager.clean(deep=args.deep)
            
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