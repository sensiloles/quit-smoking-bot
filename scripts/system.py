"""
system.py - System utilities and permission management

This module provides system-level utilities including permission setup,
file management, and system checks.
"""

import os
import platform
import stat
from pathlib import Path
from typing import Dict

from .errors import ErrorContext
from .output import (
    Colors,
    debug_print,
    print_error,
    print_message,
    print_success,
)


def get_system_info() -> Dict[str, str]:
    """Get system information"""
    debug_print("Getting system information")

    info = {
        "platform": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "python_version": platform.python_version(),
        "user": os.getenv("USER", "unknown"),
        "home": os.getenv("HOME", "unknown"),
        "pwd": os.getcwd(),
    }

    debug_print(f"System info: {info}")
    return info


def setup_permissions() -> bool:
    """Setup proper permissions for bot files and directories"""
    debug_print("Setting up permissions")

    try:
        with ErrorContext("Permission setup"):
            print_message("🔧 Setting up file permissions...", Colors.BLUE)

            # Create directories with proper permissions
            directories = [("data", 0o755), ("logs", 0o755), ("backups", 0o755)]

            for dir_name, permissions in directories:
                dir_path = Path(dir_name)
                dir_path.mkdir(exist_ok=True)
                os.chmod(dir_path, permissions)
                debug_print(f"Set permissions {oct(permissions)} for {dir_name}/")

            # Set permissions for important files
            files = [
                (".env", 0o600),
                ("docker-compose.yml", 0o644),
                ("Dockerfile", 0o644),
            ]

            for file_name, permissions in files:
                file_path = Path(file_name)
                if file_path.exists():
                    os.chmod(file_path, permissions)
                    debug_print(f"Set permissions {oct(permissions)} for {file_name}")

            # Make scripts executable
            script_patterns = ["scripts/*.py", "scripts/*.sh"]

            for pattern in script_patterns:
                import glob

                for script_file in glob.glob(pattern):
                    script_path = Path(script_file)
                    if script_path.exists():
                        # Add execute permission
                        current_mode = script_path.stat().st_mode
                        new_mode = current_mode | stat.S_IXUSR | stat.S_IXGRP
                        os.chmod(script_path, new_mode)
                        debug_print(f"Made {script_file} executable")

            # Create data files if they don't exist
            data_files = ["data/quotes.json"]

            for data_file in data_files:
                file_path = Path(data_file)
                if not file_path.exists():
                    file_path.parent.mkdir(exist_ok=True)

                    # Create with default content based on file type
                    if data_file.endswith("quotes.json"):
                        content = "[]"
                    else:
                        content = "{}"

                    file_path.write_text(content)
                    os.chmod(file_path, 0o644)
                    debug_print(f"Created {data_file}")

            print_success("✅ Permissions setup completed")
            return True

    except Exception as e:
        print_error(f"Failed to setup permissions: {e}")
        return False
