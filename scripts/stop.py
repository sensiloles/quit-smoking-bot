#!/usr/bin/env python3
"""
stop.py - Universal bot stop script

This script can either stop the bot (default) or completely uninstall it (--uninstall).
Supports dry-run mode to preview actions before execution.
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path
from typing import List

# Add the scripts/modules directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))

from output import Colors

def print_message(message: str, color: str = Colors.NC):
    """Print a formatted message with optional color"""
    print(f"{color}{message}{Colors.NC}")

def debug_print(message: str):
    """Print debug message if debug mode is enabled"""
    if os.getenv("DEBUG", "0") == "1" or os.getenv("VERBOSE", "0") == "1":
        print(f"DEBUG: {message}", file=sys.stderr)

def is_dry_run() -> bool:
    """Check if we're in dry-run mode"""
    return os.getenv("DRY_RUN", "0") == "1"

def execute_or_simulate(description: str, command: List[str]) -> bool:
    """Execute command or simulate if in dry-run mode"""
    if is_dry_run():
        print_message(f"🔍 [DRY-RUN] Would execute: {description}", Colors.YELLOW)
        print_message(f"    Command: {' '.join(command)}", Colors.YELLOW)
        return True
    else:
        print_message(f"🔧 {description}...", Colors.BLUE)
        try:
            result = subprocess.run(command, check=True, capture_output=True, text=True)
            print_message(f"✅ {description} completed", Colors.GREEN)
            return True
        except subprocess.CalledProcessError as e:
            print_message(f"❌ {description} failed: {e}", Colors.RED)
            if e.stderr:
                print_message(f"Error details: {e.stderr}", Colors.RED)
            return False

def stop_services(stop_all: bool = False) -> bool:
    """Stop Docker Compose services"""
    command = ["docker-compose"]
    
    if stop_all:
        command.extend(["--profile", "monitoring", "--profile", "logging"])
    
    command.extend(["down", "--remove-orphans"])
    
    return execute_or_simulate("Stop Docker Compose services", command)

def remove_images() -> bool:
    """Remove Docker images"""
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    
    if is_dry_run():
        print_message("🔍 [DRY-RUN] Would remove bot Docker images", Colors.YELLOW)
        return True
    
    print_message("🔧 Removing bot Docker images...", Colors.BLUE)
    
    try:
        # Find images
        result = subprocess.run(
            ["docker", "images", "-q", f"{system_name}*"],
            capture_output=True,
            text=True
        )
        
        images = result.stdout.strip().split('\n') if result.stdout.strip() else []
        
        if images and images[0]:
            # Remove images
            subprocess.run(["docker", "rmi"] + images, check=True)
            print_message("✅ Docker images removed", Colors.GREEN)
        else:
            print_message("ℹ️  No images found to remove", Colors.YELLOW)
        
        return True
        
    except subprocess.CalledProcessError as e:
        print_message(f"⚠️  Some images could not be removed: {e}", Colors.YELLOW)
        return True  # Don't fail the whole process

def cleanup_docker_resources() -> bool:
    """Cleanup Docker resources"""
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    success = True
    
    # Clean up remaining containers
    try:
        if not is_dry_run():
            result = subprocess.run(
                ["docker", "ps", "-a", "-q", "--filter", f"name={system_name}"],
                capture_output=True,
                text=True
            )
            containers = result.stdout.strip().split('\n') if result.stdout.strip() else []
            
            if containers and containers[0]:
                subprocess.run(["docker", "rm", "-f"] + containers)
                print_message("✅ Remaining containers removed", Colors.GREEN)
        else:
            print_message("🔍 [DRY-RUN] Would remove remaining containers", Colors.YELLOW)
    except subprocess.CalledProcessError:
        print_message("⚠️  Some containers could not be removed", Colors.YELLOW)
    
    # Clean up networks
    try:
        if not is_dry_run():
            result = subprocess.run(
                ["docker", "network", "ls", "-q", "--filter", f"name={system_name}"],
                capture_output=True,
                text=True
            )
            networks = result.stdout.strip().split('\n') if result.stdout.strip() else []
            
            if networks and networks[0]:
                subprocess.run(["docker", "network", "rm"] + networks)
                print_message("✅ Docker networks removed", Colors.GREEN)
        else:
            print_message("🔍 [DRY-RUN] Would remove Docker networks", Colors.YELLOW)
    except subprocess.CalledProcessError:
        print_message("⚠️  Some networks could not be removed", Colors.YELLOW)
    
    # Clean up volumes
    try:
        if not is_dry_run():
            result = subprocess.run(
                ["docker", "volume", "ls", "-q"],
                capture_output=True,
                text=True
            )
            
            all_volumes = result.stdout.strip().split('\n') if result.stdout.strip() else []
            volumes = [v for v in all_volumes if system_name.lower() in v.lower()]
            
            if volumes:
                subprocess.run(["docker", "volume", "rm"] + volumes)
                print_message("✅ Docker volumes removed", Colors.GREEN)
        else:
            print_message("🔍 [DRY-RUN] Would remove Docker volumes", Colors.YELLOW)
    except subprocess.CalledProcessError:
        print_message("⚠️  Some volumes could not be removed", Colors.YELLOW)
    
    # General Docker cleanup
    success &= execute_or_simulate("Docker system cleanup", ["docker", "system", "prune", "-f"])
    
    return success

