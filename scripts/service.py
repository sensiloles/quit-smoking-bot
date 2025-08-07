"""
service.py - Service management utilities

This module provides functions for managing bot services,
including starting, stopping, and checking service status.
"""

import os
import subprocess
import time
from typing import Any, Dict

from .docker_utils import get_container_status, run_command
from .environment import is_dry_run
from .errors import ErrorContext, ServiceError
from .output import (
    Colors,
    debug_print,
    print_message,
    print_success,
    print_warning,
)


def get_service_status() -> Dict[str, Any]:
    """Get comprehensive service status"""
    debug_print("Getting service status")

    status = {
        "docker_running": False,
        "containers": {},
        "services": {},
        "healthy": False,
    }

    # Check Docker daemon
    result = run_command(["docker", "info"])
    status["docker_running"] = result.returncode == 0

    if not status["docker_running"]:
        return status

    # Check containers
    container_status = get_container_status()
    status["containers"] = container_status

    # Check docker-compose services
    result = run_command(
        ["docker-compose", "-f", "docker/docker-compose.yml", "ps", "--services"],
    )
    if result.returncode == 0:
        services = [s.strip() for s in result.stdout.split("\n") if s.strip()]
        for service in services:
            service_result = run_command(
                ["docker-compose", "-f", "docker/docker-compose.yml", "ps", service],
            )
            is_running = "Up" in service_result.stdout
            status["services"][service] = {
                "running": is_running,
                "status": "healthy" if is_running else "stopped",
            }

    # Overall health
    status["healthy"] = (
        status["docker_running"]
        and container_status.get("running", False)
        and container_status.get("healthy", False)
    )

    return status


def start_service(service: str = "bot") -> bool:
    """Start a specific service"""
    debug_print(f"Starting service: {service}")

    with ErrorContext(f"Starting service {service}"):
        if is_dry_run():
            print_message(f"DRY RUN: Would start service {service}", Colors.YELLOW)
            return True

        # Prepare environment
        env = os.environ.copy()

        print_message(f"🚀 Starting service: {service}", Colors.BLUE)

        # Start the service
        cmd = ["docker-compose", "-f", "docker/docker-compose.yml", "up", "-d"]
        if service != "all":
            cmd.append(service)

        result = subprocess.run(cmd, check=False, env=env, capture_output=False)
        if result.returncode != 0:
            raise ServiceError(f"Failed to start service {service}")

        # Wait for service to be ready
        print_message(f"Waiting for {service} to be ready...", Colors.YELLOW)
        if not wait_for_service_ready(service):
            print_warning(f"Service {service} may not be fully ready")
            return False

        print_success(f"✅ Service {service} started successfully")
        return True


def stop_service(service: str = "bot", cleanup: bool = False) -> bool:
    """Stop a specific service"""
    debug_print(f"Stopping service: {service}, cleanup: {cleanup}")

    with ErrorContext(f"Stopping service {service}"):
        if is_dry_run():
            print_message(f"DRY RUN: Would stop service {service}", Colors.YELLOW)
            return True

        print_message(f"🛑 Stopping service: {service}", Colors.BLUE)

        if service == "all":
            cmd = ["docker-compose", "-f", "docker/docker-compose.yml", "down"]
            if cleanup:
                cmd.extend(["-v", "--remove-orphans"])
        else:
            cmd = ["docker-compose", "-f", "docker/docker-compose.yml", "stop", service]

        result = subprocess.run(cmd, check=False, capture_output=False)
        if result.returncode != 0:
            raise ServiceError(f"Failed to stop service {service}")

        print_success(f"✅ Service {service} stopped successfully")
        return True


def restart_service(service: str = "bot") -> bool:
    """Restart a specific service"""
    debug_print(f"Restarting service: {service}")

    print_message(f"🔄 Restarting service: {service}", Colors.BLUE)

    # Stop first
    if not stop_service(service):
        return False

    # Wait a moment
    time.sleep(2)

    # Start again
    return start_service(service)


def wait_for_service_ready(service: str, timeout: int = 60) -> bool:
    """Wait for service to be ready"""
    debug_print(f"Waiting for service {service} to be ready (timeout: {timeout}s)")

    start_time = time.time()

    while time.time() - start_time < timeout:
        # Check if container is running
        status = get_container_status()
        if not status.get("running", False):
            debug_print(f"Service {service} container is not running")
            time.sleep(2)
            continue

        # For bot service, check health
        if service == "bot":
            result = run_command(
                [
                    "docker-compose",
                    "-f",
                    "docker/docker-compose.yml",
                    "ps",
                    "-q",
                    "bot",
                ],
            )
            container_id = result.stdout.strip()

            if container_id:
                # Check health status
                result = run_command(
                    [
                        "docker",
                        "inspect",
                        "--format",
                        "{{.State.Health.Status}}",
                        container_id,
                    ],
                )
                health_status = result.stdout.strip()

                if health_status == "healthy":
                    debug_print(f"Service {service} is healthy")
                    return True
                if health_status == "starting":
                    debug_print(f"Service {service} is starting...")
                    time.sleep(5)
                    continue
                debug_print(
                    f"Service {service} health check failed: {health_status}",
                )
                time.sleep(2)
                continue
        else:
            # For other services, just check if running
            return True

    debug_print(f"Timeout waiting for service {service} to be ready")
    return False
