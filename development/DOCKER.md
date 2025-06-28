# Development Environment Docker Configuration

This document provides comprehensive information about the Docker setup for the development environment of the Quit Smoking Bot project, specifically covering the configurations in `development/Dockerfile` and `development/docker-compose.yml`.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Dockerfile Analysis](#dockerfile-analysis)
- [Docker Compose Services](#docker-compose-services)
- [Environment Setup](#environment-setup)
- [Docker-in-Docker Configuration](#docker-in-docker-configuration)
- [systemd Integration](#systemd-integration)
- [Volume Management](#volume-management)
- [Security Configuration](#security-configuration)
- [Usage Patterns](#usage-patterns)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The development environment uses Docker to provide a consistent Linux-based testing environment that can run on any operating system. This is particularly valuable for:

- **Cross-platform development**: Run Linux environment on macOS, Windows, or any Docker-capable system
- **Service testing**: Test systemd service installation and management
- **Script validation**: Test all project scripts in isolated environment
- **Docker-in-Docker**: Test Docker containers from within the development container

### Key Features

- **Ubuntu 22.04** base image for full Linux compatibility
- **Docker + Docker Compose** installed for container testing
- **systemd support** for service testing (optional privileged mode)
- **Development tools** including Python, Git, curl, jq, vim, nano
- **User environment** with sudo access and shell customization
- **Persistent storage** for development files and configurations

## Architecture

The development environment consists of two main services:

1. **`dev-env`**: Standard development environment with Docker-in-Docker
2. **`dev-env-systemd`**: Enhanced environment with full systemd support

Both services share the same base image but have different runtime configurations to support different testing scenarios.

```
Development Container Architecture:

┌─────────────────────────────────────┐
│ Ubuntu 22.04 Container              │
├─────────────────────────────────────┤
│ /workspace (mounted from host)      │
│ ├── src/                            │
│ ├── scripts/                        │
│ ├── development/                    │
│ └── ... (entire project)            │
├─────────────────────────────────────┤
│ /home/developer (persistent volume) │
│ ├── .bashrc (custom shell config)   │
│ ├── .bash_history                   │
│ └── ... (development files)         │
├─────────────────────────────────────┤
│ System Services                     │
│ ├── Docker daemon (via socket)      │
│ ├── systemd (in systemd mode)       │
│ └── Development tools               │
└─────────────────────────────────────┘
```

## Dockerfile Analysis

### Base Image and Environment

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
```

**Design Decisions:**
- **Ubuntu 22.04**: Full Linux distribution for complete compatibility
- **Non-interactive**: Prevents package installation prompts
- **UTC timezone**: Neutral timezone for development

### System Dependencies

The Dockerfile installs comprehensive development tools:

```dockerfile
RUN apt-get update && apt-get install -y \
    # Basic tools
    curl wget git jq nano vim htop tree \
    # Docker installation dependencies
    ca-certificates gnupg lsb-release \
    # Systemd for service testing
    systemd systemd-sysv \
    # Python and pip for bot testing
    python3 python3-pip \
    # Network tools
    net-tools iputils-ping \
    # Process tools
    procps psmisc \
    # Build tools
    build-essential
```

**Tool Categories:**
- **Basic utilities**: Essential command-line tools
- **Development**: Git, editors, process monitoring
- **Network**: Connectivity testing and debugging
- **Python**: For running and testing the bot
- **Build**: Compilation tools for native dependencies

### Docker Installation

```dockerfile
# Install Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose
```

**Docker-in-Docker Setup:**
- Installs latest Docker CE from official repository
- Includes Docker Compose for orchestration testing
- Configured to use host Docker daemon via socket mounting

### User Configuration

```dockerfile
# Create development user
RUN useradd -m -s /bin/bash -G docker developer \
    && echo 'developer ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
```

**User Features:**
- **Non-root user**: `developer` for security
- **Docker group**: Direct Docker access
- **Sudo access**: Passwordless sudo for testing
- **Bash shell**: Full shell environment

### Environment Customization

```dockerfile
# Set up shell environment
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias la="ls -la"' >> ~/.bashrc \
    && echo 'export PS1="\[\033[01;32m\]dev-env\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc
```

**Shell Enhancements:**
- **Convenient aliases**: Common directory listing shortcuts
- **Custom prompt**: Colored prompt showing `dev-env` context
- **Development-friendly**: Optimized for interactive use

## Docker Compose Services

### Standard Development Service (`dev-env`)

```yaml
dev-env:
  build:
    context: .
    dockerfile: Dockerfile
  container_name: quit-smoking-bot-dev
  hostname: dev-env
  volumes:
    - ../:/workspace
    - /var/run/docker.sock:/var/run/docker.sock
    - dev-home:/home/developer
  environment:
    - SYSTEM_NAME=quit-smoking-bot
    - SYSTEM_DISPLAY_NAME=Quit Smoking Bot
  working_dir: /workspace
  stdin_open: true
  tty: true
  command: /bin/bash
```

**Service Features:**
- **Interactive terminal**: `stdin_open` and `tty` for shell access
- **Project mounting**: Entire project available at `/workspace`
- **Docker socket**: Docker-in-Docker capability
- **Persistent home**: User files persist between sessions
- **Environment variables**: Project configuration available

### systemd-Enabled Service (`dev-env-systemd`)

```yaml
dev-env-systemd:
  build:
    context: .
    dockerfile: Dockerfile
  container_name: quit-smoking-bot-dev-systemd
  hostname: dev-systemd
  volumes:
    - ../:/workspace
    - /var/run/docker.sock:/var/run/docker.sock
    - dev-systemd-home:/home/developer
    - /sys/fs/cgroup:/sys/fs/cgroup:ro
  environment:
    - SYSTEM_NAME=quit-smoking-bot
    - SYSTEM_DISPLAY_NAME=Quit Smoking Bot
  working_dir: /workspace
  stdin_open: true
  tty: true
  privileged: true
  tmpfs:
    - /tmp
    - /run
    - /run/lock
  command: /sbin/init
```

**systemd-Specific Features:**
- **Privileged mode**: Required for systemd operation
- **cgroup mounting**: `/sys/fs/cgroup` for systemd functionality
- **tmpfs mounts**: Temporary filesystems for systemd
- **Init process**: `/sbin/init` starts systemd as PID 1

## Environment Setup

### Working Directory

- **Project root**: Mounted at `/workspace`
- **Current directory**: Starts in `/workspace`
- **Full access**: Read-write access to entire project

### Environment Variables

```bash
SYSTEM_NAME=quit-smoking-bot
SYSTEM_DISPLAY_NAME=Quit Smoking Bot
```

These variables are used by the project scripts for:
- Container naming conventions
- Service identification
- Display purposes in logs and output

### Development Tools Available

| Tool | Purpose | Usage Example |
|------|---------|---------------|
| `git` | Version control | `git status`, `git commit` |
| `curl` | HTTP requests | `curl -s https://api.telegram.org/bot<token>/getMe` |
| `jq` | JSON processing | `cat data/bot_users.json \| jq .` |
| `docker` | Container management | `docker ps`, `docker build` |
| `docker-compose` | Service orchestration | `docker-compose up -d` |
| `python3` | Bot execution | `python3 -m src.bot` |
| `pip3` | Package management | `pip3 install -r requirements.txt` |
| `vim/nano` | Text editing | `vim scripts/run.sh` |
| `htop` | Process monitoring | `htop` |

## Docker-in-Docker Configuration

### Socket Mounting

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

**Capabilities:**
- **Host Docker access**: Use host Docker daemon
- **Container management**: Build, run, stop containers
- **Image operations**: Pull, push, build images
- **Network access**: Access Docker networks

### Usage Examples

```bash
# Inside development container

# Build the main project image
docker build -t quit-smoking-bot .

# Run the main project with docker-compose
docker-compose up -d

# Test Docker functionality
docker run --rm hello-world

# Inspect running containers
docker ps

# View container logs
docker-compose logs bot
```

### Security Considerations

- **Host access**: Container can manage host Docker
- **Privilege escalation**: Docker group membership
- **Resource sharing**: Shares host Docker resources
- **Network access**: Can access Docker networks

## systemd Integration

### Standard vs systemd Mode

| Feature | dev-env | dev-env-systemd |
|---------|---------|-----------------|
| **Process init** | `/bin/bash` | `/sbin/init` |
| **Privileged** | No | Yes |
| **systemctl** | Limited | Full support |
| **Service testing** | No | Yes |
| **cgroup access** | No | Yes |

### systemd Service Testing

In `dev-env-systemd` mode, you can:

```bash
# Install bot as systemd service
sudo ./scripts/install-service.sh --token YOUR_TOKEN

# Manage service with systemctl
sudo systemctl start quit-smoking-bot.service
sudo systemctl status quit-smoking-bot.service
sudo systemctl stop quit-smoking-bot.service

# View service logs
sudo journalctl -u quit-smoking-bot.service -f

# Uninstall service
sudo ./scripts/uninstall-service.sh
```

### systemd Configuration

```dockerfile
# Configure systemd (for service testing)
RUN systemctl set-default multi-user.target
```

This configures systemd for multi-user mode without GUI components.

## Volume Management

### Volume Types

1. **Project Mount** (`../:/workspace`)
   - **Type**: Bind mount
   - **Purpose**: Direct access to project files
   - **Persistence**: Changes immediately reflected on host

2. **Docker Socket** (`/var/run/docker.sock:/var/run/docker.sock`)
   - **Type**: Bind mount
   - **Purpose**: Docker-in-Docker functionality
   - **Security**: Full Docker daemon access

3. **Home Directory** (`dev-home:/home/developer`)
   - **Type**: Named volume
   - **Purpose**: Persistent user environment
   - **Contents**: Shell history, configurations, development files

4. **systemd Volumes** (systemd mode only)
   - **cgroup**: `/sys/fs/cgroup:/sys/fs/cgroup:ro`
   - **tmpfs**: `/tmp`, `/run`, `/run/lock`

### Volume Benefits

- **Persistence**: Development settings survive container restarts
- **Performance**: Native filesystem performance for project files
- **Flexibility**: Easy backup and migration of development environment
- **Isolation**: Separate environments for different users/projects

## Security Configuration

### User Security

```dockerfile
RUN useradd -m -s /bin/bash -G docker developer \
    && echo 'developer ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
```

**Security Features:**
- **Non-root execution**: Primary work done as `developer` user
- **Controlled privileges**: Sudo access for system operations
- **Docker group**: Direct Docker access without sudo
- **Isolated environment**: Container isolation from host

### Privileged Mode (systemd only)

```yaml
privileged: true
```

**Implications:**
- **Full system access**: Container can access host kernel features
- **Required for systemd**: Necessary for proper systemd operation
- **Security trade-off**: Increased access for testing capabilities
- **Testing only**: Should not be used in production

### Best Practices

1. **Use standard mode** for most development tasks
2. **Use systemd mode** only when testing services
3. **Don't store secrets** in the container
4. **Regular cleanup** of containers and volumes

## Usage Patterns

### Development Workflow

```bash
# 1. Start development environment
./development/start-dev.sh

# 2. Inside container - test scripts
cd /workspace
./development/scripts/test-scripts.sh

# 3. Run bot in development mode
./scripts/run.sh --development

# 4. Test Docker functionality
docker-compose up -d bot
docker-compose logs -f bot

# 5. Exit and cleanup
exit
# Outside container
cd development && docker-compose down
```

### Service Testing Workflow

```bash
# 1. Start systemd environment
./development/start-dev.sh --systemd

# 2. Inside container - install service
sudo ./scripts/install-service.sh --token YOUR_TOKEN

# 3. Test service management
sudo systemctl status quit-smoking-bot.service
sudo journalctl -u quit-smoking-bot.service -f

# 4. Cleanup
sudo ./scripts/uninstall-service.sh
exit
```

### Continuous Testing

```bash
# Background development environment
./development/start-dev.sh --detach

# Connect when needed
cd development && docker-compose exec dev-env bash

# Run comprehensive tests
./development/scripts/test-scripts.sh

# Stop when done
docker-compose down
```

## Troubleshooting

### Common Issues

#### 1. Docker Socket Permission Denied

```bash
# Error: permission denied while trying to connect to Docker daemon
# Solution: Ensure user is in docker group
sudo usermod -aG docker $USER
# Then rebuild container
```

#### 2. systemd Not Working

```bash
# Error: systemctl commands fail
# Solution: Use systemd mode
./development/start-dev.sh --systemd

# Or check if running in privileged mode
docker inspect quit-smoking-bot-dev-systemd | grep Privileged
```

#### 3. Volume Permission Issues

```bash
# Error: Permission denied accessing /workspace files
# Solution: Check file permissions on host
ls -la ../
# Fix permissions if needed
sudo chown -R $(id -u):$(id -g) ../
```

#### 4. Container Won't Start

```bash
# Check container logs
docker-compose logs dev-env

# Check if ports are in use
docker ps

# Rebuild container
docker-compose build --no-cache dev-env
```

### Diagnostic Commands

```bash
# Container status
docker-compose ps

# Container logs
docker-compose logs -f dev-env

# Execute commands in running container
docker-compose exec dev-env bash

# Check Docker-in-Docker
docker-compose exec dev-env docker version

# Check systemd status (systemd mode)
docker-compose exec dev-env-systemd systemctl status

# Volume inspection
docker volume ls
docker volume inspect development_dev-home
```

## Best Practices

### Development Best Practices

1. **Use appropriate mode**:
   - Standard mode for general development
   - systemd mode only for service testing

2. **Manage resources**:
   ```bash
   # Stop containers when not needed
   docker-compose down
   
   # Clean up periodically
   docker system prune -f
   ```

3. **Backup important data**:
   ```bash
   # Backup development volume
   docker run --rm -v development_dev-home:/data -v $(pwd):/backup ubuntu tar czf /backup/dev-home-backup.tar.gz -C /data .
   ```

### Security Best Practices

1. **Don't store secrets** in container or volumes
2. **Use standard mode** unless systemd testing required
3. **Regular updates**:
   ```bash
   # Rebuild with latest base image
   docker-compose build --no-cache --pull dev-env
   ```

4. **Limit exposure**:
   - Don't expose unnecessary ports
   - Use isolated networks when possible

### Performance Best Practices

1. **Use .dockerignore** to exclude unnecessary files:
   ```gitignore
   .git/
   logs/
   data/
   *.log
   ```

2. **Layer caching**:
   - Install packages before copying code
   - Group related operations

3. **Volume optimization**:
   - Use named volumes for persistent data
   - Bind mount only necessary directories

---

## Summary

The development environment Docker configuration provides:

- **Comprehensive testing platform** with full Linux compatibility
- **Docker-in-Docker capability** for container testing
- **systemd integration** for service testing
- **Development-friendly tools** and environment
- **Persistent development state** across sessions
- **Cross-platform consistency** for all developers

This setup enables thorough testing of the Quit Smoking Bot project in an isolated, reproducible environment that closely matches production Linux systems. 