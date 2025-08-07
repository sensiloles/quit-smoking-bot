"""
actions.py - Action handlers and core operations

This module provides action handlers for bot management operations.
"""

import os
import subprocess
import time
from pathlib import Path
from typing import Optional

from .docker_utils import (
    auto_cleanup_images_before_build,
    check_docker_installation,
    cleanup_dangling_images,
    cleanup_docker_resources,
    get_container_status,
)
from .environment import check_bot_token, get_system_name, is_dry_run, update_env_token
from .errors import BotError, DockerError, ErrorContext
from .health import check_bot_status, comprehensive_health_check, is_bot_operational
from .output import (
    Colors,
    debug_print,
    print_error,
    print_message,
    print_success,
    print_warning,
)


def action_setup(token: Optional[str] = None) -> bool:
    """Setup the bot environment"""
    debug_print("Starting setup action")

    with ErrorContext("Bot setup"):
        print_message("🚀 Setting up Quit Smoking Bot...", Colors.BLUE)

        # Step 1: Check Docker installation
        print_message("Step 1: Checking Docker installation...", Colors.YELLOW)
        if not check_docker_installation():
            raise DockerError("Docker is not properly installed or running")
        print_success("✅ Docker is ready")

        # Step 2: Setup environment
        print_message("Step 2: Setting up environment...", Colors.YELLOW)
        if token:
            debug_print("Token provided, updating .env file")
            if not update_env_token(token):
                raise BotError("Failed to update BOT_TOKEN")
            print_success("✅ BOT_TOKEN configured")
        elif not check_bot_token():
            raise BotError("BOT_TOKEN is not configured. Please provide a token.")
        else:
            print_success("✅ BOT_TOKEN already configured")

        # Step 3: Create necessary directories
        print_message("Step 3: Creating directories...", Colors.YELLOW)
        for dir_name in ["data", "logs", "backups"]:
            dir_path = Path(dir_name)
            dir_path.mkdir(exist_ok=True)
            debug_print(f"Created directory: {dir_name}")
        print_success("✅ Directories created")

        # Step 4: Set permissions
        print_message("Step 4: Setting up permissions...", Colors.YELLOW)
        from .system import setup_permissions

        if not setup_permissions():
            print_warning("⚠️  Permission setup had issues, but continuing...")
        else:
            print_success("✅ Permissions configured")

        print_success("🎉 Setup completed successfully!")
        print_message(
            "You can now start the bot with: python scripts/start.py start",
            Colors.GREEN,
        )

        return True


