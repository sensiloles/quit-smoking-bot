"""
errors.py - Error handling utilities and custom exceptions

This module provides custom exception classes and error handling utilities
for the bot management system.
"""

import sys
from typing import Optional, Any

from .output import print_error, print_warning, debug_print, Colors

class BotError(Exception):
    """Base exception class for bot-related errors"""
    
    def __init__(self, message: str, code: int = 1, details: Optional[str] = None):
        self.message = message
        self.code = code
        self.details = details
        super().__init__(self.message)
    
    def __str__(self):
        result = self.message
        if self.details:
            result += f" Details: {self.details}"
        return result

class DockerError(BotError):
    """Exception for Docker-related errors"""
    
    def __init__(self, message: str, command: Optional[str] = None, code: int = 2):
        details = f"Command: {command}" if command else None
        super().__init__(message, code, details)

class ConfigError(BotError):
    """Exception for configuration errors"""
    
    def __init__(self, message: str, config_file: Optional[str] = None, code: int = 3):
        details = f"Config file: {config_file}" if config_file else None
        super().__init__(message, code, details)

class EnvironmentError(BotError):
    """Exception for environment variable errors"""
    
    def __init__(self, message: str, var_name: Optional[str] = None, code: int = 4):
        details = f"Variable: {var_name}" if var_name else None
        super().__init__(message, code, details)

class ServiceError(BotError):
    """Exception for service management errors"""
    
    def __init__(self, message: str, service: Optional[str] = None, code: int = 5):
        details = f"Service: {service}" if service else None
        super().__init__(message, code, details)

def handle_error(error: Exception, exit_on_error: bool = True) -> None:
    """Handle and display errors appropriately"""
    debug_print(f"Handling error: {type(error).__name__}: {error}")
    
    if isinstance(error, BotError):
        print_error(f"❌ {error.message}")
        if error.details:
            print_error(f"   {error.details}")
        
        if exit_on_error:
            debug_print(f"Exiting with code {error.code}")
            sys.exit(error.code)
    
    elif isinstance(error, KeyboardInterrupt):
        print_warning("\n🛑 Operation cancelled by user")
        if exit_on_error:
            sys.exit(130)  # Standard exit code for SIGINT
    
    else:
        print_error(f"❌ Unexpected error: {error}")
        debug_print(f"Error type: {type(error)}")
        
        if exit_on_error:
            sys.exit(1)

def validate_required_param(value: Any, param_name: str) -> Any:
    """Validate that a required parameter is not None/empty"""
    if value is None or (isinstance(value, str) and not value.strip()):
        raise ConfigError(f"Required parameter '{param_name}' is missing or empty", var_name=param_name)
    return value

def require_docker() -> None:
    """Ensure Docker is available, raise DockerError if not"""
    import subprocess
    
    try:
        result = subprocess.run(["docker", "--version"], capture_output=True, check=True)
        debug_print(f"Docker version: {result.stdout.strip()}")
    except (subprocess.CalledProcessError, FileNotFoundError):
        raise DockerError("Docker is not installed or not accessible")

def require_docker_compose() -> None:
    """Ensure Docker Compose is available, raise DockerError if not"""
    import subprocess
    
    try:
        result = subprocess.run(["docker-compose", "--version"], capture_output=True, check=True)
        debug_print(f"Docker Compose version: {result.stdout.strip()}")
    except (subprocess.CalledProcessError, FileNotFoundError):
        raise DockerError("Docker Compose is not installed or not accessible")

def require_env_var(var_name: str) -> str:
    """Require an environment variable, raise EnvironmentError if not set"""
    import os
    
    value = os.getenv(var_name)
    if not value:
        raise EnvironmentError(f"Environment variable '{var_name}' is required but not set", var_name=var_name)
    
    debug_print(f"Environment variable {var_name} is set")
    return value

def safe_exit(code: int = 0, message: Optional[str] = None) -> None:
    """Safely exit the application with optional message"""
    if message:
        if code == 0:
            print_warning(message)
        else:
            print_error(message)
    
    debug_print(f"Exiting with code {code}")
    sys.exit(code)

class ErrorContext:
    """Context manager for handling errors in specific operations"""
    
    def __init__(self, operation: str, exit_on_error: bool = True):
        self.operation = operation
        self.exit_on_error = exit_on_error
    
    def __enter__(self):
        debug_print(f"Starting operation: {self.operation}")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            debug_print(f"Operation failed: {self.operation}")
            if isinstance(exc_val, BotError):
                # Re-raise BotError with operation context
                exc_val.message = f"{self.operation}: {exc_val.message}"
            
            handle_error(exc_val, self.exit_on_error)
            return not self.exit_on_error  # Suppress exception if not exiting
        else:
            debug_print(f"Operation completed successfully: {self.operation}")
        
        return False 