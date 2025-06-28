#!/usr/bin/env python3
"""
Comprehensive test suite for development environment quality assurance.
Tests Docker configuration, security, performance, and functionality.
"""

import os
import sys
import json
import time
import subprocess
import socket
import requests
import unittest
from pathlib import Path
from typing import List, Dict, Optional, Any
import docker
import yaml

class DevEnvironmentTestCase(unittest.TestCase):
    """Base test case with common utilities."""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.project_root = Path(__file__).parent.parent.parent
        cls.compose_file = cls.project_root / "development" / "docker-compose.yml"
        cls.container_name = "quit-smoking-bot-dev"
        
    def setUp(self):
        """Set up individual test."""
        self.maxDiff = None
        
    def run_command_in_container(self, command: str, container: str = None) -> Dict[str, Any]:
        """Run command inside container and return result."""
        container_name = container or self.container_name
        try:
            result = subprocess.run(
                ["docker", "exec", container_name, "bash", "-c", command],
                capture_output=True,
                text=True,
                timeout=30
            )
            return {
                "returncode": result.returncode,
                "stdout": result.stdout.strip(),
                "stderr": result.stderr.strip()
            }
        except subprocess.TimeoutExpired:
            return {
                "returncode": -1,
                "stdout": "",
                "stderr": "Command timed out"
            }
        except Exception as e:
            return {
                "returncode": -1,
                "stdout": "",
                "stderr": str(e)
            }

