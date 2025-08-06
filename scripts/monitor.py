#!/usr/bin/env python3
"""
monitor.py - Universal health monitoring script for the Telegram bot

This script provides comprehensive health monitoring functionality
Usage modes:
  --mode docker      # For Docker healthcheck (minimal, fast)
  --mode monitor     # For continuous monitoring (detailed)
  --mode diagnostics # For comprehensive diagnostics
  --mode status      # For status checks
"""

import os
import sys
import time
import json
import argparse
import logging
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any

# Add scripts directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from modules import (
    create_health_parser, parse_and_setup_args,
    quick_health_check, comprehensive_health_check, is_bot_healthy, is_bot_operational,
    print_message, print_section, debug_print, Colors, print_success, print_error,
    get_container_status
)

# Configuration
HEALTH_LOG_FILE = Path("/app/logs/health.log")

# quick_health_check is now imported from modules

def monitor_health_check() -> bool:
    """Detailed health check for monitoring mode"""
    debug_print("Running monitor health check")
    
    try:
        # Check container status using docker-compose
        result = subprocess.run(
            ["docker-compose", "-f", "docker/docker-compose.yml", "ps", "bot"],
            capture_output=True,
            text=True,
            cwd="/"
        )
        
        if result.returncode != 0:
            print_message("❌ Failed to check container status", Colors.RED)
            return False
        
        if "Up" not in result.stdout:
            print_message("❌ Container is not running", Colors.RED)
            return False
        
        print_message("✅ Container is running", Colors.GREEN)
        
        # Check if bot process is running inside container
        if not quick_health_check():
            print_message("❌ Bot process is not running", Colors.RED)
            return False
        
        print_message("✅ Bot process is running", Colors.GREEN)
        
        # Check recent logs for errors
        try:
            log_result = subprocess.run(
                ["docker-compose", "-f", "docker/docker-compose.yml", "logs", "--tail", "10", "bot"],
                capture_output=True,
                text=True,
                cwd="/"
            )
            
            if "ERROR" in log_result.stdout or "CRITICAL" in log_result.stdout:
                print_message("⚠️  Recent errors found in logs", Colors.YELLOW)
                return False
            
            print_message("✅ No recent errors in logs", Colors.GREEN)
        except Exception as e:
            debug_print(f"Could not check logs: {e}")
        
        return True
        
    except Exception as e:
        debug_print(f"Error in monitor health check: {e}")
        print_message(f"❌ Health check error: {e}", Colors.RED)
        return False

# comprehensive_health_check is now imported from modules

