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


def cleanup_project_dangling_images(verbose: bool = True) -> bool:
    """Clean up dangling Docker images belonging only to this project"""
    debug_print("Starting project-specific dangling images cleanup")

    try:
        system_name = get_system_name()
        if not system_name:
            debug_print("SYSTEM_NAME not found, cannot filter project images")
            if verbose:
                print_warning("⚠️  Cannot determine project name, skipping cleanup")
            return False

        debug_print(f"Looking for dangling images related to project: {system_name}")

        # Strategy 1: Find dangling images with project name label
        result_project_labeled = run_command(
            [
                "docker",
                "images",
                "-f",
                "dangling=true",
                "-f",
                f"label=project.name={system_name}",
                "-q",
            ]
        )

        # Strategy 2: Find dangling images with Docker Compose project label (fallback)
        result_compose_labeled = run_command(
            [
                "docker",
                "images",
                "-f",
                "dangling=true",
                "-f",
                f"label=com.docker.compose.project={system_name}",
                "-q",
            ]
        )

        # Strategy 2: Find all dangling images and filter by name pattern
        result_all_dangling = run_command(
            [
                "docker",
                "images",
                "-f",
                "dangling=true",
                "--format",
                "{{.ID}} {{.Repository}}",
            ]
        )

        project_dangling_images = set()

        # Collect images from project name labeled strategy
        if (
            result_project_labeled.returncode == 0
            and result_project_labeled.stdout.strip()
        ):
            project_labeled_images = [
                img_id.strip()
                for img_id in result_project_labeled.stdout.strip().split("\n")
                if img_id.strip()
            ]
            project_dangling_images.update(project_labeled_images)
            debug_print(
                f"Found {len(project_labeled_images)} dangling images with project.name label"
            )

        # Collect images from Docker Compose labeled strategy (fallback)
        if (
            result_compose_labeled.returncode == 0
            and result_compose_labeled.stdout.strip()
        ):
            compose_labeled_images = [
                img_id.strip()
                for img_id in result_compose_labeled.stdout.strip().split("\n")
                if img_id.strip()
            ]
            project_dangling_images.update(compose_labeled_images)
            debug_print(
                f"Found {len(compose_labeled_images)} dangling images with Docker Compose project label"
            )

        # Collect images from name pattern strategy
        if result_all_dangling.returncode == 0 and result_all_dangling.stdout.strip():
            lines = result_all_dangling.stdout.strip().split("\n")
            for line in lines:
                if line.strip():
                    parts = line.strip().split(" ", 1)
                    if len(parts) >= 2:
                        img_id, repo = parts[0], parts[1]
                        # Check if repository name contains our system name
                        if system_name.lower() in repo.lower() or repo.startswith(
                            system_name
                        ):
                            project_dangling_images.add(img_id)
                            debug_print(
                                f"Found dangling image by name pattern: {img_id} ({repo})"
                            )

        if not project_dangling_images:
            if verbose:
                debug_print(f"No dangling images found for project: {system_name}")
            return True

        project_dangling_list = list(project_dangling_images)

        if verbose:
            print_message(
                f"🧹 Removing {len(project_dangling_list)} dangling images for project '{system_name}'...",
                Colors.YELLOW,
            )

        # Remove project-specific dangling images
        if project_dangling_list:
            result = run_command(["docker", "rmi"] + project_dangling_list)
            if result.returncode == 0:
                if verbose:
                    print_message(
                        "✅ Project dangling images removed successfully", Colors.GREEN
                    )
                debug_print(
                    f"Successfully removed {len(project_dangling_list)} project dangling images"
                )
                return True
            else:
                if verbose:
                    print_warning("⚠️  Failed to remove some project dangling images")
                debug_print("Failed to remove project dangling images")
                return False

        return True

    except Exception as e:
        debug_print(f"Error during project dangling images cleanup: {e}")
        if verbose:
            print_warning(f"⚠️  Error cleaning project dangling images: {e}")
        return False


def cleanup_dangling_images(verbose: bool = True) -> bool:
    """Clean up dangling Docker images (fallback to project-specific cleanup)"""
    debug_print("Starting dangling images cleanup")

    # Use project-specific cleanup by default
    return cleanup_project_dangling_images(verbose)


def auto_cleanup_images_before_build() -> bool:
    """Automatically clean up dangling images before building new ones"""
    debug_print("Running automatic image cleanup before build")

    # Always clean dangling images before build to prevent accumulation
    return cleanup_dangling_images(verbose=False)


def cleanup_docker_resources(service: str = "", cleanup_all: bool = False) -> bool:
    """Clean up Docker resources"""
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
