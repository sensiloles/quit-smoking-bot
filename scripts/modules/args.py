"""
args.py - Argument parsing utilities

This module provides argument parsers for various script operations.
"""

import argparse
import os
import getpass
import re
from typing import Optional

from .output import print_message, print_error, print_warning, Colors
from .errors import ConfigError


def validate_token(token: str) -> bool:
    """Validate Telegram bot token format"""
    if not token:
        return False
    
    # Telegram bot token format: bot{id}:{token}
    # Example: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
    pattern = r'^\d{8,10}:[A-Za-z0-9_-]{35}$'
    return bool(re.match(pattern, token))


def prompt_for_token() -> str:
    """Prompt user for Telegram bot token"""
    print_message("\n🔑 Telegram Bot Token Setup", Colors.BLUE)
    print_message("Please enter your Telegram bot token from @BotFather", Colors.YELLOW)
    print_message("Format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz", Colors.CYAN)
    
    while True:
        token = getpass.getpass("Bot Token: ").strip()
        
        if not token:
            print_error("Token cannot be empty. Please try again.")
            continue
        
        if validate_token(token):
            return token
        else:
            print_error("Invalid token format. Please check and try again.")
            print_message("Token should be in format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz", Colors.YELLOW)


def create_run_parser() -> argparse.ArgumentParser:
    """Create argument parser for run script"""
    parser = argparse.ArgumentParser(
        description="Bot management script - start, install, or manage the bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --install               # Install and start bot
  %(prog)s --start                 # Start existing bot
  %(prog)s --status                # Check bot status
  %(prog)s --logs                  # Show bot logs
  %(prog)s --restart               # Restart bot
  %(prog)s --stop                  # Stop bot
  %(prog)s --prune                 # Remove all bot data and containers
  %(prog)s --dry-run --install     # Preview installation steps
        """
    )
    
    # Action arguments
    action_group = parser.add_mutually_exclusive_group()
    action_group.add_argument('--install', action='store_true',
                             help='Install and start the bot with full setup')
    action_group.add_argument('--start', action='store_true',
                             help='Start the bot service')
    action_group.add_argument('--stop', action='store_true',
                             help='Stop the bot service')
    action_group.add_argument('--restart', action='store_true',
                             help='Restart the bot service')
    action_group.add_argument('--status', action='store_true',
                             help='Show bot status and health')
    action_group.add_argument('--logs', action='store_true',
                             help='Show bot logs')
    action_group.add_argument('--prune', action='store_true',
                             help='Remove all bot data, logs, and containers')
    
    # Configuration arguments
    parser.add_argument('--token', type=str,
                       help='Telegram bot token (can also use BOT_TOKEN env var)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview actions without executing them')
    parser.add_argument('--force-rebuild', action='store_true',
                       help='Force rebuild of Docker containers')
    parser.add_argument('--enable-monitoring', action='store_true',
                       help='Enable health monitoring services')
    parser.add_argument('--enable-logging', action='store_true',
                       help='Enable centralized logging')
    
    # Debugging
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug mode')
    
    return parser


def create_health_parser() -> argparse.ArgumentParser:
    """Create argument parser for health monitoring script"""
    parser = argparse.ArgumentParser(
        description="Health monitoring for the quit-smoking bot",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--check-interval', type=int, default=30,
                       help='Health check interval in seconds (default: 30)')
    parser.add_argument('--max-failures', type=int, default=3,
                       help='Maximum consecutive failures before restart (default: 3)')
    parser.add_argument('--restart-cooldown', type=int, default=300,
                       help='Cooldown period between restarts in seconds (default: 300)')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                       default='INFO', help='Logging level (default: INFO)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Run in dry-run mode (no actual actions)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    
    return parser


def create_check_service_parser() -> argparse.ArgumentParser:
    """Create argument parser for service checking script"""
    parser = argparse.ArgumentParser(
        description="Check service status and health",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--service', type=str, choices=['bot', 'monitor', 'all'],
                       default='all', help='Service to check (default: all)')
    parser.add_argument('--detailed', action='store_true',
                       help='Show detailed status information')
    parser.add_argument('--json', action='store_true',
                       help='Output results in JSON format')
    parser.add_argument('--timeout', type=int, default=10,
                       help='Timeout for checks in seconds (default: 10)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    
    return parser


def create_bootstrap_parser() -> argparse.ArgumentParser:
    """Create argument parser for bootstrap script"""
    parser = argparse.ArgumentParser(
        description="Bootstrap the bot environment and dependencies",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--skip-docker', action='store_true',
                       help='Skip Docker installation check')
    parser.add_argument('--skip-permissions', action='store_true',
                       help='Skip permission setup')
    parser.add_argument('--force', action='store_true',
                       help='Force bootstrap even if already initialized')
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview bootstrap actions')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    
    return parser


def create_stop_parser() -> argparse.ArgumentParser:
    """Create argument parser for stop script"""
    parser = argparse.ArgumentParser(
        description="Stop bot services gracefully",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--force', action='store_true',
                       help='Force stop services (kill containers)')
    parser.add_argument('--cleanup', action='store_true',
                       help='Remove containers and networks after stopping')
    parser.add_argument('--timeout', type=int, default=30,
                       help='Timeout for graceful shutdown in seconds (default: 30)')
    parser.add_argument('--service', type=str, choices=['bot', 'monitor', 'all'],
                       default='all', help='Service to stop (default: all)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview stop actions')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    
    return parser


def parse_and_setup_args(parser: argparse.ArgumentParser) -> argparse.Namespace:
    """Parse arguments and setup environment variables"""
    args = parser.parse_args()
    
    # Load .env file first to get environment variables
    from .environment import load_env
    load_env()
    
    # Setup debug/verbose mode
    if hasattr(args, 'debug') and args.debug:
        os.environ['DEBUG'] = '1'
    if hasattr(args, 'verbose') and args.verbose:
        os.environ['VERBOSE'] = '1'
    
    # Setup dry-run mode
    if hasattr(args, 'dry_run') and args.dry_run:
        os.environ['DRY_RUN'] = '1'
    
    # Handle token setup for run script
    if hasattr(args, 'token') and parser.prog and 'run' in parser.prog:
        if args.token:
            if not validate_token(args.token):
                raise ConfigError("Invalid token format provided")
            os.environ['BOT_TOKEN'] = args.token
        else:
            # Check for existing token in environment
            existing_token = os.getenv('BOT_TOKEN')
            if not existing_token and hasattr(args, 'install') and args.install:
                # Only prompt for token if we're doing install and no token exists
                token = prompt_for_token()
                os.environ['BOT_TOKEN'] = token
    
    return args 