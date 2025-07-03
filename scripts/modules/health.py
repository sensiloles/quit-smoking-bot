"""
health.py - Health check and status monitoring utilities

This module provides functions for checking container health,
bot operational status, and system monitoring.
"""

import subprocess
from typing import Dict, Any, Optional

from .output import print_error, print_message, print_warning, debug_print, Colors
from .environment import get_system_name
from .docker_utils import run_command

def is_bot_healthy() -> bool:
    """Check if bot is healthy using Docker healthcheck"""
    debug_print("Starting is_bot_healthy check")
    
    system_name = get_system_name()
    
    # Get container ID
    result = run_command(["docker-compose", "ps", "-q", "bot"])
    container_id = result.stdout.strip()
    
    debug_print(f"Container ID: {container_id}")
    
    if not container_id:
        debug_print("Container is not running - no container ID found")
        print_error("Container is not running")
        return False
    
    # Get container health status
    result = run_command(["docker", "inspect", "--format", "{{.State.Health.Status}}", container_id])
    health_status = result.stdout.strip()
    
    debug_print(f"Container health status: {health_status}")
    
    if health_status == "healthy":
        debug_print("Container health check passed")
        print_message("Bot is healthy - container health check passed", Colors.GREEN)
        
        # Print the most recent health check log
        print_message("Last health check result:", Colors.YELLOW)
        result = run_command([
            "docker", "inspect", "--format",
            "{{range .State.Health.Log}}{{if eq .ExitCode 0}}{{.Output}}{{end}}{{end}}",
            container_id
        ])
        if result.stdout.strip():
            print(result.stdout.strip().split('\n')[-1])  # Last line
        
        return True
    elif health_status == "starting":
        debug_print("Health check is still starting")
        print_message("Bot health check is still initializing", Colors.YELLOW)
        return False
    else:
        debug_print(f"Health check failed with status: {health_status}")
        print_error(f"Bot health check failed - status: {health_status}")
        
        # Print the most recent health check log
        print_message("Last health check result:", Colors.YELLOW)
        result = run_command([
            "docker", "inspect", "--format",
            "{{range .State.Health.Log}}{{.Output}}{{end}}",
            container_id
        ])
        if result.stdout.strip():
            print(result.stdout.strip().split('\n')[-1])  # Last line
        
        return False

def is_bot_operational() -> bool:
    """Check if bot is operational"""
    debug_print("Starting is_bot_operational check")
    
    # Get container ID
    result = run_command(["docker-compose", "ps", "-q", "bot"])
    container_id = result.stdout.strip()
    
    debug_print(f"Container ID for operational check: {container_id}")
    
    if not container_id:
        debug_print("Container is not running for operational check")
        print_error("Container is not running")
        return False
    
    # Check if Python process is running
    debug_print("Checking if Python bot process is running")
    result = run_command([
        "docker", "exec", container_id, 
        "pgrep", "-f", "python.*src[/.]bot"
    ])
    
    if result.returncode != 0:
        debug_print("Bot process is not running inside container")
        print_error("Bot process is not running inside container")
        return False
    
    debug_print("Bot process is running inside container")
    
    # Check container logs for operational messages
    debug_print("Checking logs for operational status")
    print_message("Checking logs for operational status...", Colors.YELLOW)
    
    result = run_command(["docker", "logs", "--tail", "50", container_id])
    logs = result.stdout + result.stderr
    
    # Check for conflict errors first
    if any(phrase in logs for phrase in [
        "telegram.error.Conflict",
        "error_code\":409",
        "terminated by other getUpdates"
    ]):
        print_error("Telegram API conflict detected - another bot is running with the same token")
        print_message("You will need to stop the other bot instance to use this one properly.", Colors.YELLOW)
    
    # Check for successful startup
    if "Application started" in logs:
        print_message("Bot is operational", Colors.GREEN)
        return True
    
    # Check for API calls - if multiple successful API calls, consider operational
    api_calls = logs.count("\"HTTP/1.1 200 OK\"")
    if api_calls >= 2:
        print_message(f"Bot is operational ({api_calls} successful API calls detected)", Colors.GREEN)
        return True
    
    # Even with conflicts, bot might be partly operational
    if any(phrase in logs for phrase in [
        "telegram.error.Conflict",
        "error_code\":409", 
        "terminated by other getUpdates"
    ]) and "\"HTTP/1.1 200 OK\"" in logs:
        print_message("Bot is partly operational despite conflicts", Colors.YELLOW)
        return True
    
    print_error("Bot is not operational")
    return False

def quick_health_check() -> bool:
    """Quick health check for Docker healthcheck mode"""
    debug_print("Running quick health check")
    
    try:
        # Check if bot process is running
        result = run_command(["pgrep", "-f", "python.*src.*bot"])
        
        if result.returncode == 0:
            debug_print("Bot process found")
            return True
        else:
            debug_print("Bot process not found")
            return False
    except Exception as e:
        debug_print(f"Error in quick health check: {e}")
        return False

