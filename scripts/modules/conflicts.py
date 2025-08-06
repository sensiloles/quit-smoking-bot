"""
conflicts.py - Conflict detection and resolution utilities

This module provides functions for detecting and resolving conflicts
such as port conflicts, token conflicts, and resource conflicts.
"""

import os
import socket
import subprocess
from typing import Any, Dict, Optional

from .docker_utils import run_command
from .environment import get_system_name
from .output import Colors, debug_print, print_error, print_message, print_warning


def check_port_conflict(port: int) -> bool:
    """Check if a port is already in use"""
    debug_print(f"Checking port conflict for port {port}")

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            result = sock.connect_ex(("localhost", port))

            if result == 0:
                debug_print(f"Port {port} is already in use")
                return True
            debug_print(f"Port {port} is available")
            return False
    except Exception as e:
        debug_print(f"Error checking port {port}: {e}")
        return False


def find_process_using_port(port: int) -> Optional[Dict[str, Any]]:
    """Find process using a specific port"""
    debug_print(f"Finding process using port {port}")

    try:
        # Try lsof first (more reliable)
        result = run_command(["lsof", "-i", f":{port}", "-n", "-P"])
        if result.returncode == 0 and result.stdout.strip():
            lines = result.stdout.strip().split("\n")
            if len(lines) > 1:  # Skip header
                fields = lines[1].split()
                if len(fields) >= 2:
                    return {
                        "command": fields[0],
                        "pid": fields[1],
                        "user": fields[2] if len(fields) > 2 else "unknown",
                    }
    except Exception:
        pass

    try:
        # Fallback to netstat
        result = run_command(["netstat", "-tlnp"])
        if result.returncode == 0:
            for line in result.stdout.split("\n"):
                if f":{port} " in line:
                    debug_print(f"Found netstat line: {line}")
                    return {"command": "unknown", "pid": "unknown", "user": "unknown"}
    except Exception:
        pass

    return None


def check_telegram_token_conflict() -> bool:
    """Check for Telegram bot token conflicts"""
    debug_print("Checking for Telegram token conflicts")

    bot_token = os.getenv("BOT_TOKEN")
    if not bot_token:
        debug_print("No BOT_TOKEN set, skipping conflict check")
        return False

    # Check if any other containers might be using the same token
    result = run_command(["docker", "ps", "--format", "{{.Names}}"])
    if result.returncode != 0:
        debug_print("Could not list Docker containers")
        return False

    system_name = get_system_name()
    containers = [name.strip() for name in result.stdout.split("\n") if name.strip()]

    # Look for other bot containers
    bot_containers = [
        name for name in containers if "bot" in name.lower() and system_name not in name
    ]

    if bot_containers:
        debug_print(f"Found other bot containers: {bot_containers}")
        print_warning("⚠️  Other bot containers detected:")
        for container in bot_containers:
            print_message(f"  - {container}", Colors.YELLOW)
        print_message(
            "Multiple bots with the same token may cause conflicts",
            Colors.YELLOW,
        )
        return True

    return False


def check_docker_name_conflict() -> bool:
    """Check for Docker container/image name conflicts"""
    debug_print("Checking for Docker name conflicts")

    system_name = get_system_name()

    # Check for containers with similar names
    result = run_command(["docker", "ps", "-a", "--format", "{{.Names}}"])
    if result.returncode != 0:
        return False

    containers = [name.strip() for name in result.stdout.split("\n") if name.strip()]

    # Look for containers with similar names
    similar_containers = []
    for container in containers:
        if system_name in container or container in system_name:
            if container != system_name and f"{system_name}_" not in container:
                similar_containers.append(container)

    if similar_containers:
        debug_print(f"Found similar container names: {similar_containers}")
        print_warning("⚠️  Similar container names detected:")
        for container in similar_containers:
            print_message(f"  - {container}", Colors.YELLOW)
        print_message("This might cause confusion", Colors.YELLOW)
        return True

    return False


def check_file_conflicts() -> bool:
    """Check for file and directory conflicts"""
    debug_print("Checking for file conflicts")

    conflicts = []

    # Check for important files
    important_files = [".env", "docker-compose.yml", "Dockerfile"]
    for file_name in important_files:
        if os.path.exists(file_name):
            # Check if file is writable
            if not os.access(file_name, os.W_OK):
                conflicts.append(f"{file_name} is not writable")

    # Check for data directories
    important_dirs = ["data", "logs"]
    for dir_name in important_dirs:
        if os.path.exists(dir_name):
            if not os.access(dir_name, os.W_OK):
                conflicts.append(f"{dir_name}/ directory is not writable")

    if conflicts:
        debug_print(f"Found file conflicts: {conflicts}")
        print_warning("⚠️  File permission conflicts detected:")
        for conflict in conflicts:
            print_message(f"  - {conflict}", Colors.YELLOW)
        return True

    return False