def action_start(
    dry_run: bool = False,
    force_rebuild: bool = False,
    enable_monitoring: bool = False,
    enable_logging: bool = False,
) -> bool:
    """Start the bot service"""
    debug_print(f"Starting bot, dry_run: {dry_run}")

    with ErrorContext("Bot start"):
        print_message(f"🚀 Starting {get_system_name()}...", Colors.BLUE)

        # Check if already running
        status = get_container_status()
        if status["running"]:
            print_warning("Bot is already running!")
            print_message("Container status:", Colors.YELLOW)
            subprocess.run(
                ["docker-compose", "-f", "docker/docker-compose.yml", "ps"],
                check=False,
                capture_output=False,
            )
            return True

        # Check Docker
        if not check_docker_installation():
            raise DockerError("Docker is not properly installed or running")

        # Check environment
        if not check_bot_token():
            raise BotError("BOT_TOKEN is not configured")

        # Clean up dangling images before build to prevent accumulation
        print_message("Cleaning up dangling images before build...", Colors.YELLOW)
        auto_cleanup_images_before_build()

        # Build containers if needed
        if force_rebuild:
            print_message("Force rebuilding Docker containers...", Colors.YELLOW)
            build_cmd = [
                "docker-compose",
                "-f",
                "docker/docker-compose.yml",
                "build",
                "--no-cache",
            ]
            if dry_run or is_dry_run():
                print_message(
                    f"DRY RUN: Would execute: {' '.join(build_cmd)}",
                    Colors.YELLOW,
                )
            else:
                result = subprocess.run(build_cmd, check=False, capture_output=False)
                if result.returncode != 0:
                    raise DockerError("Failed to rebuild containers")

                # Clean up dangling images after rebuild
                print_message(
                    "Cleaning up dangling images after rebuild...", Colors.YELLOW
                )
                cleanup_dangling_images(verbose=False)

        # Determine compose profiles
        compose_profiles = []
        if enable_monitoring:
            compose_profiles.append("monitoring")
        if enable_logging:
            compose_profiles.append("logging")

        # Prepare environment variables for docker-compose
        env = os.environ.copy()

        if dry_run or is_dry_run():
            profiles_str = " ".join(f"--profile {p}" for p in compose_profiles)
            print_message(
                "DRY RUN: Would start bot with the following command:",
                Colors.YELLOW,
            )
            print_message(f"docker-compose {profiles_str} up -d --build", Colors.YELLOW)
            return True

        # Start the service
        print_message("Starting bot container...", Colors.YELLOW)
        cmd = ["docker-compose", "-f", "docker/docker-compose.yml"]

        # Add profiles for additional services
        for profile_name in compose_profiles:
            cmd.extend(["--profile", profile_name])
        cmd.extend(["up", "-d", "--build"])

        result = subprocess.run(cmd, check=False, env=env, capture_output=False)
        if result.returncode != 0:
            raise DockerError("Failed to start bot container", " ".join(cmd))

        # Clean up dangling images after container build/start
        print_message(
            "Cleaning up dangling images after container start...", Colors.YELLOW
        )
        cleanup_dangling_images(verbose=False)

        # Check status after startup
        print_message("Checking bot status after startup...", Colors.YELLOW)
        status = check_bot_status()

        if status["bot_operational"]:
            print_success("🎉 Bot started successfully!")
            return True
        print_warning("⚠️  Bot started but may not be fully operational")
        print_message(
            "Check logs with: docker-compose -f docker/docker-compose.yml logs bot",
            Colors.YELLOW,
        )
        return False


def action_stop(confirm: bool = False) -> bool:
    """Stop the bot service"""
    debug_print("Stopping bot service")

    with ErrorContext("Bot stop"):
        # Check if running
        status = get_container_status()
        if not status["running"]:
            print_message("Bot is not running", Colors.YELLOW)
            return True

        if not confirm:
            print_message("This will stop the bot service.", Colors.YELLOW)
            response = input("Are you sure? (y/N): ").strip().lower()
            if response not in ["y", "yes"]:
                print_message("Operation cancelled", Colors.YELLOW)
                return True

        print_message("🛑 Stopping bot...", Colors.YELLOW)

        result = subprocess.run(
            ["docker-compose", "-f", "docker/docker-compose.yml", "down"],
            check=False,
            capture_output=False,
        )
        if result.returncode != 0:
            raise DockerError("Failed to stop bot container")

        print_success("✅ Bot stopped successfully")
        return True


def action_restart() -> bool:
    """Restart the bot service"""
    debug_print("Restarting bot")

    print_message("🔄 Restarting bot...", Colors.BLUE)

    # Stop first
    if not action_stop(confirm=True):
        return False

    # Clean up dangling images during restart
    print_message("Cleaning up dangling images during restart...", Colors.YELLOW)
    cleanup_dangling_images(verbose=False)

    # Wait a moment
    time.sleep(2)

    # Start again
    return action_start()


def action_status() -> bool:
    """Show comprehensive bot status with monitoring and diagnostics"""
    debug_print("Checking bot status with full diagnostics")

    print_message("📊 Comprehensive Bot Status & Diagnostics", Colors.BLUE)
    return _run_comprehensive_status()


