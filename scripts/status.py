#!/usr/bin/env python3
"""
status.py - Comprehensive service diagnostics script

Check the status of the Telegram bot service and provide comprehensive diagnostics.
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path
from typing import List, Optional

# Add the scripts/modules directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))

from output import Colors

def print_message(message: str, color: str = Colors.NC):
    """Print a formatted message with optional color"""
    print(f"{color}{message}{Colors.NC}")

def print_section(title: str):
    """Print a section header"""
    print(f"\n{Colors.BLUE}=== {title} ==={Colors.NC}")

def debug_print(message: str):
    """Print debug message if debug mode is enabled"""
    if os.getenv("DEBUG", "0") == "1" or os.getenv("VERBOSE", "0") == "1":
        print(f"DEBUG: {message}", file=sys.stderr)

def run_command(cmd: List[str], capture_output: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the result"""
    try:
        return subprocess.run(cmd, capture_output=capture_output, text=True, check=False)
    except Exception as e:
        debug_print(f"Command failed: {' '.join(cmd)}, error: {e}")
        return subprocess.CompletedProcess(cmd, 1, "", str(e))

def check_docker_compose_service():
    """Check Docker Compose service status"""
    debug_print("Starting Docker Compose service status check")
    print_section("Docker Compose Service Status")
    
    # Check if docker-compose.yml exists
    compose_file = Path("docker-compose.yml")
    if compose_file.exists():
        print_message("✅ Configuration file exists: docker-compose.yml", Colors.GREEN)
        
        # Check running services
        result = run_command(["docker-compose", "ps", "--services", "--filter", "status=running"])
        running_services = result.stdout.strip().split('\n') if result.stdout.strip() else []
        
        # Check all services
        result_all = run_command(["docker-compose", "ps", "--services"])
        all_services = result_all.stdout.strip().split('\n') if result_all.stdout.strip() else []
        
        if running_services and running_services[0]:
            print_message(f"✅ Services running: {', '.join(running_services)}", Colors.GREEN)
            
            # Show full compose status
            print_message("\nFull Docker Compose status:", Colors.BLUE)
            subprocess.run(["docker-compose", "ps"])
        else:
            print_message("❌ Service status: NOT RUNNING", Colors.RED)
            if all_services and all_services[0]:
                print_message(f"   Available services: {', '.join(all_services)}", Colors.RED)
    else:
        print_message("❌ Configuration file not found: docker-compose.yml", Colors.RED)
        print_message("   Service is not configured for Docker Compose", Colors.RED)
    
    debug_print("Docker Compose service check completed")

def check_docker_containers():
    """Check Docker containers"""
    debug_print("Starting Docker containers check")
    print_section("Docker Containers")
    
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    debug_print(f"Searching for containers with name: {system_name}")
    
    result = run_command(["docker", "ps", "-a", "--filter", f"name={system_name}", "--format", "{{.Names}}"])
    containers = result.stdout.strip().split('\n') if result.stdout.strip() else []
    
    if not containers or not containers[0]:
        debug_print("No containers found")
        print_message(f"No {system_name} containers found", Colors.YELLOW)
    else:
        debug_print(f"Found containers: {containers}")
        print_message("Found containers:", Colors.GREEN)
        subprocess.run([
            "docker", "ps", "-a", "--filter", f"name={system_name}",
            "--format", "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
        ])
        
        # Show resource usage for running containers
        result = run_command(["docker", "ps", "-q", "--filter", f"name={system_name}"])
        running_containers = result.stdout.strip().split('\n') if result.stdout.strip() else []
        
        if running_containers and running_containers[0]:
            print_message("\nContainer resource usage:", Colors.BLUE)
            cmd = ["docker", "stats", "--no-stream", "--format", 
                   "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"] + running_containers
            subprocess.run(cmd)
    
    debug_print("Docker containers check completed")

