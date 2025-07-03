#!/usr/bin/env python3
"""
start.py - Universal bot start script

This script manages the running bot services - start, stop, restart, status, logs.
For initial installation use setup.py --install instead.
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path

# Add scripts directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from modules import (
    action_start, action_stop, action_restart, action_status, action_logs,
    action_prune,
    print_message, debug_print, Colors, print_success, print_error,
    is_dry_run, handle_error, BotError, DockerError
)

def create_start_parser() -> argparse.ArgumentParser:
    """Create argument parser for start script"""
    parser = argparse.ArgumentParser(
        description="Bot management script - start, stop, restart, or manage running bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                         # Start the bot (default action)
  %(prog)s --start                 # Start the bot explicitly
  %(prog)s --stop                  # Stop the bot
  %(prog)s --restart               # Restart the bot
  %(prog)s --status                # Check bot status
  %(prog)s --logs                  # Show bot logs
  %(prog)s --prune                 # Remove all bot data and containers

Note: For initial installation, use: python3 scripts/setup.py --install
        """
    )
    
    # Action arguments
    action_group = parser.add_mutually_exclusive_group()
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
    parser.add_argument('--force-rebuild', action='store_true',
                       help='Force rebuild of Docker containers before starting')
    parser.add_argument('--enable-monitoring', action='store_true',
                       help='Enable health monitoring services')
    parser.add_argument('--enable-logging', action='store_true',
                       help='Enable centralized logging')
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview actions without executing them')
    
    # Debugging
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug mode')
    
    return parser

def parse_and_setup_args(parser: argparse.ArgumentParser) -> argparse.Namespace:
    """Parse arguments and setup environment variables"""
    args = parser.parse_args()
    
    # Load .env file first to get environment variables
    from modules.environment import load_env
    load_env()
    
    # Setup debug/verbose mode
    if args.verbose:
        os.environ["VERBOSE"] = "1"
    if args.debug:
        os.environ["DEBUG"] = "1"
    if args.dry_run:
        os.environ["DRY_RUN"] = "1"
    
    return args

def main():
    """Main function"""
    try:
        parser = create_start_parser()
        args = parse_and_setup_args(parser)
        
        # Determine which action was selected
        action = None
        if args.start:
            action = 'start'
        elif args.stop:
            action = 'stop'
        elif args.restart:
            action = 'restart'
        elif args.status:
            action = 'status'
        elif args.logs:
            action = 'logs'
        elif args.prune:
            action = 'prune'
        else:
            # Default action if no specific action is provided
            action = 'start'
        
        # Map actions to functions
        action_map = {
            'start': action_start,
            'stop': action_stop,
            'restart': action_restart,
            'status': action_status,
            'logs': action_logs,
            'prune': action_prune
        }
        
        # Prepare action arguments
        action_kwargs = {}
        
        if action == 'start':
            action_kwargs['profile'] = 'prod'
            action_kwargs['dry_run'] = is_dry_run()
            action_kwargs['force_rebuild'] = args.force_rebuild
            action_kwargs['enable_monitoring'] = args.enable_monitoring
            action_kwargs['enable_logging'] = args.enable_logging
        elif action == 'restart':
            action_kwargs['profile'] = 'prod'
        elif action == 'logs':
            action_kwargs['follow'] = True
            action_kwargs['lines'] = 50
        elif action == 'stop':
            action_kwargs['confirm'] = False
        
        # Execute action
        action_func = action_map.get(action)
        if action_func:
            success = action_func(**action_kwargs)
            if not success:
                sys.exit(1)
        else:
            print_error(f"Unknown action: {action}")
            sys.exit(1)
            
    except (BotError, DockerError) as e:
        handle_error(e)
    except KeyboardInterrupt:
        print_message("\n🛑 Operation cancelled by user", Colors.YELLOW)
        sys.exit(130)

if __name__ == "__main__":
    main() 