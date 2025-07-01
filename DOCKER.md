# Docker Configuration for Quit Smoking Bot

This document provides a comprehensive overview of the Docker setup for the Quit Smoking Bot project, including container lifecycle, networking, configuration, and advanced usage.

## Overview

The Quit Smoking Bot is fully containerized using **Docker Compose** to ensure consistent and reliable operation across different environments. The Docker implementation provides:

- **Pure Container Architecture**: No systemd, supervisor, or host system dependencies
- **Isolated execution environment**: Complete process and network isolation
- **Automatic dependency management**: All dependencies contained within images
- **Configuration through environment variables**: 12-factor app methodology
- **Persistent data storage with volumes**: Data survives container updates
- **Health monitoring and self-healing**: Built-in Docker health checks
- **Resource control and limitation**: Container-level resource management
- **Standardized deployment process**: Identical deployment across environments

## Container Architecture

The project uses a modern multi-container setup defined in `docker-compose.yml`:

### Core Services

1. **Main Bot Service** (`bot`): The primary container running the Telegram bot
   - **Restart Policy**: `unless-stopped` for automatic recovery
   - **Health Checks**: Custom health monitoring every 30 seconds
   - **Resource Limits**: 256MB memory limit with 128MB reservation
   - **Logging**: JSON format with automatic rotation (10MB, 5 files)
   - **Profile-based**: Only runs when explicitly requested
   

### Additional Services (Profile-based)

3. **Health Monitor Service** (`health-monitor`): Advanced health monitoring
   - **Profile**: `monitoring`
   - **Purpose**: Extended health metrics and alerting

4. **Log Aggregator Service** (`log-aggregator`): Centralized logging
   - **Profile**: `logging`  
   - **Purpose**: Log collection, processing, and rotation

All services share the same base image but have different configurations and entrypoints, following the DRY principle while maintaining service isolation.

### Directory Structure in Container

```
/app/                    # Application root directory
├── src/                 # Source code

├── scripts/             # Shell scripts
├── data/                # Persistent data (volume)
│   ├── bot_users.json   # User data
│   ├── bot_admins.json  # Admin data
│   └── quotes.json      # Motivational quotes
├── logs/                # Log files (volume)
│   └── bot.log          # Main log file
└── health/              # Health check data
    ├── operational      # Health status marker
    └── status.log       # Health monitoring logs
```

## Dockerfile Explained

The `Dockerfile` uses a multi-stage build process to create an optimized image:

```dockerfile
# Multi-stage build for optimized image size
FROM python:3.9-slim as base

# Environment variable configuration
ENV TZ=Asia/Novosibirsk \
    PYTHONUNBUFFERED=1 \
    IN_CONTAINER=true \
    BUILD_ID=latest

# Set timezone for proper scheduling
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Create non-root user for security
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} appuser && \
    useradd -m -u ${USER_ID} -g appuser appuser

# Install minimal system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    apt-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup application
WORKDIR /app
COPY setup.py /app/
RUN pip install --no-cache-dir -e . requests setuptools

# Prepare directories with proper permissions
RUN mkdir -p /app/data /app/logs /app/health \
    && chown -R appuser:appuser /app \
    && chmod 755 /app /app/data /app/logs /app/health

# Copy application code
COPY --chown=appuser:appuser . .
RUN chmod +x /app/scripts/*.sh

# Switch to non-root user for security
USER appuser
ENV PATH="/home/appuser/.local/bin:${PATH}"

# Define volumes for persistence
VOLUME /app/data
VOLUME /app/logs

# Configure entrypoint and health check
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /app/scripts/health.sh --mode docker
```

### Key Dockerfile Components

1. **Base Image**: Python 3.9 slim for minimal footprint while maintaining functionality
2. **Environment Setup**: Configures timezone and Python settings for container execution
3. **Security**: Creates non-root user to run the application (principle of least privilege)
4. **Dependencies**: Installs only essential system packages to reduce attack surface
5. **Application**: Copies code and installs Python dependencies
6. **Permissions**: Sets appropriate permissions for directories and files
7. **Volumes**: Defines persistent storage for data and logs
8. **Entrypoint**: Uses custom script for initialization and startup
9. **Health Check**: Configures container health monitoring with Docker native features

## Docker Compose Configuration

The `docker-compose.yml` file orchestrates the services using modern Docker Compose features:

