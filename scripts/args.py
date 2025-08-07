"""
args.py - Argument parsing utilities

This module provides argument parsers for various script operations.
"""

import argparse
import getpass
import os
import re

from .errors import ConfigError
from .output import Colors, print_error, print_message


def validate_token(token: str) -> bool:
    """Validate Telegram bot token format"""
    if not token:
        return False

    # Telegram bot token format: bot{id}:{token}
    # Example: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
    pattern = r"^\d{8,10}:[A-Za-z0-9_-]{35}$"
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
        print_error("Invalid token format. Please check and try again.")
        print_message(
            "Token should be in format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz",
            Colors.YELLOW,
        )


def create_health_parser() -> argparse.ArgumentParser:
    """Create argument parser for health monitoring script"""
    parser = argparse.ArgumentParser(
        description="Health monitoring for the quit-smoking bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--mode",
        choices=["docker", "diagnostics", "status"],
        default="status",
        help="Monitoring mode (default: status)",
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=30,
        help="Check interval in seconds for health check mode (default: 30)",
    )
    parser.add_argument(
        "--continuous",
        action="store_true",
        help="Run continuous monitoring (monitor mode only)",
    )
    parser.add_argument(
        "--check-interval",
        type=int,
        default=30,
        help="Health check interval in seconds (default: 30)",
    )
    parser.add_argument(
        "--max-failures",
        type=int,
        default=3,
        help="Maximum consecutive failures before restart (default: 3)",
    )
    parser.add_argument(
        "--restart-cooldown",
        type=int,
        default=300,
        help="Cooldown period between restarts in seconds (default: 300)",
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Logging level (default: INFO)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run in dry-run mode (no actual actions)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )

    return parser


def parse_and_setup_args(parser: argparse.ArgumentParser) -> argparse.Namespace:
    """Parse arguments and setup environment variables"""
    args = parser.parse_args()

    # Load .env file first to get environment variables
    from .environment import load_env

    load_env()

    # Setup debug/verbose mode
    if hasattr(args, "debug") and args.debug:
        os.environ["DEBUG"] = "1"
    if hasattr(args, "verbose") and args.verbose:
        os.environ["VERBOSE"] = "1"

    # Setup dry-run mode
    if hasattr(args, "dry_run") and args.dry_run:
        os.environ["DRY_RUN"] = "1"

    # Handle token setup for run script
    if hasattr(args, "token") and parser.prog and "run" in parser.prog:
        if args.token:
            if not validate_token(args.token):
                raise ConfigError("Invalid token format provided")
            os.environ["BOT_TOKEN"] = args.token
        else:
            # Check for existing token in environment
            existing_token = os.getenv("BOT_TOKEN")
            if not existing_token and hasattr(args, "install") and args.install:
                # Only prompt for token if we're doing install and no token exists
                token = prompt_for_token()
                os.environ["BOT_TOKEN"] = token

    return args