def confirm_action(action: str, force: bool = False, dangerous: bool = False) -> bool:
    """Show confirmation dialog"""
    if force or is_dry_run():
        return True
    
    system_display_name = os.getenv("SYSTEM_DISPLAY_NAME", "Quit Smoking Bot")
    
    print_message("")
    print_message(f"This will {action} {system_display_name}.", Colors.YELLOW)
    
    if dangerous:
        print_message("⚠️  WARNING: This action may result in data loss!", Colors.RED)
    
    print_message("")
    try:
        response = input("Are you sure you want to proceed? (y/N): ").strip().lower()
        return response in ['y', 'yes']
    except KeyboardInterrupt:
        print_message("\n❌ Operation cancelled", Colors.YELLOW)
        return False

def show_final_status(uninstall_mode: bool = False):
    """Show final status"""
    if is_dry_run():
        return
    
    print_message("\n📊 Final Status:", Colors.BLUE)
    
    # Check for remaining containers
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", f"name={system_name}", "--format", "table {{.Names}}\t{{.Status}}"],
            capture_output=True,
            text=True
        )
        
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1 and lines[1]:  # More than just header
            print_message("Still running:", Colors.YELLOW)
            print(result.stdout)
        else:
            print_message("✅ All bot services stopped", Colors.GREEN)
    except subprocess.CalledProcessError:
        print_message("✅ All bot services stopped", Colors.GREEN)
    
    if uninstall_mode:
        print_message("\n🗑️  Uninstall Summary:", Colors.GREEN)
        print_message("  ✓ Docker Compose services removed", Colors.GREEN)
        print_message("  ✓ Docker images removed", Colors.GREEN)
        print_message("  ✓ Docker resources cleaned up", Colors.GREEN)
        print_message("")
        
        project_root = Path(__file__).parent.parent.absolute()
        print_message(f"ℹ️  Note: Project source code remains in {project_root}", Colors.BLUE)
        print_message("ℹ️  You can reinstall with: python scripts/start.py --install", Colors.BLUE)
    else:
        print_message("\n📋 Next steps:", Colors.BLUE)
        print_message("  Start bot:    python scripts/start.py", Colors.BLUE)
        print_message("  View logs:    docker-compose logs bot", Colors.BLUE)
        print_message("  Full cleanup: python scripts/stop.py --uninstall", Colors.BLUE)

def load_env():
    """Load environment variables from .env file"""
    env_file = Path(".env")
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    value = value.strip('"\'')
                    os.environ[key] = value

def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description="Universal script to stop or uninstall the Telegram bot"
    )
    
    parser.add_argument(
        "--uninstall",
        action="store_true",
        help="Complete uninstallation (removes images and cleans Docker)"
    )
    
    parser.add_argument(
        "--all",
        action="store_true",
        help="Stop all services including monitoring and logging"
    )
    
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without executing"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Skip confirmation prompts"
    )
    
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Minimal output (errors only)"
    )
    
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Detailed output and debugging"
    )
    
    args = parser.parse_args()
    
    # Set environment variables
    if args.dry_run:
        os.environ["DRY_RUN"] = "1"
    if args.verbose:
        os.environ["VERBOSE"] = "1"
    if args.quiet:
        os.environ["QUIET"] = "1"
    
    # Load environment
    load_env()
    
    # Change to project root
    project_root = Path(__file__).parent.parent.absolute()
    os.chdir(project_root)
    
    try:
        debug_print(f"Starting universal stop script with uninstall={args.uninstall}")
        
        # Determine action
        if args.uninstall:
            action = "completely uninstall"
            dangerous = True
        else:
            action = "stop"
            dangerous = False
        
        # Confirm action
        if not confirm_action(action, args.force, dangerous):
            sys.exit(0)
        
        print_message("🛑 Stopping bot services...", Colors.BLUE)
        
        # Stop services
        success = stop_services(args.all)
        
        # If uninstalling, do additional cleanup
        if args.uninstall and success:
            print_message("🗑️  Starting uninstall cleanup...", Colors.BLUE)
            remove_images()
            cleanup_docker_resources()
        
        # Show final status
        show_final_status(args.uninstall)
        
        if success:
            print_message("\n🎉 Operation completed successfully!", Colors.GREEN)
        else:
            print_message("\n⚠️  Operation completed with some warnings", Colors.YELLOW)
            sys.exit(1)
        
    except KeyboardInterrupt:
        print_message("\n🛑 Operation cancelled by user", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        print_message(f"❌ Unexpected error: {e}", Colors.RED)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main() 