def check_docker_conflicts() -> bool:
    """Check for Docker-related conflicts"""
    debug_print("Checking for Docker conflicts")

    conflicts = False

    # Check Docker daemon
    result = run_command(["docker", "info"])
    if result.returncode != 0:
        print_error("Docker daemon is not running or accessible")
        return True

    # Check for multiple Docker Compose files
    compose_files = []
    for filename in [
        "docker-compose.yml",
        "docker-compose.yaml",
        "compose.yml",
        "compose.yaml",
    ]:
        if os.path.exists(filename):
            compose_files.append(filename)

    if len(compose_files) > 1:
        print_warning("⚠️  Multiple Docker Compose files found:")
        for file in compose_files:
            print_message(f"  - {file}", Colors.YELLOW)
        print_message("This might cause unexpected behavior", Colors.YELLOW)
        conflicts = True

    return conflicts


def check_environment_conflicts() -> bool:
    """Check for environment variable conflicts"""
    debug_print("Checking for environment conflicts")

    conflicts = []

    # Check for conflicting environment variables
    conflicting_vars = {
        "DOCKER_HOST": "Custom Docker host might interfere with local operations",
        "COMPOSE_FILE": "Custom compose file might override project configuration",
    }

    for var, message in conflicting_vars.items():
        if os.getenv(var):
            conflicts.append(f"{var}: {message}")

    if conflicts:
        debug_print(f"Found environment conflicts: {conflicts}")
        print_warning("⚠️  Environment variable conflicts detected:")
        for conflict in conflicts:
            print_message(f"  - {conflict}", Colors.YELLOW)
        return True

    return False


def detect_all_conflicts() -> Dict[str, bool]:
    """Detect all types of conflicts"""
    debug_print("Running comprehensive conflict detection")

    print_message("🔍 Checking for conflicts...", Colors.BLUE)

    conflicts = {
        "telegram_token": check_telegram_token_conflict(),
        "docker_names": check_docker_name_conflict(),
        "file_permissions": check_file_conflicts(),
        "docker_resources": check_docker_conflicts(),
        "environment": check_environment_conflicts(),
    }

    # Check common ports
    common_ports = [80, 443, 8080, 3000, 5000]
    port_conflicts = any(check_port_conflict(port) for port in common_ports)
    conflicts["ports"] = port_conflicts

    total_conflicts = sum(conflicts.values())

    if total_conflicts == 0:
        print_message("✅ No conflicts detected", Colors.GREEN)
    else:
        print_warning(f"⚠️  {total_conflicts} conflict(s) detected")
        print_message(
            "Review the warnings above and resolve conflicts if necessary",
            Colors.YELLOW,
        )

    return conflicts


def resolve_port_conflict(port: int, force: bool = False) -> bool:
    """Attempt to resolve port conflict"""
    debug_print(f"Attempting to resolve port conflict for port {port}")

    process_info = find_process_using_port(port)
    if not process_info:
        return True  # No conflict

    print_warning(f"Port {port} is in use by: {process_info.get('command', 'unknown')}")

    if not force:
        response = (
            input(
                f"Would you like to try to stop the process using port {port}? (y/N): ",
            )
            .strip()
            .lower()
        )
        if response not in ["y", "yes"]:
            return False

    # Try to stop the process
    pid = process_info.get("pid")
    if pid and pid != "unknown":
        try:
            debug_print(f"Attempting to kill process {pid}")
            subprocess.run(["kill", pid], check=True)
            print_message(f"Stopped process {pid}", Colors.GREEN)
            return True
        except subprocess.CalledProcessError:
            print_error(f"Failed to stop process {pid}")
            return False

    return False


def suggest_conflict_resolutions(conflicts: Dict[str, bool]) -> None:
    """Suggest resolutions for detected conflicts"""
    if not any(conflicts.values()):
        return

    print_message("\n💡 Conflict Resolution Suggestions:", Colors.BLUE)

    if conflicts.get("telegram_token"):
        print_message(
            "• Stop other bot instances or use different tokens",
            Colors.YELLOW,
        )

    if conflicts.get("docker_names"):
        print_message("• Rename or remove conflicting containers", Colors.YELLOW)

    if conflicts.get("file_permissions"):
        print_message("• Run: python scripts/setup-permissions.py", Colors.YELLOW)

    if conflicts.get("docker_resources"):
        print_message("• Clean up Docker resources: docker system prune", Colors.YELLOW)

    if conflicts.get("environment"):
        print_message("• Review and adjust environment variables", Colors.YELLOW)

    if conflicts.get("ports"):
        print_message("• Stop services using conflicting ports", Colors.YELLOW)


def wait_for_conflict_resolution(max_attempts: int = 5) -> bool:
    """Wait for user to resolve conflicts manually"""
    print_message(
        f"\nWaiting for conflict resolution (max {max_attempts} attempts)...",
        Colors.YELLOW,
    )

    for attempt in range(1, max_attempts + 1):
        print_message(
            f"Attempt {attempt}/{max_attempts}: Checking conflicts...",
            Colors.YELLOW,
        )

        conflicts = detect_all_conflicts()
        if not any(conflicts.values()):
            print_message("✅ All conflicts resolved!", Colors.GREEN)
            return True

        if attempt < max_attempts:
            input("Press Enter after resolving conflicts to check again...")

    print_warning("⚠️  Some conflicts remain unresolved")
    return False
