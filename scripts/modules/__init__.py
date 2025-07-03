"""
Scripts modules package for quit-smoking-bot

This package contains utility modules for bot management scripts.
"""

# Core utilities
from .output import Colors, print_message, print_section, print_header, debug_print, print_success, print_error, print_warning
from .errors import BotError, DockerError, ConfigError, ServiceError, EnvironmentError, handle_error, ErrorContext

# Environment and configuration
from .environment import (
    load_env, check_env_var, get_system_name, check_bot_token, 
    update_env_token, is_dry_run, is_debug_mode, setup_environment
)

# Docker utilities
from .docker_utils import (
    check_docker, check_docker_installation, run_docker_command, 
    get_container_status, cleanup_docker_resources
)

# Health monitoring
from .health import (
    quick_health_check, comprehensive_health_check, 
    is_bot_healthy, is_bot_operational, check_bot_status
)

# Service management
from .service import (
    get_service_status, start_service, stop_service, restart_service,
    get_service_logs, update_service, cleanup_service_resources
)

# System utilities
from .system import (
    setup_permissions, check_permissions, get_system_info,
    get_disk_usage, cleanup_old_files, check_system_resources
)

# Conflict detection
from .conflicts import (
    detect_all_conflicts, check_port_conflict, check_telegram_token_conflict,
    suggest_conflict_resolutions
)

# Action handlers
from .actions import (
    action_setup, action_start, action_stop, action_restart,
    action_status, action_logs, action_cleanup,
    action_prune, action_backup, action_restore
)

# Argument parsing
from .args import (
    create_run_parser, create_health_parser, create_check_service_parser,
    create_bootstrap_parser, create_stop_parser, parse_and_setup_args,
    validate_token, prompt_for_token
)

__all__ = [
    # Core utilities
    'Colors', 'print_message', 'print_section', 'print_header', 'debug_print',
    'print_success', 'print_error', 'print_warning',
    'BotError', 'DockerError', 'ConfigError', 'ServiceError', 'EnvironmentError',
    'handle_error', 'ErrorContext',
    
    # Environment and configuration
    'load_env', 'check_env_var', 'get_system_name', 'check_bot_token',
    'update_env_token', 'is_dry_run', 'is_debug_mode', 'setup_environment',
    
    # Docker utilities
    'check_docker', 'check_docker_installation', 'run_docker_command',
    'get_container_status', 'cleanup_docker_resources',
    
    # Health monitoring
    'quick_health_check', 'comprehensive_health_check',
    'is_bot_healthy', 'is_bot_operational', 'check_bot_status',
    
    # Service management
    'get_service_status', 'start_service', 'stop_service', 'restart_service',
    'get_service_logs', 'update_service', 'cleanup_service_resources',
    
    # System utilities
    'setup_permissions', 'check_permissions', 'get_system_info',
    'get_disk_usage', 'cleanup_old_files', 'check_system_resources',
    
    # Conflict detection
    'detect_all_conflicts', 'check_port_conflict', 'check_telegram_token_conflict',
    'suggest_conflict_resolutions',
    
    # Action handlers
    'action_setup', 'action_start', 'action_stop', 'action_restart',
    'action_status', 'action_logs', 'action_cleanup',
    'action_prune', 'action_backup', 'action_restore',
    
    # Argument parsing
    'create_run_parser', 'create_health_parser', 'create_check_service_parser',
    'create_bootstrap_parser', 'create_stop_parser', 'parse_and_setup_args',
    'validate_token', 'prompt_for_token'
] 