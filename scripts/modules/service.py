"""
service.py - Service management utilities

This module provides functions for managing bot services,
including starting, stopping, and checking service status.
"""

import os
import subprocess
import time
from typing import Dict, Any, Optional

from .output import print_error, print_message, print_warning, debug_print, Colors, print_success
from .environment import get_system_name, is_dry_run
from .docker_utils import run_command, get_container_status
from .errors import ServiceError, BotError, ErrorContext

def get_service_status() -> Dict[str, Any]:
    """Get comprehensive service status"""
    debug_print("Getting service status")
    
    status = {
        "docker_running": False,
        "containers": {},
        "services": {},
        "healthy": False
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
    result = run_command(["docker-compose", "ps", "--services"])
    if result.returncode == 0:
        services = [s.strip() for s in result.stdout.split('\n') if s.strip()]
        for service in services:
            service_result = run_command(["docker-compose", "ps", service])
            is_running = "Up" in service_result.stdout
            status["services"][service] = {
                "running": is_running,
                "status": "healthy" if is_running else "stopped"
            }
    
    # Overall health
    status["healthy"] = (
        status["docker_running"] and
        container_status.get("running", False) and
        container_status.get("healthy", False)
    )
    
    return status

def start_service(service: str = "bot", profile: str = "prod") -> bool:
    """Start a specific service"""
    debug_print(f"Starting service: {service} with profile: {profile}")
    
    with ErrorContext(f"Starting service {service}"):
        if is_dry_run():
            print_message(f"DRY RUN: Would start service {service}", Colors.YELLOW)
            return True
        
        # Prepare environment
        env = os.environ.copy()
        env["COMPOSE_PROFILES"] = profile
        
        print_message(f"🚀 Starting service: {service}", Colors.BLUE)
        
        # Start the service
        cmd = ["docker-compose", "up", "-d"]
        if service != "all":
            cmd.append(service)
        
        result = subprocess.run(cmd, env=env, capture_output=False)
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
            cmd = ["docker-compose", "down"]
            if cleanup:
                cmd.extend(["-v", "--remove-orphans"])
        else:
            cmd = ["docker-compose", "stop", service]
        
        result = subprocess.run(cmd, capture_output=False)
        if result.returncode != 0:
            raise ServiceError(f"Failed to stop service {service}")
        
        print_success(f"✅ Service {service} stopped successfully")
        return True

def restart_service(service: str = "bot", profile: str = "prod") -> bool:
    """Restart a specific service"""
    debug_print(f"Restarting service: {service}")
    
    print_message(f"🔄 Restarting service: {service}", Colors.BLUE)
    
    # Stop first
    if not stop_service(service):
        return False
    
    # Wait a moment
    time.sleep(2)
    
    # Start again
    return start_service(service, profile)

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
            result = run_command(["docker-compose", "ps", "-q", "bot"])
            container_id = result.stdout.strip()
            
            if container_id:
                # Check health status
                result = run_command([
                    "docker", "inspect", "--format", "{{.State.Health.Status}}", 
                    container_id
                ])
                health_status = result.stdout.strip()
                
                if health_status == "healthy":
                    debug_print(f"Service {service} is healthy")
                    return True
                elif health_status == "starting":
                    debug_print(f"Service {service} is starting...")
                    time.sleep(5)
                    continue
                else:
                    debug_print(f"Service {service} health check failed: {health_status}")
                    time.sleep(2)
                    continue
        else:
            # For other services, just check if running
            return True
    
    debug_print(f"Timeout waiting for service {service} to be ready")
    return False

def scale_service(service: str, replicas: int) -> bool:
    """Scale a service to specific number of replicas"""
    debug_print(f"Scaling service {service} to {replicas} replicas")
    
    with ErrorContext(f"Scaling service {service}"):
        if is_dry_run():
            print_message(f"DRY RUN: Would scale {service} to {replicas} replicas", Colors.YELLOW)
            return True
        
        print_message(f"📊 Scaling {service} to {replicas} replicas...", Colors.BLUE)
        
        cmd = ["docker-compose", "up", "-d", "--scale", f"{service}={replicas}"]
        result = subprocess.run(cmd, capture_output=False)
        
        if result.returncode != 0:
            raise ServiceError(f"Failed to scale service {service}")
        
        print_success(f"✅ Service {service} scaled to {replicas} replicas")
        return True

def get_service_logs(service: str, lines: int = 50, follow: bool = False) -> bool:
    """Get logs for a specific service"""
    debug_print(f"Getting logs for service {service}, lines: {lines}, follow: {follow}")
    
    cmd = ["docker-compose", "logs", "--tail", str(lines)]
    if follow:
        cmd.append("-f")
    cmd.append(service)
    
    try:
        subprocess.run(cmd, capture_output=False)
        return True
    except KeyboardInterrupt:
        print_message("\n🛑 Log viewing interrupted", Colors.YELLOW)
        return True

def exec_in_service(service: str, command: list, interactive: bool = False) -> bool:
    """Execute command in service container"""
    debug_print(f"Executing command in {service}: {' '.join(command)}")
    
    # Get container ID
    result = run_command(["docker-compose", "ps", "-q", service])
    container_id = result.stdout.strip()
    
    if not container_id:
        print_error(f"Service {service} is not running")
        return False
    
    cmd = ["docker", "exec"]
    if interactive:
        cmd.extend(["-it"])
    cmd.append(container_id)
    cmd.extend(command)
    
    result = subprocess.run(cmd, capture_output=False)
    return result.returncode == 0

def update_service(service: str = "bot", rebuild: bool = True) -> bool:
    """Update a service to latest version"""
    debug_print(f"Updating service {service}, rebuild: {rebuild}")
    
    with ErrorContext(f"Updating service {service}"):
        print_message(f"🔄 Updating service: {service}", Colors.BLUE)
        
        # Check if service is running
        status = get_service_status()
        was_running = status["services"].get(service, {}).get("running", False)
        
        if was_running:
            print_message(f"Stopping {service} for update...", Colors.YELLOW)
            if not stop_service(service):
                raise ServiceError(f"Failed to stop {service} for update")
        
        if rebuild:
            print_message(f"Rebuilding {service}...", Colors.YELLOW)
            cmd = ["docker-compose", "build", service]
            result = subprocess.run(cmd, capture_output=False)
            if result.returncode != 0:
                raise ServiceError(f"Failed to rebuild {service}")
        
        if was_running:
            print_message(f"Starting {service}...", Colors.YELLOW)
            if not start_service(service):
                raise ServiceError(f"Failed to start {service} after update")
        
        print_success(f"✅ Service {service} updated successfully")
        return True

def check_service_dependencies() -> bool:
    """Check if service dependencies are available"""
    debug_print("Checking service dependencies")
    
    dependencies = {
        "docker": ["docker", "--version"],
        "docker-compose": ["docker-compose", "--version"]
    }
    
    missing_deps = []
    
    for dep_name, cmd in dependencies.items():
        result = run_command(cmd)
        if result.returncode != 0:
            missing_deps.append(dep_name)
            debug_print(f"Missing dependency: {dep_name}")
    
    if missing_deps:
        print_error(f"Missing dependencies: {', '.join(missing_deps)}")
        return False
    
    debug_print("All service dependencies are available")
    return True

def cleanup_service_resources(service: str = "") -> bool:
    """Clean up resources for a specific service"""
    debug_print(f"Cleaning up resources for service: {service}")
    
    with ErrorContext(f"Cleaning up service {service}"):
        print_message(f"🧹 Cleaning up {service} resources...", Colors.YELLOW)
        
        if service:
            # Remove specific service containers
            result = run_command(["docker-compose", "rm", "-sf", service])
            if result.returncode != 0:
                print_warning(f"Failed to remove {service} containers")
            
            # Remove service images
            result = run_command(["docker-compose", "images", "-q", service])
            if result.stdout.strip():
                images = result.stdout.strip().split('\n')
                run_command(["docker", "rmi"] + images)
        else:
            # Clean up all project resources
            result = run_command(["docker-compose", "down", "-v", "--remove-orphans"])
            if result.returncode != 0:
                print_warning("Failed to clean up all resources")
        
        print_success(f"✅ Cleaned up {service or 'all'} resources")
        return True 