```yaml
version: '3.8'

services:
  bot:
    build:
      context: .
      args:
        - USER_ID=${USER_ID:-1000}
        - GROUP_ID=${GROUP_ID:-1000}
        - BUILD_ID=${BUILD_ID:-latest}
    image: ${SYSTEM_NAME:-quit-smoking-bot}:latest
    container_name: ${SYSTEM_NAME:-quit-smoking-bot}
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
        reservations:
          memory: 128M
          cpus: '0.25'
    env_file:
      - .env
    volumes:
      - ./data:/app/data:rw
      - ./logs:/app/logs:rw
    environment:
      - TZ=Asia/Novosibirsk
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "/app/scripts/health.sh", "--mode", "docker"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        compress: "true"
    networks:
      - bot-network

  # Extended services available via profiles
  health-monitor:
    profiles: ["monitoring"]
    build:
      context: .
      args:
        - USER_ID=${USER_ID:-1000}
        - GROUP_ID=${GROUP_ID:-1000}
    image: ${SYSTEM_NAME:-quit-smoking-bot}:latest
    container_name: ${SYSTEM_NAME:-quit-smoking-bot}-monitor
    restart: unless-stopped
    depends_on:
      - bot
    volumes:
      - ./logs:/app/logs:ro
    networks:
      - bot-network

  log-aggregator:
    profiles: ["logging"]
    build:
      context: .
      args:
        - USER_ID=${USER_ID:-1000}
        - GROUP_ID=${GROUP_ID:-1000}
    image: ${SYSTEM_NAME:-quit-smoking-bot}:latest
    container_name: ${SYSTEM_NAME:-quit-smoking-bot}-logs
    restart: unless-stopped
    depends_on:
      - bot
    volumes:
      - ./logs:/app/logs:rw
    networks:
      - bot-network

networks:
  bot-network:
    driver: bridge
    name: ${SYSTEM_NAME:-quit-smoking-bot}-network
```

### Key Docker Compose Components

1. **Services**: Defines multiple services with profile-based activation
2. **Build Arguments**: Passes user and group IDs for proper permission matching
3. **Container Names**: Uses environment variables for consistent, configurable naming
4. **Restart Policy**: `unless-stopped` for automatic recovery without manual intervention
5. **Resource Limits**: Controls CPU and memory usage with limits and reservations
6. **Volumes**: Maps data and logs directories to host for persistence across updates
7. **Environment**: Sets required environment variables for container execution
8. **Health Check**: Configures native Docker health monitoring with custom scripts
9. **Logging**: Sets up JSON logging with rotation, compression, and size limits
10. **Networks**: Creates isolated bridge network for inter-container communication
11. **Profiles**: Enables selective service execution (monitoring, logging)
12. **Dependencies**: Defines service startup order and dependencies

## Container Lifecycle

### Startup Process

When the container starts, the `entrypoint.sh` script performs initialization:

1. **Environment Validation**: Checks required environment variables
2. **Health System Setup**: Initializes health monitoring directories and files
3. **Log Management**: Sets up log rotation and directory permissions
4. **Data Directory Setup**: Creates required data files if missing
5. **Process Management**: Terminates any existing bot instances to prevent conflicts
6. **Health Monitor**: Starts background health monitoring process
7. **Bot Startup**: Launches the Python bot application with proper signal handling

### Health Monitoring System

The comprehensive health monitoring consists of:

1. **Background Monitor** (in `entrypoint.sh`): 
   - Continuously monitors bot process status
   - Updates health marker files
   - Tracks resource usage
   - Logs health status changes

2. **Docker Health Check** (`health.sh`): 
   - Runs every 30 seconds by Docker daemon
   - Performs comprehensive health validation
   - Reports status to Docker for restart decisions

3. **Health Markers**: 
   - `operational` file: Indicates bot is fully functional
   - `status.log`: Detailed health monitoring logs
   - Process validation: Confirms bot process is running

The health check script performs these validations:

1. **Process Check**: Verifies bot process is running
2. **Operational File**: Confirms health marker exists and is current
3. **Log Analysis**: Scans for critical errors or conflict patterns
4. **API Connectivity**: Validates Telegram API communication
5. **Resource Monitoring**: Checks memory and CPU usage

If health checks fail repeatedly, Docker's restart policy automatically recovers the container.

### Shutdown Process

The bot handles graceful shutdown through Python signal handlers:

1. **Signal Reception**: Captures SIGTERM/SIGINT signals
2. **Graceful Stop**: Stops accepting new commands
3. **Operation Completion**: Finishes in-progress operations
4. **State Persistence**: Saves any pending state changes
5. **Resource Cleanup**: Releases file handles and connections
6. **Health Cleanup**: Removes operational marker files

## Service Management (No systemd/supervisor)

Unlike traditional deployments, this bot uses **pure Docker Compose** for service management:

### Traditional vs. Docker Approach

❌ **Traditional (systemd/supervisor)**:
- Requires root access for service installation
- System-specific configuration files
- Manual dependency management
- Complex log rotation setup
- OS-specific service commands

