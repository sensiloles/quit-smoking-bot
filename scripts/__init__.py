"""
Scripts modules package for quit-smoking-bot

This package contains utility modules for bot management scripts.
"""

# Core utilities
# Action handlers
from .actions import (
    action_backup,
    action_cleanup,
    action_logs,
    action_prune,
    action_restart,
    action_setup,
    action_start,
    action_status,
    action_stop,
)

# Argument parsing
from .args import (
    create_health_parser,
    parse_and_setup_args,
    prompt_for_token,
    validate_token,
)

# Conflict detection
from .conflicts import (
    check_port_conflict,
    check_telegram_token_conflict,
    detect_all_conflicts,
)

# Docker utilities
from .docker_utils import (
    check_docker_installation,
    cleanup_docker_resources,
    get_container_status,
)

# Environment and configuration
from .environment import (
    check_bot_token,
    check_env_var,
    get_system_name,
    is_debug_mode,
    is_dry_run,
    load_env,
    setup_environment,
    update_env_token,
)
from .errors import (
    BotError,
    ConfigError,
    DockerError,
    EnvironmentError,
    ErrorContext,
    ServiceError,
    handle_error,
)

# Health monitoring
from .health import (
    check_bot_status,
    comprehensive_health_check,
    is_bot_healthy,
    is_bot_operational,
    quick_health_check,
)
from .output import (
    Colors,
    debug_print,
    print_error,
    print_header,
    print_message,
    print_section,
    print_success,
    print_warning,
)

# Service management
from .service import (
    get_service_status,
    restart_service,
    start_service,
    stop_service,
)

# System utilities
from .system import (
    get_system_info,
    setup_permissions,
)

__all__ = [
    # Core utilities
    "Colors",
    "print_message",
    "print_section",
    "print_header",
    "debug_print",
    "print_success",
    "print_error",
    "print_warning",
    "BotError",
    "DockerError",
    "ConfigError",
    "ServiceError",
    "EnvironmentError",
    "handle_error",
    "ErrorContext",
    # Environment and configuration
    "load_env",
    "check_env_var",
    "get_system_name",
    "check_bot_token",
    "update_env_token",
    "is_dry_run",
    "is_debug_mode",
    "setup_environment",
    # Docker utilities
    "check_docker_installation",
    "get_container_status",
    "cleanup_docker_resources",
    # Health monitoring
    "quick_health_check",
    "comprehensive_health_check",
    "is_bot_healthy",
    "is_bot_operational",
    "check_bot_status",
    # Service management
    "get_service_status",
    "start_service",
    "stop_service",
    "restart_service",
    # System utilities
    "setup_permissions",
    "get_system_info",
    # Conflict detection
    "detect_all_conflicts",
    "check_port_conflict",
    "check_telegram_token_conflict",
    # Action handlers
    "action_setup",
    "action_start",
    "action_stop",
    "action_restart",
    "action_status",
    "action_logs",
    "action_cleanup",
    "action_prune",
    "action_backup",
    # Argument parsing
    "create_health_parser",
    "parse_and_setup_args",
    "validate_token",
    "prompt_for_token",
]