def _run_comprehensive_status() -> bool:
    """Run comprehensive status check with all monitoring and diagnostics"""
    total_checks = 0
    failed_checks = 0

    # === BASIC STATUS ===
    print_message("\n🔋 Basic Status Check:", Colors.BLUE)

    # Check container status
    status = get_container_status()

    if not status["exists"]:
        print_message("❌ No bot containers found", Colors.RED)
        print_message(
            "Run 'python scripts/start.py start' to start the bot",
            Colors.YELLOW,
        )
        return True

    if status["running"]:
        print_message("✅ Bot container is running", Colors.GREEN)

        # Show container info
        print_message("\n📋 Container Status:", Colors.BLUE)
        subprocess.run(
            ["docker-compose", "-f", "docker/docker-compose.yml", "ps"],
            check=False,
            capture_output=False,
        )

        # Check operational status
        if is_bot_operational():
            print_message("\n✅ Bot is operational", Colors.GREEN)
        else:
            print_message(
                "\n⚠️  Bot is running but may not be operational",
                Colors.YELLOW,
            )

        # Show recent logs
        print_message("\n📝 Recent Logs:", Colors.BLUE)
        subprocess.run(
            [
                "docker-compose",
                "-f",
                "docker/docker-compose.yml",
                "logs",
                "--tail",
                "10",
                "bot",
            ],
            check=False,
            capture_output=False,
        )

    else:
        print_message("❌ Bot container is not running", Colors.RED)
        print_message(
            "Run 'python scripts/start.py start' to start the bot",
            Colors.YELLOW,
        )

    # === HEALTH MONITORING ===
    print_message("\n🏥 Health Monitoring:", Colors.BLUE)
    total_checks += 1
    if comprehensive_health_check():
        print_message("✅ Health checks passed", Colors.GREEN)
    else:
        print_message("❌ Health checks failed", Colors.RED)
        failed_checks += 1

    # === CONTAINER DIAGNOSTICS ===
    if status["running"]:
        try:
            subprocess.run(["docker", "--version"], capture_output=True, check=True)
            print_message("\n🐳 Container Diagnostics:", Colors.BLUE)
            total_checks += 1

            from .environment import get_system_name

            container_name = get_system_name()
            if container_name:
                result = subprocess.run(
                    [
                        "docker",
                        "ps",
                        "--format",
                        "{{.Names}}",
                        "--filter",
                        f"name={container_name}",
                    ],
                    check=False,
                    capture_output=True,
                    text=True,
                )

                if container_name in result.stdout:
                    print_message("✅ Container is running", Colors.GREEN)

                    # Show container details
                    print_message("\n📊 Container Details:", Colors.YELLOW)
                    subprocess.run(
                        [
                            "docker",
                            "ps",
                            "--filter",
                            f"name={container_name}",
                            "--format",
                            "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}",
                        ],
                        check=False,
                    )

                    # Show resource usage
                    print_message("\n💻 Resource Usage:", Colors.YELLOW)
                    result = subprocess.run(
                        [
                            "docker",
                            "stats",
                            "--no-stream",
                            "--format",
                            "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}",
                            container_name,
                        ],
                        check=False,
                        capture_output=True,
                        text=True,
                    )
                    if result.returncode == 0 and result.stdout.strip():
                        print(result.stdout)
                    else:
                        print_message("Resource usage not available", Colors.YELLOW)
                else:
                    print_message("❌ Container is not running", Colors.RED)
                    failed_checks += 1

        except subprocess.CalledProcessError:
            print_message("⚠️  Docker not available", Colors.YELLOW)
        except Exception as e:
            print_message(f"❌ Container diagnostics error: {e}", Colors.RED)
            failed_checks += 1

    # === FINAL SUMMARY ===
    print_message("\n📋 Status Summary:", Colors.BLUE)
    print_message(f"Total checks: {total_checks}", Colors.BLUE)
    print_message(f"Passed: {total_checks - failed_checks}", Colors.GREEN)
    print_message(f"Failed: {failed_checks}", Colors.RED)

    if failed_checks == 0:
        print_message("\n🎉 All systems operational!", Colors.GREEN)
    else:
        print_message(
            f"\n⚠️  {failed_checks} check(s) failed - see details above", Colors.YELLOW
        )

    return True


def action_logs(follow: bool = False, lines: int = 50) -> bool:
    """Show bot logs"""
    debug_print(f"Showing logs, follow: {follow}, lines: {lines}")

    # Check if container exists
    status = get_container_status()
    if not status["exists"]:
        print_error("No bot containers found")
        return False

    print_message(f"📋 Bot Logs (last {lines} lines):", Colors.BLUE)

    cmd = [
        "docker-compose",
        "-f",
        "docker/docker-compose.yml",
        "logs",
        "--tail",
        str(lines),
    ]
    if follow:
        cmd.append("-f")
    cmd.append("bot")

    try:
        subprocess.run(cmd, check=False, capture_output=False)
        return True
    except KeyboardInterrupt:
        print_message("\n🛑 Log viewing interrupted", Colors.YELLOW)
        return True