✅ **Docker Compose**:
- No root access required (after Docker installation)
- Portable configuration across all systems
- Automatic dependency resolution
- Built-in log management
- Consistent commands across platforms

### Service Management Commands

```bash
# Start services
docker-compose up -d

# Stop services  
docker-compose down

# Restart services
docker-compose restart

# View service status
docker-compose ps

# Follow logs
docker-compose logs -f

# Scale services (if needed)
docker-compose up -d --scale bot=2
```

### Advantages of Docker-only Approach

1. **Simplicity**: No complex service manager configuration
2. **Portability**: Works identically on any Docker-capable system
3. **Isolation**: Complete process and filesystem isolation
4. **Consistency**: Same behavior in development and production
5. **Updates**: Easy to update by rebuilding containers
6. **Rollback**: Simple rollback by switching image tags

## Networking

The project uses a dedicated bridge network (`bot-network`) for:

1. **Service Isolation**: Containers communicate only within the network
2. **DNS Resolution**: Services can reach each other by service name
3. **Security**: Network traffic is isolated from host and other containers
4. **Scalability**: Easy to add new services to the same network

Network configuration:
- **Driver**: Bridge (standard Docker networking)
- **Name**: Configurable via `SYSTEM_NAME` environment variable
- **Scope**: Local to the Docker Compose stack
- **Port Exposure**: No ports exposed to host (outbound API calls only)

## Data Persistence

Two Docker volumes ensure data persists across container lifecycles:

### Data Volume (`/app/data`)
- **Purpose**: Stores user information, admin lists, and quotes
- **Mount**: `./data:/app/data:rw` (read-write)
- **Backup**: Easy to backup by copying the `data` directory
- **Migration**: Portable data format (JSON files)

### Logs Volume (`/app/logs`)  
- **Purpose**: Contains application logs for monitoring and debugging
- **Mount**: `./logs:/app/logs:rw` (read-write)
- **Rotation**: Automatic log rotation with Docker logging driver
- **Analysis**: Standard log format for easy parsing

### Volume Benefits
- **Persistence**: Data survives container restarts and updates
- **Performance**: Native filesystem performance
- **Accessibility**: Direct access from host for backup/analysis
- **Portability**: Easy to migrate between systems

## Resource Management

Container resource management ensures stable operation:

### Memory Management
- **Limit**: 256MB maximum memory usage
- **Reservation**: 128MB guaranteed memory allocation
- **Swap**: Limited to prevent system impact
- **OOM Handling**: Container restart on out-of-memory

### CPU Management
- **Limit**: 0.5 CPU cores maximum
- **Reservation**: 0.25 CPU cores guaranteed
- **Scheduling**: CFS (Completely Fair Scheduler)
- **Throttling**: Automatic CPU throttling when limit exceeded

### Benefits
- **System Stability**: Prevents resource exhaustion
- **Predictable Performance**: Guaranteed resource allocation
- **Cost Control**: Efficient resource utilization
- **Monitoring**: Easy resource usage tracking

## Build Process

The Docker build process is optimized for efficiency:

### Build Stages
1. **Base Setup**: Install system dependencies
2. **User Creation**: Create non-root user for security
3. **Application Install**: Install Python dependencies
4. **Code Copy**: Copy application code with proper permissions
5. **Configuration**: Set entrypoint and health check

### Build Arguments
- `USER_ID`: Container user ID (default: 1000)
- `GROUP_ID`: Container group ID (default: 1000)  
- `BUILD_ID`: Build identifier for versioning (default: latest)

### Build Optimization
- **Layer Caching**: Efficient Docker layer caching strategy
- **Minimal Base**: Python slim image for reduced size
- **Multi-stage**: Separate build and runtime environments
- **Dependency Order**: Dependencies installed before code copy for better caching

## Advanced Usage

### Profile-based Services

Start additional services using profiles:

```bash
# Start with health monitoring
./scripts/run.sh --monitoring
# or
docker-compose --profile monitoring up -d

# Start with log aggregation  
./scripts/run.sh --logging
# or
docker-compose --profile logging up -d

# Start all services
docker-compose --profile monitoring --profile logging up -d
```

### Custom User/Group IDs

Match container user with host user for proper file permissions:

```bash
USER_ID=$(id -u) GROUP_ID=$(id -g) ./scripts/run.sh
```

### Development Mode

For development with hot reloading:

```bash
# Mount source code as volume for development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Forcing Rebuilds

Force complete image rebuild without cache:

```bash
./scripts/run.sh --force-rebuild
# or
docker-compose build --no-cache
```

### Health Check Monitoring

Monitor container health status:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' quit-smoking-bot

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{"\n"}}{{end}}' quit-smoking-bot

# Follow health status changes
watch -n 5 'docker inspect --format="{{.State.Health.Status}}" quit-smoking-bot'
```