def get_container_resources(container_name: str) -> str:
    """Get container resource usage"""
    try:
        result = subprocess.run(
            ["docker", "stats", "--no-stream", "--format", 
             "table {{.CPUPerc}}\t{{.MemUsage}}", container_name],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                return lines[1]  # Skip header
        
        return "N/A"
    except Exception:
        return "N/A"

def run_docker_mode():
    """Run Docker healthcheck mode"""
    debug_print("Running Docker healthcheck mode")
    print_message("🔍 Docker Health Check", Colors.BLUE)
    
    if quick_health_check():
        print_message("✅ Health check passed", Colors.GREEN)
        sys.exit(0)
    else:
        print_message("❌ Health check failed", Colors.RED)
        sys.exit(1)

def run_monitor_mode(continuous: bool, interval: int):
    """Run monitoring mode"""
    debug_print(f"Running monitoring mode (continuous={continuous})")
    
    if continuous:
        print_message(f"🔄 Starting continuous monitoring (interval: {interval}s)", Colors.BLUE)
        print_message("Press Ctrl+C to stop", Colors.YELLOW)
        
        try:
            while True:
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                print_message(f"\n[{timestamp}] Health Monitor Check:", Colors.BLUE)
                
                if monitor_health_check():
                    print_message("✅ System healthy", Colors.GREEN)
                else:
                    print_message("⚠️  System issues detected", Colors.YELLOW)
                
                time.sleep(interval)
        except KeyboardInterrupt:
            print_message("\n🛑 Monitoring stopped by user", Colors.YELLOW)
            sys.exit(0)
    else:
        print_message("🔍 Single Monitoring Check", Colors.BLUE)
        
        if monitor_health_check():
            print_message("✅ System healthy", Colors.GREEN)
            sys.exit(0)
        else:
            print_message("⚠️  System issues detected", Colors.YELLOW)
            sys.exit(1)

def run_diagnostics_mode():
    """Run diagnostics mode"""
    debug_print("Running diagnostics mode")
    print_message("🔬 Comprehensive System Diagnostics", Colors.BLUE)
    
    total_checks = 0
    failed_checks = 0
    
    # Health checks
    print_section("Health Status")
    total_checks += 1
    if comprehensive_health_check():
        print_message("✅ Health checks passed", Colors.GREEN)
    else:
        print_message("❌ Health checks failed", Colors.RED)
        failed_checks += 1
    
    # Container diagnostics
    try:
        subprocess.run(["docker", "--version"], capture_output=True, check=True)
        print_section("Container Status")
        total_checks += 1
        
        container_name = os.getenv("SYSTEM_NAME", "quit-smoking-bot")
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}", "--filter", f"name={container_name}"],
            capture_output=True,
            text=True
        )
        
        if container_name in result.stdout:
            print_message("✅ Container is running", Colors.GREEN)
            
            # Show container details
            print_message("\nContainer Details:", Colors.YELLOW)
            subprocess.run([
                "docker", "ps", "--filter", f"name={container_name}",
                "--format", "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
            ])
            
            # Show resource usage
            resources = get_container_resources(container_name)
            if resources != "N/A":
                print_message("\nResource Usage:", Colors.YELLOW)
                print("CPU\tMemory")
                print(resources)
        else:
            print_message("❌ Container is not running", Colors.RED)
            failed_checks += 1
            
    except subprocess.CalledProcessError:
        print_message("⚠️  Docker not available", Colors.YELLOW)
    except Exception as e:
        print_message(f"❌ Container diagnostics error: {e}", Colors.RED)
        failed_checks += 1
    
    # Summary
    print_section("Diagnostics Summary")
    print_message(f"Total checks: {total_checks}", Colors.BLUE)
    print_message(f"Passed: {total_checks - failed_checks}", Colors.GREEN)
    print_message(f"Failed: {failed_checks}", Colors.RED)
    
    if failed_checks == 0:
        print_message("🎉 All diagnostics passed!", Colors.GREEN)
        sys.exit(0)
    else:
        print_message("⚠️  Some diagnostics failed", Colors.YELLOW)
        sys.exit(1)

def run_status_mode():
    """Run status mode"""
    debug_print("Running status mode")
    print_message("📊 Current Status Snapshot", Colors.BLUE)
    
    # Quick status overview
    print_section("Service Status")
    try:
        result = subprocess.run(
            ["docker-compose", "-f", "docker/docker-compose.yml", "ps"],
            capture_output=True,
            text=True,
            cwd="/"
        )
        print(result.stdout)
        
        # Health status
        if quick_health_check():
            print_message("✅ Bot process: Running", Colors.GREEN)
        else:
            print_message("❌ Bot process: Not running", Colors.RED)
            
    except Exception as e:
        print_message(f"❌ Status check error: {e}", Colors.RED)
        sys.exit(1)

def main():
    """Main function"""
    parser = create_health_parser()
    args = parse_and_setup_args(parser)
    
    debug_print(f"Health check starting with mode: {args.mode}")
    
    # Ensure logs directory exists
    HEALTH_LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        if args.mode == "docker":
            run_docker_mode()
        elif args.mode == "monitor":
            run_monitor_mode(getattr(args, 'continuous', False), args.interval)
        elif args.mode == "diagnostics":
            run_diagnostics_mode()
        elif args.mode == "status":
            run_status_mode()
    except Exception as e:
        print_error(f"Health monitor error: {e}")
        debug_print(f"Exception details: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 