def check_docker_images():
    """Check Docker images"""
    debug_print("Starting Docker images check")
    print_section("Docker Images")
    
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    debug_print(f"Searching for images with name: {system_name}")
    
    result = run_command(["docker", "images", "--format", "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}", "--filter", f"reference={system_name}*"])
    
    if not result.stdout.strip():
        debug_print("No images found")
        print_message(f"No {system_name} images found", Colors.YELLOW)
    else:
        debug_print("Found images")
        print_message("Found images:", Colors.GREEN)
        print("REPOSITORY\tTAG\tIMAGE ID\tSIZE")
        print(result.stdout)
    
    debug_print("Docker images check completed")

def check_docker_volumes():
    """Check Docker volumes"""
    print_section("Docker Volumes")
    
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    result = run_command(["docker", "volume", "ls", "--format", "{{.Name}}", "--filter", f"name={system_name}"])
    volumes = result.stdout.strip().split('\n') if result.stdout.strip() else []
    
    if not volumes or not volumes[0]:
        print_message(f"No {system_name} volumes found", Colors.YELLOW)
    else:
        print_message("Found volumes:", Colors.GREEN)
        subprocess.run(["docker", "volume", "ls", "--filter", f"name={system_name}"])
        
        # Show volume details
        print_message("\nVolume details:", Colors.BLUE)
        for volume in volumes:
            if volume:
                print_message(f"Volume: {volume}", Colors.YELLOW)
                result = run_command(["docker", "volume", "inspect", volume, "--format", "{{.Mountpoint}}"])
                if result.returncode == 0:
                    print(f"  Mountpoint: {result.stdout.strip()}")
                
                result = run_command(["docker", "volume", "inspect", volume, "--format", "{{.CreatedAt}}"])
                if result.returncode == 0:
                    print(f"  Created: {result.stdout.strip()}")

def check_docker_networks():
    """Check Docker networks"""
    print_section("Docker Networks")
    
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    result = run_command(["docker", "network", "ls", "--format", "{{.Name}}", "--filter", f"name={system_name}"])
    networks = result.stdout.strip().split('\n') if result.stdout.strip() else []
    
    if not networks or not networks[0]:
        print_message(f"No custom {system_name} networks found", Colors.YELLOW)
    else:
        print_message("Found networks:", Colors.GREEN)
        subprocess.run(["docker", "network", "ls", "--filter", f"name={system_name}"])
    
    # Show container network connections
    result = run_command(["docker", "ps", "-q", "--filter", f"name={system_name}"])
    container_ids = result.stdout.strip().split('\n') if result.stdout.strip() else []
    
    if container_ids and container_ids[0]:
        print_message("\nContainer network details:", Colors.BLUE)
        for container_id in container_ids:
            if container_id:
                result = run_command([
                    "docker", "inspect", "--format",
                    '{{range $net, $config := .NetworkSettings.Networks}}Network: {{$net}}, IP: {{$config.IPAddress}}{{if $config.Aliases}}, Aliases: {{join $config.Aliases ", "}}{{end}}{{"\n"}}{{end}}',
                    container_id
                ])
                if result.returncode == 0:
                    print(result.stdout)