### Log Management

Advanced log management options:

```bash
# View logs with timestamps
docker-compose logs -f -t bot

# View logs from specific time
docker-compose logs --since 2h bot

# Export logs for analysis
docker-compose logs --no-color bot > bot-logs.txt

# Real-time log analysis
docker-compose logs -f bot | grep ERROR
```



## Troubleshooting

### Container Startup Issues

1. **Check container logs**:
   ```bash
   docker-compose logs bot
   ```

2. **Verify environment configuration**:
   ```bash
   docker-compose config
   ```

3. **Check resource availability**:
   ```bash
   docker system info
   docker system df
   ```

### Health Check Failures

1. **Monitor health status**:
   ```bash
   ./scripts/check-service.sh
   ```

2. **View detailed health logs**:
   ```bash
   docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{"\n"}}{{end}}' quit-smoking-bot
   ```

3. **Check health files inside container**:
   ```bash
   docker exec quit-smoking-bot ls -la /app/health/
   docker exec quit-smoking-bot cat /app/health/status.log
   ```

### Network Issues

1. **Verify network configuration**:
   ```bash
   docker network ls
   docker network inspect quit-smoking-bot-network
   ```

2. **Bot container connectivity**:
   ```bash
   docker exec quit-smoking-bot ping -c 3 api.telegram.org
   ```

### Resource Constraints

1. **Monitor resource usage**:
   ```bash
   docker stats quit-smoking-bot
   ```

2. **Adjust resource limits**:
   Edit `docker-compose.yml` and increase memory/CPU limits

3. **Clean up unused resources**:
   ```bash
   docker system prune -f
   docker volume prune -f
   ```

## Security Considerations

The Docker implementation prioritizes security:

### Container Security
- **Non-root Execution**: All processes run as non-privileged user
- **Minimal Base Image**: Reduced attack surface with slim image
- **No Privileged Access**: Container runs without elevated privileges
- **Resource Limits**: Prevents resource-based attacks

### Network Security
- **No Exposed Ports**: No unnecessary network exposure
- **Isolated Network**: Dedicated network for service communication
- **Outbound Only**: Only outbound connections to Telegram API
- **No Host Network**: Network isolation from host system

### Data Security
- **Volume Permissions**: Proper file permissions on mounted volumes
- **User Matching**: Container user matches host user for file access

- **Log Rotation**: Prevents log files from consuming excessive disk space

### Operational Security
- **Health Monitoring**: Automatic detection of compromised containers
- **Automatic Restart**: Quick recovery from security incidents
- **Immutable Infrastructure**: Containers are replaced, not patched
- **Environment Isolation**: Complete isolation from host system

## Performance Optimization

### Image Optimization
- **Multi-stage Build**: Minimizes final image size
- **Layer Caching**: Optimizes build times
- **Dependency Order**: Efficient Docker layer utilization
- **Minimal Dependencies**: Only essential packages included

### Runtime Optimization
- **Resource Limits**: Prevents resource contention
- **Health Checks**: Early detection of performance issues
- **Log Rotation**: Prevents disk space exhaustion
- **Process Management**: Efficient process lifecycle management

### Monitoring and Metrics
- **Health Status**: Real-time health monitoring
- **Resource Usage**: CPU and memory tracking
- **Log Analysis**: Performance metrics from logs
- **Container Stats**: Docker native monitoring

## Summary

The Docker configuration for the Quit Smoking Bot represents a modern, cloud-native approach to application deployment:

### Key Benefits
- **✅ Simplicity**: No complex service managers or system dependencies
- **✅ Portability**: Runs identically on any Docker-capable system  
- **✅ Reliability**: Automatic restart and comprehensive health monitoring
- **✅ Security**: Process isolation and non-root execution
- **✅ Scalability**: Easy to extend with additional services
- **✅ Maintainability**: Clear separation of concerns and standardized operations

### Architecture Advantages
- **Pure Container Deployment**: No systemd, supervisor, or host dependencies
- **Profile-based Services**: Optional services activated on demand
- **Resource Management**: Container-level CPU and memory controls
- **Health Monitoring**: Multi-layer health checking and automatic recovery
- **Data Persistence**: Reliable data storage with Docker volumes
- **Network Isolation**: Secure inter-service communication

This Docker-first approach ensures the bot can be consistently deployed across development and production environments while maintaining high reliability and security standards.

## Local Development Environment

For local development without Docker, a Python virtual environment is recommended:

1. Install development dependencies:
   ```bash
   python3 -m pip install -r requirements-dev.txt
   ```

2. This installs:
   - `setuptools`: For package management
   - Project dependencies: Through the `-e .` editable install

The editable install (`-e .`) allows you to modify the code and have changes take effect immediately without reinstalling the package.
