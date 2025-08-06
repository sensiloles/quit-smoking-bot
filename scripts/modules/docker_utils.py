"""
docker_utils.py - Docker management utilities

This module provides functions for Docker installation checks,
daemon management, and container operations.
"""

import os
import platform
import subprocess
from typing import Any, Dict, List, Optional

from .environment import get_system_name
from .output import Colors, debug_print, print_error, print_message, print_warning


def run_command(
    cmd: List[str],
    capture_output: bool = True,
) -> subprocess.CompletedProcess:
    """Run a command and return the result"""
    try:
        debug_print(f"Running command: {' '.join(cmd)}")
        return subprocess.run(
            cmd,
            capture_output=capture_output,
            text=True,
            check=False,
        )
    except Exception as e:
        debug_print(f"Command failed: {' '.join(cmd)}, error: {e}")
        return subprocess.CompletedProcess(cmd, 1, "", str(e))


def check_docker_installation() -> bool:
    """Check if Docker is installed and running"""
    debug_print("Checking Docker installation...")

    # Check if docker command exists
    result = run_command(["docker", "--version"])
    if result.returncode != 0:
        debug_print("Docker command not found in PATH")
        print_error("Docker is not installed.")
        print_message("Please install Docker first.", Colors.YELLOW)
        return False

    debug_print("Docker command found")

    # Check if Docker daemon is running
    debug_print("Checking Docker daemon status...")
    result = run_command(["docker", "info"])
    if result.returncode != 0:
        debug_print("Docker daemon is not responding")
        print_error("Docker daemon is not running.")

        # Try to start Docker based on OS
        if platform.system() == "Darwin":
            debug_print("Detected macOS, attempting to start Docker for Mac")
            return start_docker_macos()
        debug_print("Detected Linux, attempting to start Docker daemon")
        return start_docker_linux()

    debug_print("Docker daemon is running and accessible")
    return True


def start_docker_macos() -> bool:
    """Start Docker on macOS"""
    debug_print("Starting Docker for Mac procedure")
    print_message("Attempting to start Docker for Mac...", Colors.YELLOW)

    docker_app_path = "/Applications/Docker.app/Contents/MacOS/Docker"
    if os.path.exists(docker_app_path):
        debug_print("Docker.app found, executing 'open -a Docker'")
        print_message("Found Docker.app, attempting to start it...", Colors.YELLOW)

        result = run_command(["open", "-a", "Docker"])
        if result.returncode != 0:
            print_error("Failed to start Docker.app")
            return False

        # Wait for Docker to start (up to 60 seconds)
        max_attempts = 30
        debug_print(f"Starting Docker daemon wait loop (max {max_attempts} attempts)")

        for attempt in range(1, max_attempts + 1):
            print_message(
                f"Waiting for Docker to start (attempt {attempt}/{max_attempts})...",
                Colors.YELLOW,
            )
            debug_print(f"Testing Docker daemon connectivity (attempt {attempt})")

            result = run_command(["docker", "info"])
            if result.returncode == 0:
                debug_print("Docker daemon responded successfully")
                print_message("Docker started successfully.", Colors.GREEN)
                return True

            import time

            time.sleep(2)

        debug_print("Docker daemon failed to start within timeout period")
        print_error("Failed to start Docker for Mac.")
        print_message(
            "Please start Docker for Mac manually and try again.",
            Colors.YELLOW,
        )
        return False
    debug_print("Docker.app not found")
    print_error("Docker for Mac is not installed.")
    print_message("Please install Docker for Mac and try again.", Colors.YELLOW)
    return False


def start_docker_linux() -> bool:
    """Start Docker on Linux"""
    debug_print("Starting Docker daemon on Linux")
    print_message("Attempting to start Docker daemon...", Colors.YELLOW)

    debug_print("Executing: systemctl start docker.service")
    result = run_command(["systemctl", "start", "docker.service"])

    if result.returncode == 0:
        debug_print("systemctl start command succeeded")

        # Wait for Docker to start
        max_attempts = 10
        debug_print(f"Starting Docker daemon wait loop (max {max_attempts} attempts)")

        for attempt in range(1, max_attempts + 1):
            print_message(
                f"Waiting for Docker to start (attempt {attempt}/{max_attempts})...",
                Colors.YELLOW,
            )
            debug_print(f"Testing Docker daemon connectivity (attempt {attempt})")

            result = run_command(["docker", "info"])
            if result.returncode == 0:
                debug_print("Docker daemon responded successfully")
                print_message("Docker started successfully.", Colors.GREEN)
                return True

            import time

            time.sleep(2)

        debug_print("Docker daemon failed to respond within timeout period")
    else:
        debug_print("systemctl start docker.service failed")

    debug_print("Failed to start Docker daemon via systemctl")
    print_error("Failed to start Docker daemon.")
    print_message(
        "Please start Docker daemon manually: sudo systemctl start docker",
        Colors.YELLOW,
    )
    return False


