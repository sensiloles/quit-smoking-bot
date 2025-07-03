"""
environment.py - Environment validation utilities

This module provides functions for checking and validating
environment variables and configuration.
"""

import os
from pathlib import Path
from typing import Optional, Dict, Any

from .output import print_error, print_message, print_warning, debug_print, Colors

def load_env(env_file: str = ".env") -> Dict[str, str]:
    """Load environment variables from .env file"""
    env_vars = {}
    env_path = Path(env_file)
    
    if env_path.exists():
        debug_print(f"Loading environment from {env_file}")
        with open(env_path) as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    try:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip().strip('"\'')
                        env_vars[key] = value
                        os.environ[key] = value
                        debug_print(f"Loaded {key} from .env")
                    except ValueError:
                        debug_print(f"Invalid line {line_num} in {env_file}: {line}")
    else:
        debug_print(f"Environment file {env_file} not found")
    
    return env_vars

def check_env_var(var_name: str, required: bool = True) -> Optional[str]:
    """Check if environment variable is set and return its value"""
    debug_print(f"Checking environment variable: {var_name}")
    
    value = os.getenv(var_name)
    
    if value:
        debug_print(f"{var_name} is set")
        return value
    elif required:
        debug_print(f"{var_name} is not set and is required")
        print_error(f"{var_name} environment variable is not set.")
        return None
    else:
        debug_print(f"{var_name} is not set but is optional")
        return None

def check_bot_token() -> bool:
    """Check if BOT_TOKEN is properly configured"""
    debug_print("Checking BOT_TOKEN availability")
    
    # First check if BOT_TOKEN is set in environment
    token = os.getenv("BOT_TOKEN")
    if token and token != "your_telegram_bot_token_here":
        debug_print("BOT_TOKEN found in environment")
        return True
    
    # Then check if .env file exists and contains BOT_TOKEN
    env_path = Path(".env")
    if env_path.exists():
        debug_print(".env file found, checking for BOT_TOKEN")
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith('BOT_TOKEN='):
                    token_value = line.split('=', 1)[1].strip().strip('"\'')
                    if token_value and token_value != "your_telegram_bot_token_here":
                        debug_print("Valid BOT_TOKEN found in .env file")
                        os.environ["BOT_TOKEN"] = token_value
                        return True
    
    debug_print("BOT_TOKEN not found or invalid")
    print_error("BOT_TOKEN environment variable is not set or invalid.")
    print_message("Please set BOT_TOKEN in one of the following ways:", Colors.YELLOW)
    print_message("1. Export it in your environment: export BOT_TOKEN='your_bot_token_here'", Colors.YELLOW)
    print_message("2. Add it to .env file: echo 'BOT_TOKEN=your_bot_token_here' > .env", Colors.YELLOW)
    print_message("3. Pass it as an argument to the script", Colors.YELLOW)
    return False

def get_system_name() -> str:
    """Get system name from environment or return default"""
    return os.getenv("SYSTEM_NAME", "quit-smoking-bot")

def get_system_display_name() -> str:
    """Get system display name from environment or return default"""
    return os.getenv("SYSTEM_DISPLAY_NAME", "Quit Smoking Bot")

def check_system_name() -> bool:
    """Check if SYSTEM_NAME is set"""
    name = get_system_name()
    if not name:
        print_error("SYSTEM_NAME is not set")
        print_message("Please set SYSTEM_NAME in .env file", Colors.YELLOW)
        return False
    debug_print(f"System name: {name}")
    return True

def is_dry_run() -> bool:
    """Check if we're in dry-run mode"""
    return os.getenv("DRY_RUN", "0") == "1"

def is_debug_mode() -> bool:
    """Check if debug mode is enabled"""
    return os.getenv("DEBUG", "0") == "1"

def is_verbose_mode() -> bool:
    """Check if verbose mode is enabled"""
    return os.getenv("VERBOSE", "0") == "1"

def update_env_token(token: str, env_file: str = ".env") -> bool:
    """Update BOT_TOKEN in .env file"""
    debug_print(f"Updating BOT_TOKEN in {env_file}")
    debug_print(f"Token length: {len(token)} characters")
    
    env_path = Path(env_file)
    
    # Create .env file if it doesn't exist
    if not env_path.exists():
        debug_print(f"{env_file} does not exist, creating it")
        env_path.touch()
    
    # Read current content
    lines = []
    if env_path.exists():
        with open(env_path, 'r') as f:
            lines = f.readlines()
    
    # Update or add BOT_TOKEN
    token_updated = False
    for i, line in enumerate(lines):
        if line.strip().startswith('BOT_TOKEN='):
            lines[i] = f'BOT_TOKEN="{token}"\n'
            token_updated = True
            debug_print("BOT_TOKEN replaced successfully")
            break
    
    if not token_updated:
        lines.append(f'BOT_TOKEN="{token}"\n')
        debug_print("BOT_TOKEN added successfully")
    
    # Write back to file
    try:
        with open(env_path, 'w') as f:
            f.writelines(lines)
        
        print_message(f"✅ Updated BOT_TOKEN in {env_file}", Colors.GREEN)
        # Update current environment
        os.environ["BOT_TOKEN"] = token
        return True
    except Exception as e:
        print_error(f"Failed to update {env_file}: {e}")
        return False

def setup_environment():
    """Setup and validate environment"""
    debug_print("Setting up environment")
    
    # Load .env file
    load_env()
    
    # Validate required variables
    success = True
    success &= check_system_name()
    success &= check_bot_token()
    
    return success 