def action_cleanup(service: str = "", full: bool = False) -> bool:
    """Clean up Docker resources"""
    debug_print(f"Cleaning up resources, service: {service}, full: {full}")

    print_message("🧹 Cleaning up Docker resources...", Colors.YELLOW)

    if not full:
        response = (
            input("This will remove containers and images. Continue? (y/N): ")
            .strip()
            .lower()
        )
        if response not in ["y", "yes"]:
            print_message("Operation cancelled", Colors.YELLOW)
            return True

    return cleanup_docker_resources(service, full)


def action_prune(confirm: bool = False) -> bool:
    """Remove all bot data, logs, and containers"""
    debug_print("Cleaning up all bot data")

    if not confirm:
        print_message(
            "⚠️  This will remove all bot data, logs, and containers!",
            Colors.RED,
        )
        print_message("This action cannot be undone.", Colors.RED)
        response = (
            input("Are you sure you want to continue? (Yes/No): ").strip().lower()
        )
        if response not in ["yes", "y"]:
            print_message("Operation cancelled", Colors.YELLOW)
            return True

    with ErrorContext("Bot cleanup"):
        print_message("🧹 Cleaning up bot data...", Colors.YELLOW)

        # Stop everything
        print_message("Stopping all services...", Colors.YELLOW)
        subprocess.run(
            [
                "docker-compose",
                "-f",
                "docker/docker-compose.yml",
                "down",
                "-v",
                "--remove-orphans",
            ],
            check=False,
            capture_output=False,
        )

        # Remove images
        print_message("Removing Docker images...", Colors.YELLOW)
        cleanup_docker_resources(cleanup_all=True)

        # Force remove project images directly
        try:
            # Get all quit-smoking-bot images
            result = subprocess.run(
                ["docker", "images", "--filter", "reference=quit-smoking-bot*", "-q"],
                capture_output=True,
                text=True,
                check=False,
            )

            if result.stdout.strip():
                image_ids = result.stdout.strip().split("\n")
                for image_id in image_ids:
                    if image_id.strip():
                        subprocess.run(
                            ["docker", "rmi", "-f", image_id.strip()],
                            capture_output=True,
                            check=False,
                        )
                        debug_print(f"Force removed Docker image: {image_id.strip()}")
                print_message("Force removed project Docker images", Colors.GREEN)
        except Exception as e:
            debug_print(f"Warning: Could not force remove project images: {e}")

        # Clean logs directory
        print_message("Cleaning logs directory...", Colors.YELLOW)
        logs_path = Path("logs")
        if logs_path.exists():
            import shutil

            shutil.rmtree(logs_path)
            debug_print("Removed logs directory")

        print_success("✅ Bot data cleanup completed!")
        print_message(
            "Run 'python scripts/start.py --install' to initialize again",
            Colors.GREEN,
        )
        return True


def action_backup() -> bool:
    """Backup bot data"""
    debug_print("Creating backup")

    with ErrorContext("Bot backup"):
        print_message("💾 Creating backup...", Colors.BLUE)

        # Create backup directory
        backup_dir = Path("backups")
        backup_dir.mkdir(exist_ok=True)

        # Create timestamped backup
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        backup_name = f"bot_backup_{timestamp}.tar.gz"
        backup_path = backup_dir / backup_name

        # Create backup archive
        print_message("Creating backup archive...", Colors.YELLOW)
        cmd = [
            "tar",
            "czf",
            str(backup_path),
            "--exclude=backups",
            "--exclude=logs/*.log",
            "data",
            "logs",
            ".env",
        ]

        result = subprocess.run(cmd, check=False, capture_output=True, text=True)
        if result.returncode != 0:
            raise BotError(f"Failed to create backup: {result.stderr}")

        print_success(f"✅ Backup created: {backup_path}")
        return True