def check_docker() -> bool:
    """Check Docker daemon and start if needed"""
    result = run_command(["docker", "info"])
    if result.returncode != 0:
        print_error("Docker daemon is not running")
        if platform.system() == "Darwin":
            return start_docker_macos()
        return start_docker_linux()
    return True


def check_docker_buildx() -> bool:
    """Check Docker Buildx availability"""
    result = run_command(["docker", "buildx", "version"])
    if result.returncode != 0:
        print_warning("Docker Buildx is not installed. Using legacy builder.")
        print_message(
            "For better performance, consider installing Docker Buildx:",
            Colors.YELLOW,
        )
        print_message("https://docs.docker.com/go/buildx/", Colors.YELLOW)
        return False
    return True


def run_docker_command(
    cmd: List[str],
    description: str = "",
    check: bool = True,
) -> bool:
    """Run a Docker command with error handling"""
    if description:
        print_message(f"🔧 {description}...", Colors.BLUE)

    result = run_command(cmd, capture_output=False)

    if result.returncode == 0:
        if description:
            print_message(f"✅ {description} completed", Colors.GREEN)
        return True
    if description:
        print_error(f"❌ {description} failed")
    if check:
        raise subprocess.CalledProcessError(result.returncode, cmd)
    return False


def get_container_status(container_name: Optional[str] = None) -> Dict[str, Any]:
    """Get container status information"""
    if not container_name:
        container_name = get_system_name()

    debug_print(f"Getting status for container: {container_name}")

    # Check if container exists
    result = run_command(
        [
            "docker",
            "ps",
            "-a",
            "--filter",
            f"name={container_name}",
            "--format",
            "{{.Names}}",
        ],
    )
    containers = [name for name in result.stdout.strip().split("\n") if name.strip()]

    if not containers:
        return {"exists": False, "running": False, "healthy": False, "containers": []}

    # Check if running
    result = run_command(
        [
            "docker",
            "ps",
            "--filter",
            f"name={container_name}",
            "--format",
            "{{.Names}}",
        ],
    )
    running_containers = [
        name for name in result.stdout.strip().split("\n") if name.strip()
    ]

    is_running = len(running_containers) > 0

    # Check health status if running
    is_healthy = False
    if is_running:
        result = run_command(
            [
                "docker",
                "inspect",
                "--format",
                "{{.State.Health.Status}}",
                container_name,
            ],
        )
        if result.returncode == 0:
            health_status = result.stdout.strip()
            is_healthy = health_status == "healthy"

    return {
        "exists": True,
        "running": is_running,
        "healthy": is_healthy,
        "containers": containers,
        "running_containers": running_containers,
    }


def cleanup_docker_resources(service: str = "", cleanup_all: bool = False) -> bool:
    """Clean up Docker resources"""
    system_name = get_system_name()

    print_message("Cleaning up Docker resources...", Colors.YELLOW)
    success = True

    try:
        # Stop and remove containers
        print_message("Stopping and removing containers...", Colors.YELLOW)
        if service:
            run_command(
                [
                    "docker-compose",
                    "-f",
                    "docker/docker-compose.yml",
                    "rm",
                    "-sf",
                    service,
                ],
            )
        else:
            run_command(["docker-compose", "-f", "docker/docker-compose.yml", "down"])

        # Remove images
        print_message("Removing Docker images...", Colors.YELLOW)
        if service:
            result = run_command(
                [
                    "docker-compose",
                    "-f",
                    "docker/docker-compose.yml",
                    "images",
                    "-q",
                    service,
                ],
            )
            if result.stdout.strip():
                images = result.stdout.strip().split("\n")
                run_command(["docker", "rmi"] + images)
        else:
            result = run_command(
                ["docker-compose", "-f", "docker/docker-compose.yml", "images", "-q"],
            )
            if result.stdout.strip():
                images = result.stdout.strip().split("\n")
                run_command(["docker", "rmi"] + images)

        # Additional cleanup if requested
        if cleanup_all:
            print_message("Cleaning up unused Docker resources...", Colors.YELLOW)
            run_command(
                [
                    "docker-compose",
                    "-f",
                    "docker/docker-compose.yml",
                    "down",
                    "-v",
                    "--remove-orphans",
                ],
            )

        print_message("Docker cleanup completed.", Colors.GREEN)

    except Exception as e:
        print_error(f"Error during cleanup: {e}")
        success = False

    return success
