"""
output.py - Output utilities for formatted messages

This module provides colored output functions and message formatting.
"""

import os
import sys


# ANSI color codes
class Colors:
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    RED = "\033[0;31m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    MAGENTA = "\033[0;35m"
    WHITE = "\033[1;37m"
    NC = "\033[0m"  # No Color


def print_message(message: str, color: str = Colors.NC):
    """Print a formatted message with optional color"""
    print(f"{color}{message}{Colors.NC}")


def print_warning(message: str):
    """Print a warning message"""
    print_message(message, Colors.YELLOW)


def print_error(message: str):
    """Print an error message"""
    print_message(message, Colors.RED)


def print_section(title: str):
    """Print a section header"""
    print(f"\n{Colors.BLUE}=== {title} ==={Colors.NC}")


def print_header(title: str):
    """Print a main header (like section but more prominent)"""
    print(f"\n{Colors.GREEN}{'=' * 50}{Colors.NC}")
    print(f"{Colors.GREEN}{title}{Colors.NC}")
    print(f"{Colors.GREEN}{'=' * 50}{Colors.NC}\n")


def print_success(message: str):
    """Print a success message"""
    print_message(message, Colors.GREEN)


def debug_print(message: str):
    """Print debug message if debug mode is enabled"""
    if os.getenv("DEBUG", "0") == "1" or os.getenv("VERBOSE", "0") == "1":
        print(f"DEBUG: {message}", file=sys.stderr)
