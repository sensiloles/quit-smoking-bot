"""
system.py - System utilities and permission management

This module provides system-level utilities including permission setup,
file management, and system checks.
"""

import os
import stat
import platform
import subprocess
from pathlib import Path
from typing import List, Dict, Any, Optional

from .output import print_error, print_message, print_warning, debug_print, Colors, print_success
from .errors import BotError, ErrorContext

def get_system_info() -> Dict[str, str]:
    """Get system information"""
    debug_print("Getting system information")
    
    info = {
        "platform": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "python_version": platform.python_version(),
        "user": os.getenv("USER", "unknown"),
        "home": os.getenv("HOME", "unknown"),
        "pwd": os.getcwd()
    }
    
    debug_print(f"System info: {info}")
    return info

def setup_permissions() -> bool:
    """Setup proper permissions for bot files and directories"""
    debug_print("Setting up permissions")
    
    try:
        with ErrorContext("Permission setup"):
            print_message("🔧 Setting up file permissions...", Colors.BLUE)
            
            # Create directories with proper permissions
            directories = [
                ("data", 0o755),
                ("logs", 0o755),
                ("backups", 0o755)
            ]
            
            for dir_name, permissions in directories:
                dir_path = Path(dir_name)
                dir_path.mkdir(exist_ok=True)
                os.chmod(dir_path, permissions)
                debug_print(f"Set permissions {oct(permissions)} for {dir_name}/")
            
            # Set permissions for important files
            files = [
                (".env", 0o600),
                ("docker-compose.yml", 0o644),
                ("Dockerfile", 0o644)
            ]
            
            for file_name, permissions in files:
                file_path = Path(file_name)
                if file_path.exists():
                    os.chmod(file_path, permissions)
                    debug_print(f"Set permissions {oct(permissions)} for {file_name}")
            
            # Make scripts executable
            script_patterns = [
                "scripts/*.py",
                "scripts/*.sh"
            ]
            
            for pattern in script_patterns:
                import glob
                for script_file in glob.glob(pattern):
                    script_path = Path(script_file)
                    if script_path.exists():
                        # Add execute permission
                        current_mode = script_path.stat().st_mode
                        new_mode = current_mode | stat.S_IXUSR | stat.S_IXGRP
                        os.chmod(script_path, new_mode)
                        debug_print(f"Made {script_file} executable")
            
            # Create data files if they don't exist
            data_files = [
                "data/users.json",
                "data/quotes.json",
                "data/status.json"
            ]
            
            for data_file in data_files:
                file_path = Path(data_file)
                if not file_path.exists():
                    file_path.parent.mkdir(exist_ok=True)
                    
                    # Create with default content based on file type
                    if data_file.endswith("users.json"):
                        content = "{}"
                    elif data_file.endswith("quotes.json"):
                        content = "[]"
                    elif data_file.endswith("status.json"):
                        content = '{"users": {}}'
                    else:
                        content = "{}"
                    
                    file_path.write_text(content)
                    os.chmod(file_path, 0o644)
                    debug_print(f"Created {data_file}")
            
            print_success("✅ Permissions setup completed")
            return True
            
    except Exception as e:
        print_error(f"Failed to setup permissions: {e}")
        return False

def check_permissions() -> bool:
    """Check if file permissions are correct"""
    debug_print("Checking file permissions")
    
    issues = []
    
    # Check directory permissions
    directories = ["data", "logs", "backups"]
    for dir_name in directories:
        dir_path = Path(dir_name)
        if dir_path.exists():
            if not os.access(dir_path, os.R_OK | os.W_OK | os.X_OK):
                issues.append(f"{dir_name}/ directory is not accessible")
    
    # Check file permissions
    important_files = [".env", "docker-compose.yml"]
    for file_name in important_files:
        file_path = Path(file_name)
        if file_path.exists():
            if not os.access(file_path, os.R_OK):
                issues.append(f"{file_name} is not readable")
            if file_name == ".env" and os.access(file_path, os.R_OK, effective_ids=True):
                # Check if .env is too permissive
                file_mode = file_path.stat().st_mode
                if file_mode & (stat.S_IRGRP | stat.S_IROTH):
                    issues.append(f"{file_name} is readable by others (security risk)")
    
    if issues:
        print_warning("⚠️  Permission issues found:")
        for issue in issues:
            print_message(f"  - {issue}", Colors.YELLOW)
        return False
    else:
        print_success("✅ All permissions are correct")
        return True

def create_systemd_service() -> bool:
    """Create systemd service file for the bot"""
    debug_print("Creating systemd service")
    
    if platform.system() != "Linux":
        print_warning("Systemd services are only available on Linux")
        return False
    
    try:
        with ErrorContext("Systemd service creation"):
            service_name = "quit-smoking-bot"
            service_content = f"""[Unit]
Description=Quit Smoking Bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory={os.getcwd()}
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
User={os.getenv('USER', 'root')}

[Install]
WantedBy=multi-user.target
"""
            
            service_file = Path(f"/etc/systemd/system/{service_name}.service")
            
            # Check if we have permission to write to /etc/systemd/system/
            if not os.access("/etc/systemd/system/", os.W_OK):
                print_message(f"Creating service file at: {service_file}", Colors.YELLOW)
                print_message("You may need to run this with sudo", Colors.YELLOW)
                
                # Write to temporary location first
                temp_file = Path(f"/tmp/{service_name}.service")
                temp_file.write_text(service_content)
                
                print_message(f"Service file created at: {temp_file}", Colors.GREEN)
                print_message(f"To install, run: sudo mv {temp_file} {service_file}", Colors.YELLOW)
                print_message(f"Then run: sudo systemctl enable {service_name}", Colors.YELLOW)
                return True
            else:
                service_file.write_text(service_content)
                
                # Reload systemd and enable service
                subprocess.run(["systemctl", "daemon-reload"], check=True)
                subprocess.run(["systemctl", "enable", service_name], check=True)
                
                print_success(f"✅ Systemd service {service_name} created and enabled")
                return True
                
    except Exception as e:
        print_error(f"Failed to create systemd service: {e}")
        return False