def check_project_files():
    """Check project files"""
    print_section("Project Files")
    
    # Check data directory
    data_dir = Path("./data")
    if data_dir.exists():
        print_message("✅ Data directory exists", Colors.GREEN)
        
        # Get directory size
        result = run_command(["du", "-sh", str(data_dir)])
        if result.returncode == 0:
            size = result.stdout.split()[0]
            print_message(f"   Size: {size}", Colors.YELLOW)
        
        # Count files
        try:
            file_count = len(list(data_dir.glob("**/*")))
            print_message(f"   Files: {file_count}", Colors.YELLOW)
        except Exception:
            print_message("   Files: Unable to count", Colors.YELLOW)
    else:
        print_message("❌ Data directory not found", Colors.YELLOW)
    
    # Check logs directory
    logs_dir = Path("./logs")
    if logs_dir.exists():
        print_message("✅ Logs directory exists", Colors.GREEN)
        
        # Get directory size
        result = run_command(["du", "-sh", str(logs_dir)])
        if result.returncode == 0:
            size = result.stdout.split()[0]
            print_message(f"   Size: {size}", Colors.YELLOW)
        
        # Count log files
        try:
            log_files = len(list(logs_dir.glob("*.log")))
            print_message(f"   Log files: {log_files}", Colors.YELLOW)
        except Exception:
            print_message("   Log files: Unable to count", Colors.YELLOW)
    else:
        print_message("❌ Logs directory not found", Colors.YELLOW)
    
    # Check Docker compose files
    if Path("docker-compose.yml").exists():
        print_message("✅ docker-compose.yml exists", Colors.GREEN)
    else:
        print_message("❌ docker-compose.yml not found", Colors.RED)
    
    if Path("docker-compose.override.yml").exists():
        print_message("✅ docker-compose.override.yml exists", Colors.GREEN)
    
    # Check Dockerfile
    if Path("Dockerfile").exists():
        print_message("✅ Dockerfile exists", Colors.GREEN)
    else:
        print_message("❌ Dockerfile not found", Colors.RED)
    
    # Check .env file
    if Path(".env").exists():
        print_message("✅ .env file exists", Colors.GREEN)
    else:
        print_message("❌ .env file not found", Colors.YELLOW)

def check_bot_health():
    """Check bot health using monitor"""
    print_section("Bot Health Status")
    
    health_script = Path("scripts/monitor.py")
    if health_script.exists():
        try:
            result = subprocess.run(
                ["python", str(health_script), "--mode", "status"],
                capture_output=False
            )
            return result.returncode == 0
        except Exception as e:
            print_message(f"❌ Health check failed: {e}", Colors.RED)
            return False
    else:
        print_message("❌ Health monitor script not found", Colors.RED)
        return False

def show_summary():
    """Show diagnostic summary"""
    print_section("Diagnostic Summary")
    
    system_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
    
    # Quick status check
    result = run_command(["docker", "ps", "-q", "--filter", f"name={system_name}"])
    is_running = bool(result.stdout.strip())
    
    if is_running:
        print_message("🟢 Overall Status: RUNNING", Colors.GREEN)
    else:
        print_message("🔴 Overall Status: STOPPED", Colors.RED)
    
    # Recommendations
    print_message("\n📋 Recommendations:", Colors.BLUE)
    
    if not is_running:
        print_message("  • Start the bot: python scripts/start.py", Colors.BLUE)
    else:
        print_message("  • View logs: docker-compose logs -f bot", Colors.BLUE)
        print_message("  • Check health: python scripts/monitor.py --mode monitor", Colors.BLUE)
    
    print_message("  • Full management: python scripts/manage.py help", Colors.BLUE)

def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description="Check the status of the Telegram bot service and provide comprehensive diagnostics"
    )
    
    parser.add_argument("--debug", action="store_true", help="Enable debug output")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    
    args = parser.parse_args()
    
    # Set environment variables
    if args.debug:
        os.environ["DEBUG"] = "1"
    if args.verbose:
        os.environ["VERBOSE"] = "1"
    
    # Load environment
    env_file = Path(".env")
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    value = value.strip('"\'')
                    os.environ[key] = value
    
    # Change to project root
    project_root = Path(__file__).parent.parent.absolute()
    os.chdir(project_root)
    
    try:
        print_message("🔍 Comprehensive Service Diagnostics", Colors.BLUE)
        print_message("=" * 50, Colors.BLUE)
        
        # Run all checks
        check_docker_compose_service()
        check_docker_containers()
        check_docker_images()
        check_docker_volumes()
        check_docker_networks()
        check_project_files()
        check_bot_health()
        show_summary()
        
        print_message("\n✅ Diagnostic check completed", Colors.GREEN)
        
    except KeyboardInterrupt:
        print_message("\n🛑 Diagnostics cancelled by user", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        print_message(f"❌ Unexpected error: {e}", Colors.RED)
        if args.debug:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main() 