def comprehensive_health_check() -> bool:
    """Comprehensive health check for diagnostics mode"""
    debug_print("Running comprehensive health check")
    
    success = True
    
    # Basic health check
    print_message("📋 Basic Health Check:", Colors.BLUE)
    if quick_health_check():
        print_message("✅ Process check passed", Colors.GREEN)
    else:
        print_message("❌ Process check failed", Colors.RED)
        success = False
    
    # Container health check  
    print_message("\n🐳 Container Health Check:", Colors.BLUE)
    try:
        result = run_command(["docker-compose", "ps", "bot"])
        if result.returncode == 0 and "Up" in result.stdout:
            print_message("✅ Container is running", Colors.GREEN)
            
            # Check if bot process is running inside container
            if quick_health_check():
                print_message("✅ Bot process is running", Colors.GREEN)
            else:
                print_message("❌ Bot process is not running", Colors.RED)
                success = False
                
            # Check recent logs for errors
            system_name = get_system_name()
            result = run_command(["docker-compose", "logs", "--tail", "10", "bot"])
            
            if any(level in result.stdout for level in ["ERROR", "CRITICAL"]):
                print_message("⚠️  Recent errors found in logs", Colors.YELLOW)
                success = False
            else:
                print_message("✅ No recent errors in logs", Colors.GREEN)
        else:
            print_message("❌ Container is not running", Colors.RED)
            success = False
            
    except Exception as e:
        print_message(f"❌ Container check error: {e}", Colors.RED)
        success = False
    
    # File system checks
    print_message("\n📁 File System Check:", Colors.BLUE)
    try:
        from pathlib import Path
        
        data_dir = Path("/app/data") if Path("/app").exists() else Path("./data")
        logs_dir = Path("/app/logs") if Path("/app").exists() else Path("./logs")
        
        if data_dir.exists() and data_dir.is_dir():
            print_message("✅ Data directory exists", Colors.GREEN)
        else:
            print_message("❌ Data directory missing", Colors.RED)
            success = False
        
        if logs_dir.exists() and logs_dir.is_dir():
            print_message("✅ Logs directory exists", Colors.GREEN)
        else:
            print_message("❌ Logs directory missing", Colors.RED)
            success = False
            
    except Exception as e:
        print_message(f"❌ File system check error: {e}", Colors.RED)
        success = False
    
    return success

def check_bot_status() -> Dict[str, Any]:
    """Check comprehensive bot status after startup"""
    print_message("\n=== BOT STATUS CHECK ===", Colors.BLUE)
    print_message("Checking bot status after startup...", Colors.YELLOW)
    
    status = {
        "container_running": False,
        "bot_healthy": False,
        "bot_operational": False,
        "errors": []
    }
    
    # Step 1: Verify container is still running
    print_message("Step 1: Verifying container is running...", Colors.YELLOW)
    result = run_command(["docker-compose", "ps", "bot"])
    
    if result.returncode != 0 or "Up" not in result.stdout:
        status["errors"].append("Container is not running")
        print_error("Container is not running!")
        subprocess.run(["docker-compose", "ps", "bot"], capture_output=False)
        return status
    
    print_message("✅ Container is running", Colors.GREEN)
    status["container_running"] = True
    
    # Step 2: Wait for initialization
    print_message("Step 2: Waiting for container initialization (5 seconds)...", Colors.YELLOW)
    import time
    time.sleep(5)
    
    # Step 3: Show recent logs
    print_message("Step 3: Recent container logs:", Colors.YELLOW)
    subprocess.run(["docker-compose", "logs", "--tail", "10", "bot"], capture_output=False)
    
    # Step 4: Health check loop
    print_message("Step 4: Health check loop (max 30 attempts)...", Colors.YELLOW)
    max_attempts = 30
    
    for attempt in range(1, max_attempts + 1):
        print_message(f"Checking bot health (attempt {attempt}/{max_attempts})...", Colors.YELLOW)
        
        # Check if container is still running
        result = run_command(["docker-compose", "ps", "bot"])
        if "Up" not in result.stdout:
            status["errors"].append("Container stopped during health check")
            print_error("Container stopped running during health check!")
            return status
        
        # Check if bot is healthy using Docker healthcheck
        if is_bot_healthy():
            print_message("Bot health check: PASSED", Colors.GREEN)
            status["bot_healthy"] = True
            break
        else:
            if attempt == max_attempts:
                print_message("Bot health check did not pass within timeout, but bot might still be functioning.", Colors.YELLOW)
                print_message("Continuing with operational check...", Colors.YELLOW)
                # Show recent logs for debugging
                print_message("Recent logs for debugging:", Colors.YELLOW)
                subprocess.run(["docker-compose", "logs", "--tail", "15", "bot"], capture_output=False)
            else:
                print_message("Bot health check not yet passing, waiting...", Colors.YELLOW)
                time.sleep(5)
                continue
    
    # Step 5: Operational check
    print_message("Step 5: Operational check...", Colors.YELLOW)
    if is_bot_operational():
        print_message("Bot operational check: PASSED", Colors.GREEN)
        print_message("🎉 Bot is fully operational!", Colors.GREEN)
        status["bot_operational"] = True
        
        # Show final status summary
        print_message("\n=== FINAL STATUS SUMMARY ===", Colors.GREEN)
        print_message("Container status:", Colors.GREEN)
        subprocess.run(["docker-compose", "ps", "bot"], capture_output=False)
        print_message("Most recent logs:", Colors.GREEN)
        subprocess.run(["docker-compose", "logs", "--tail", "5", "bot"], capture_output=False)
        print_message("=== END STATUS SUMMARY ===", Colors.GREEN)
        
    else:
        print_message("Bot operational check: NOT PASSED", Colors.YELLOW)
        print_message("Bot is running but might not be fully operational.", Colors.YELLOW)
        status["errors"].append("Bot not fully operational")
        
        # Detailed diagnostic info
        print_message("\n=== DIAGNOSTIC INFORMATION ===", Colors.YELLOW)
        print_message("Container status:", Colors.YELLOW)
        subprocess.run(["docker-compose", "ps", "bot"], capture_output=False)
        print_message("Extended logs for diagnostics:", Colors.YELLOW)
        subprocess.run(["docker-compose", "logs", "--tail", "25", "bot"], capture_output=False)
        print_message("=== END DIAGNOSTICS ===", Colors.YELLOW)
        
        print_message("Use 'python scripts/status.py' for detailed diagnostics.", Colors.YELLOW)
    
    return status 