def get_disk_usage() -> Dict[str, Any]:
    """Get disk usage information for the project"""
    debug_print("Getting disk usage information")
    
    usage = {
        "total_size": 0,
        "directories": {}
    }
    
    # Check main directories
    directories = ["data", "logs", "backups"]
    
    for dir_name in directories:
        dir_path = Path(dir_name)
        if dir_path.exists():
            size = get_directory_size(dir_path)
            usage["directories"][dir_name] = {
                "size_bytes": size,
                "size_mb": round(size / (1024 * 1024), 2)
            }
            usage["total_size"] += size
    
    usage["total_size_mb"] = round(usage["total_size"] / (1024 * 1024), 2)
    
    debug_print(f"Disk usage: {usage}")
    return usage

def get_directory_size(path: Path) -> int:
    """Get total size of a directory"""
    total_size = 0
    
    try:
        for item in path.rglob("*"):
            if item.is_file():
                total_size += item.stat().st_size
    except Exception as e:
        debug_print(f"Error calculating size for {path}: {e}")
    
    return total_size

def cleanup_old_files(days: int = 7) -> bool:
    """Clean up old log files and backups"""
    debug_print(f"Cleaning up files older than {days} days")
    
    try:
        with ErrorContext("File cleanup"):
            import time
            cutoff_time = time.time() - (days * 24 * 60 * 60)
            
            cleaned_files = []
            
            # Clean old log files
            logs_dir = Path("logs")
            if logs_dir.exists():
                for log_file in logs_dir.glob("*.log"):
                    if log_file.stat().st_mtime < cutoff_time:
                        log_file.unlink()
                        cleaned_files.append(str(log_file))
                        debug_print(f"Removed old log file: {log_file}")
            
            # Clean old backups (keep at least 3 newest)
            backups_dir = Path("backups")
            if backups_dir.exists():
                backup_files = list(backups_dir.glob("*.tar.gz"))
                backup_files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
                
                # Keep newest 3, remove older ones
                for backup_file in backup_files[3:]:
                    if backup_file.stat().st_mtime < cutoff_time:
                        backup_file.unlink()
                        cleaned_files.append(str(backup_file))
                        debug_print(f"Removed old backup: {backup_file}")
            
            if cleaned_files:
                print_message(f"🧹 Cleaned up {len(cleaned_files)} old files", Colors.GREEN)
                for file in cleaned_files:
                    debug_print(f"  - {file}")
            else:
                print_message("✅ No old files to clean up", Colors.GREEN)
            
            return True
            
    except Exception as e:
        print_error(f"Failed to cleanup old files: {e}")
        return False

def check_system_resources() -> Dict[str, Any]:
    """Check system resources (memory, disk space)"""
    debug_print("Checking system resources")
    
    resources = {
        "memory": {},
        "disk": {},
        "docker": {}
    }
    
    try:
        # Check memory (if psutil is available)
        try:
            import psutil
            memory = psutil.virtual_memory()
            resources["memory"] = {
                "total_gb": round(memory.total / (1024**3), 2),
                "available_gb": round(memory.available / (1024**3), 2),
                "percent_used": memory.percent
            }
        except ImportError:
            debug_print("psutil not available, skipping memory check")
        
        # Check disk space
        import shutil
        disk_usage = shutil.disk_usage(".")
        resources["disk"] = {
            "total_gb": round(disk_usage.total / (1024**3), 2),
            "free_gb": round(disk_usage.free / (1024**3), 2),
            "used_gb": round((disk_usage.total - disk_usage.free) / (1024**3), 2),
            "percent_used": round(((disk_usage.total - disk_usage.free) / disk_usage.total) * 100, 1)
        }
        
        # Check Docker resources
        try:
            result = subprocess.run(["docker", "system", "df"], capture_output=True, text=True)
            if result.returncode == 0:
                resources["docker"]["system_df_available"] = True
            else:
                resources["docker"]["system_df_available"] = False
        except Exception:
            resources["docker"]["system_df_available"] = False
        
    except Exception as e:
        debug_print(f"Error checking system resources: {e}")
    
    return resources

def install_dependencies() -> bool:
    """Install system dependencies if needed"""
    debug_print("Installing system dependencies")
    
    if platform.system() == "Linux":
        # Try to install basic dependencies
        dependencies = ["curl", "wget", "tar", "gzip"]
        
        try:
            # Check if apt is available
            result = subprocess.run(["which", "apt"], capture_output=True)
            if result.returncode == 0:
                print_message("Installing dependencies with apt...", Colors.YELLOW)
                for dep in dependencies:
                    subprocess.run(["apt", "install", "-y", dep], 
                                 capture_output=True, check=False)
                return True
        except Exception:
            pass
        
        try:
            # Check if yum is available
            result = subprocess.run(["which", "yum"], capture_output=True)
            if result.returncode == 0:
                print_message("Installing dependencies with yum...", Colors.YELLOW)
                for dep in dependencies:
                    subprocess.run(["yum", "install", "-y", dep], 
                                 capture_output=True, check=False)
                return True
        except Exception:
            pass
    
    print_warning("Could not automatically install dependencies")
    return False 