class DockerConfigurationTests(DevEnvironmentTestCase):
    """Test Docker configuration and setup."""
    
    def test_docker_compose_file_validity(self):
        """Test that docker-compose.yml is valid."""
        self.assertTrue(self.compose_file.exists(), "docker-compose.yml not found")
        
        # Parse YAML
        with open(self.compose_file) as f:
            try:
                compose_config = yaml.safe_load(f)
            except yaml.YAMLError as e:
                self.fail(f"Invalid YAML in docker-compose.yml: {e}")
                
        # Check required services
        self.assertIn("services", compose_config)
        services = compose_config["services"]
        
        required_services = ["dev-env", "dev-env-basic", "redis"]
        for service in required_services:
            self.assertIn(service, services, f"Service {service} not found")
            
    def test_dockerfile_validity(self):
        """Test that Dockerfile is valid."""
        dockerfile = self.project_root / "development" / "Dockerfile"
        self.assertTrue(dockerfile.exists(), "Dockerfile not found")
        
        # Check Dockerfile syntax
        result = subprocess.run(
            ["docker", "build", "--dry-run", "-f", str(dockerfile), "."],
            cwd=str(dockerfile.parent),
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            self.fail(f"Dockerfile syntax error: {result.stderr}")
            
    def test_build_arguments_configuration(self):
        """Test build arguments are properly configured."""
        with open(self.compose_file) as f:
            compose_config = yaml.safe_load(f)
            
        dev_env_service = compose_config["services"]["dev-env"]
        self.assertIn("build", dev_env_service)
        
        build_config = dev_env_service["build"]
        self.assertIn("args", build_config)
        
        required_args = ["DOCKER_VERSION", "DOCKER_COMPOSE_VERSION", "PYTHON_VERSION"]
        for arg in required_args:
            self.assertIn(arg, build_config["args"])

class SecurityTests(DevEnvironmentTestCase):
    """Test security configuration."""
    
    def test_non_privileged_mode(self):
        """Test container runs in non-privileged mode."""
        container = self.client.containers.get(self.container_name)
        
        # Check container is not privileged
        self.assertFalse(
            container.attrs.get("HostConfig", {}).get("Privileged", False),
            "Container should not run in privileged mode"
        )
        
    def test_security_options(self):
        """Test security options are properly configured."""
        container = self.client.containers.get(self.container_name)
        security_opt = container.attrs.get("HostConfig", {}).get("SecurityOpt", [])
        
        # Check for no-new-privileges
        self.assertIn("no-new-privileges:true", security_opt)
        
    def test_capabilities_dropped(self):
        """Test unnecessary capabilities are dropped."""
        container = self.client.containers.get(self.container_name)
        cap_drop = container.attrs.get("HostConfig", {}).get("CapDrop", [])
        
        # Should drop all capabilities by default
        self.assertIn("ALL", cap_drop)
        
    def test_user_configuration(self):
        """Test container runs as non-root user."""
        result = self.run_command_in_container("id -u")
        self.assertEqual(result["returncode"], 0)
        self.assertEqual(result["stdout"], "1000", "Container should run as user ID 1000")
        
        result = self.run_command_in_container("whoami")
        self.assertEqual(result["returncode"], 0)
        self.assertEqual(result["stdout"], "developer", "Container should run as developer user")

class ResourceLimitsTests(DevEnvironmentTestCase):
    """Test resource limits and constraints."""
    
    def test_memory_limits(self):
        """Test memory limits are configured."""
        container = self.client.containers.get(self.container_name)
        host_config = container.attrs.get("HostConfig", {})
        
        # Check memory limit is set
        memory_limit = host_config.get("Memory", 0)
        self.assertGreater(memory_limit, 0, "Memory limit should be set")
        self.assertLessEqual(memory_limit, 2 * 1024 * 1024 * 1024, "Memory limit should be <= 2GB")
        
    def test_cpu_limits(self):
        """Test CPU limits are configured."""
        container = self.client.containers.get(self.container_name)
        host_config = container.attrs.get("HostConfig", {})
        
        # Check CPU limit
        nano_cpus = host_config.get("NanoCpus", 0)
        if nano_cpus > 0:
            cpu_count = nano_cpus / 1000000000
            self.assertLessEqual(cpu_count, 2.0, "CPU limit should be <= 2.0")

class HealthCheckTests(DevEnvironmentTestCase):
    """Test health check functionality."""
    
    def test_health_check_script_exists(self):
        """Test health check script exists and is executable."""
        result = self.run_command_in_container("test -x /usr/local/bin/healthcheck.sh")
        self.assertEqual(result["returncode"], 0, "Health check script should exist and be executable")
        
    def test_health_check_execution(self):
        """Test health check script executes successfully."""
        result = self.run_command_in_container("/usr/local/bin/healthcheck.sh")
        self.assertEqual(result["returncode"], 0, f"Health check failed: {result['stderr']}")
        
    def test_container_health_status(self):
        """Test container reports healthy status."""
        container = self.client.containers.get(self.container_name)
        container.reload()
        
        # Wait for health check to run
        max_wait = 60  # seconds
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            container.reload()
            health = container.attrs.get("State", {}).get("Health", {})
            status = health.get("Status", "")
            
            if status == "healthy":
                break
            elif status == "unhealthy":
                logs = health.get("Log", [])
                last_log = logs[-1] if logs else {}
                self.fail(f"Container is unhealthy: {last_log.get('Output', 'No output')}")
                
            time.sleep(5)
        else:
            self.fail("Container did not become healthy within timeout")

class FunctionalityTests(DevEnvironmentTestCase):
    """Test development environment functionality."""
    
    def test_python_installation(self):
        """Test Python is properly installed and configured."""
        # Test Python version
        result = self.run_command_in_container("python3 --version")
        self.assertEqual(result["returncode"], 0)
        self.assertIn("Python 3.11", result["stdout"])
        
        # Test pip
        result = self.run_command_in_container("pip3 --version")
        self.assertEqual(result["returncode"], 0)
        
    def test_development_tools_installation(self):
        """Test development tools are installed."""
        tools = ["git", "curl", "jq", "nano", "vim"]
        
        for tool in tools:
            with self.subTest(tool=tool):
                result = self.run_command_in_container(f"command -v {tool}")
                self.assertEqual(result["returncode"], 0, f"Tool {tool} not found")
                
    def test_python_development_packages(self):
        """Test Python development packages are installed."""
        packages = ["pytest", "black", "flake8", "isort"]
        
        for package in packages:
            with self.subTest(package=package):
                result = self.run_command_in_container(f"python3 -c 'import {package}'")
                self.assertEqual(result["returncode"], 0, f"Package {package} not installed")
                
    def test_workspace_mount(self):
        """Test workspace is properly mounted."""
        # Check workspace directory exists
        result = self.run_command_in_container("test -d /workspace")
        self.assertEqual(result["returncode"], 0, "Workspace directory not found")
        
        # Check project files are accessible
        files = ["main.py", "pyproject.toml", "scripts/common.sh"]
        for file in files:
            with self.subTest(file=file):
                result = self.run_command_in_container(f"test -f /workspace/{file}")
                self.assertEqual(result["returncode"], 0, f"Project file {file} not found")
                
    def test_environment_variables(self):
        """Test environment variables are properly set."""
        env_vars = {
            "PYTHONPATH": "/workspace/src",
            "SYSTEM_NAME": "quit-smoking-bot",
            "DEVELOPMENT": "1"
        }
        
        for var, expected_value in env_vars.items():
            with self.subTest(variable=var):
                result = self.run_command_in_container(f"echo ${var}")
                self.assertEqual(result["returncode"], 0)
                if expected_value:
                    self.assertEqual(result["stdout"], expected_value)

class NetworkingTests(DevEnvironmentTestCase):
    """Test networking configuration."""
    
    def test_redis_connectivity(self):
        """Test Redis service is accessible."""
        result = self.run_command_in_container("nc -z redis-dev 6379")
        self.assertEqual(result["returncode"], 0, "Redis service not accessible")
        
    def test_external_connectivity(self):
        """Test external network connectivity."""
        result = self.run_command_in_container("curl -s --connect-timeout 10 https://httpbin.org/get")
        self.assertEqual(result["returncode"], 0, "External connectivity failed")
        
    def test_port_exposure(self):
        """Test development ports are properly exposed."""
        container = self.client.containers.get(self.container_name)
        port_bindings = container.attrs.get("NetworkSettings", {}).get("Ports", {})
        
        expected_ports = ["8000/tcp", "8080/tcp", "9090/tcp"]
        for port in expected_ports:
            with self.subTest(port=port):
                self.assertIn(port, port_bindings, f"Port {port} not exposed")

class MonitoringTests(DevEnvironmentTestCase):
    """Test monitoring and logging functionality."""
    
    def test_log_directory_creation(self):
        """Test log directories are created."""
        result = self.run_command_in_container("test -d /workspace/logs")
        self.assertEqual(result["returncode"], 0, "Logs directory not found")
        
    def test_health_monitor_script(self):
        """Test health monitor script exists and is executable."""
        result = self.run_command_in_container("test -x /usr/local/bin/health-monitor.sh")
        self.assertEqual(result["returncode"], 0, "Health monitor script not found")
        
    def test_supervisor_configuration(self):
        """Test supervisor is properly configured."""
        result = self.run_command_in_container("supervisorctl status")
        self.assertEqual(result["returncode"], 0, "Supervisor not working")

class PerformanceTests(DevEnvironmentTestCase):
    """Test performance characteristics."""
    
    def test_container_startup_time(self):
        """Test container starts within reasonable time."""
        start_time = time.time()
        
        # Stop container if running
        try:
            container = self.client.containers.get(self.container_name)
            container.stop(timeout=10)
            container.remove()
        except docker.errors.NotFound:
            pass
            
        # Start container
        subprocess.run(
            ["docker-compose", "up", "-d", "dev-env"],
            cwd=str(self.compose_file.parent),
            capture_output=True
        )
        
        # Wait for container to be healthy
        max_wait = 120  # 2 minutes
        while time.time() - start_time < max_wait:
            try:
                container = self.client.containers.get(self.container_name)
                container.reload()
                health = container.attrs.get("State", {}).get("Health", {})
                if health.get("Status") == "healthy":
                    startup_time = time.time() - start_time
                    self.assertLess(startup_time, 120, "Container startup took too long")
                    return
            except docker.errors.NotFound:
                pass
            time.sleep(2)
            
        self.fail("Container did not start within timeout")
        
    def test_memory_usage(self):
        """Test container memory usage is within limits."""
        result = self.run_command_in_container("cat /proc/meminfo | grep MemAvailable")
        self.assertEqual(result["returncode"], 0)
        
        # Parse available memory
        mem_line = result["stdout"]
        mem_kb = int(mem_line.split()[1])
        mem_mb = mem_kb / 1024
        
        # Should have at least 256MB available
        self.assertGreater(mem_mb, 256, "Insufficient available memory")

def run_tests():
    """Run all development environment tests."""
    # Create test suite
    test_classes = [
        DockerConfigurationTests,
        SecurityTests,
        ResourceLimitsTests,
        HealthCheckTests,
        FunctionalityTests,
        NetworkingTests,
        MonitoringTests,
        PerformanceTests
    ]
    
    suite = unittest.TestSuite()
    for test_class in test_classes:
        tests = unittest.TestLoader().loadTestsFromTestCase(test_class)
        suite.addTests(tests)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2, buffer=True)
    result = runner.run(suite)
    
    # Return success/failure
    return result.wasSuccessful()

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1) 