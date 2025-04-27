# Docker Configuration for Quit Smoking Bot

This document provides a comprehensive overview of the Docker setup for the Quit Smoking Bot project, including container lifecycle, networking, configuration, and advanced usage.

## Overview

The Quit Smoking Bot is containerized using Docker to ensure consistent and reliable operation across different environments. The Docker implementation provides:

- Isolated execution environment
- Automatic dependency management
- Configuration through environment variables
- Persistent data storage with volumes
- Health monitoring and self-healing capabilities
- Resource control and limitation
- Standardized deployment process

## Container Architecture

The project uses a multi-container setup defined in `docker-compose.yml`:

1. **Main Bot Service** (`bot`): The primary container running the Telegram bot
2. **Test Service** (`test`): A separate container for running integration tests

Both services share the same base image but have different configurations and entrypoints.

### Directory Structure in Container

```
/app/                    # Application root directory
├── src/                 # Source code
├── tests/               # Test files
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
# Base image - slim Python for smaller footprint
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

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    apt-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup application
WORKDIR /app
COPY setup.py /app/
RUN pip install --no-cache-dir -e . requests pytest setuptools

# Prepare directories with proper permissions
RUN mkdir -p /app/data /app/logs /app/health \
    && chown -R appuser:appuser /app \
    && chmod 755 /app /app/data /app/logs /app/health

# Copy application code
COPY --chown=appuser:appuser . .
RUN chmod +x /app/scripts/*.sh

# Switch to non-root user
USER appuser
ENV PATH="/home/appuser/.local/bin:${PATH}"

# Define volumes for persistence
VOLUME /app/data
VOLUME /app/logs

# Configure entrypoint and health check
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /app/scripts/healthcheck.sh
```

### Key Dockerfile Components

1. **Base Image**: Uses Python 3.9 slim for a smaller footprint while maintaining Python functionality
2. **Environment Setup**: Configures timezone and Python settings
3. **Security**: Creates a non-root user to run the application
4. **Dependencies**: Installs minimal required system packages
5. **Application**: Copies code and installs Python dependencies
6. **Permissions**: Sets appropriate permissions for directories
7. **Volumes**: Defines persistent storage for data and logs
8. **Entrypoint**: Uses custom script for initialization and startup
9. **Health Check**: Configures container health monitoring

## Docker Compose Configuration

The `docker-compose.yml` file orchestrates the services:

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
    image: ${SYSTEM_NAME:-quit-smoking-bot}
    container_name: ${SYSTEM_NAME:-quit-smoking-bot}
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
    env_file:
      - .env
    volumes:
      - ./data:/app/data:rw
      - ./logs:/app/logs:rw
    environment:
      - TZ=Asia/Novosibirsk
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "/app/scripts/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - bot-network

  test:
    build:
      context: .
      args:
        - USER_ID=${USER_ID:-1000}
        - GROUP_ID=${GROUP_ID:-1000}
    image: ${SYSTEM_NAME:-quit-smoking-bot}-test
    container_name: ${SYSTEM_NAME:-quit-smoking-bot}-test
    profiles: ["test"]
    env_file:
      - .env
    volumes:
      - ./data:/app/data:ro
      - ./logs:/app/logs:rw
    environment:
      - TZ=Asia/Novosibirsk
      - PYTHONUNBUFFERED=1
    command: python -m tests.integration.test_notifications --token "$BOT_TOKEN"
    entrypoint: []
    networks:
      - bot-network

networks:
  bot-network:
    driver: bridge
```

### Key Docker Compose Components

1. **Services**: Defines bot and test services
2. **Build Arguments**: Passes user and group IDs for proper permissions matching
3. **Container Names**: Uses environment variables for consistent naming
4. **Restart Policy**: Configures automatic restart on failure
5. **Resource Limits**: Controls memory usage
6. **Volumes**: Maps data and logs directories to host for persistence
7. **Environment**: Sets required environment variables
8. **Health Check**: Configures container health monitoring
9. **Logging**: Sets up log rotation and format
10. **Networks**: Creates isolated network for containers
11. **Profiles**: Enables selective service execution (test container only runs when explicitly specified)

## Container Lifecycle

### Startup Process

When the container starts, the `entrypoint.sh` script performs several initialization steps:

1. **Health System Setup**: Initializes health monitoring directories and files
2. **Log Rotation**: Rotates logs to prevent large log files
3. **Data Directory Setup**: Creates required data files if missing
4. **Process Management**: Terminates any existing bot instances to prevent conflicts
5. **Health Monitor**: Starts a background process that monitors bot health
6. **Bot Startup**: Launches the Python bot application

### Health Monitoring

The health monitoring system consists of:

1. **Background Monitor** (in `entrypoint.sh`): Continuously checks if the bot process is running and updates the health marker file
2. **Health Check Script** (`healthcheck.sh`): Runs periodically by Docker to determine container health status
3. **Operational File**: Acts as a marker that the bot is fully operational

The health check script performs these checks:

1. Verifies that the bot process is running
2. Confirms the operational marker file exists and is fresh
3. Scans logs for critical errors or conflict patterns
4. Reports container status back to Docker

If health checks repeatedly fail, Docker's restart policy will attempt to recover the container.

### Shutdown Process

The bot handles graceful shutdown through signal handlers in the Python application that:

1. Stop accepting new commands
2. Complete any in-progress operations
3. Save state if necessary
4. Release resources
5. Remove the operational marker file

## Networking

The project uses a dedicated bridge network (`bot-network`) to:

1. Isolate container traffic
2. Enable communication between services
3. Provide DNS resolution between containers
4. Maintain security through network isolation

No ports are exposed to the host by default, as the Telegram bot communicates outbound to the Telegram API and doesn't require incoming connections.

## Data Persistence

Two Docker volumes are configured for data persistence:

1. **Data Volume** (`/app/data`): Stores user information, admin lists, and quotes
2. **Logs Volume** (`/app/logs`): Contains application logs for monitoring and debugging

These volumes are mapped to host directories to ensure data persists across container restarts and updates.

## Resource Management

The container has resource limits configured to:

1. Set maximum memory usage (256MB)
2. Reserve minimum memory (128MB)
3. Prevent resource exhaustion on the host

These limits ensure the bot operates efficiently while preventing it from consuming excessive resources.

## Build Process

When building the Docker image:

1. Base image is pulled from Docker Hub
2. System dependencies are installed
3. Python dependencies are installed
4. Application code is copied
5. Permissions are set
6. Entrypoint and health check are configured

Build arguments allow customization:
- `USER_ID`: ID for the container user (default: 1000)
- `GROUP_ID`: ID for the container group (default: 1000)
- `BUILD_ID`: Identifier for the build (default: latest)

## Advanced Usage

### Custom User/Group IDs

To run the container with the same user ID as the host system:

```bash
USER_ID=$(id -u) GROUP_ID=$(id -g) ./scripts/run.sh
```

### Forcing a Rebuild

To rebuild the image without using cache:

```bash
./scripts/run.sh --force-rebuild
```

### Manual Health Check

To check the container's health status:

```bash
docker inspect --format='{{.State.Health.Status}}' quit-smoking-bot
```

### Viewing Health Check Logs

```bash
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' quit-smoking-bot
```

### Running Tests

```bash
docker-compose run --rm test
```

Or using the script:

```bash
./scripts/test.sh
```

## Troubleshooting

### Container Fails to Start

1. Check logs for errors:
   ```bash
   docker logs quit-smoking-bot
   ```

2. Verify environment variables are properly set in `.env` file

3. Check for port conflicts if you've modified the configuration to expose ports

### Health Check Failures

1. Check health status:
   ```bash
   docker inspect --format='{{.State.Health.Status}}' quit-smoking-bot
   ```

2. View health check logs:
   ```bash
   docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' quit-smoking-bot
   ```

3. Examine container logs:
   ```bash
   docker logs quit-smoking-bot
   ```

4. Check the health status file inside the container:
   ```bash
   docker exec quit-smoking-bot cat /app/health/status.log
   ```

### Resource Constraints

If the container is being terminated due to resource limits:

1. Increase memory limits in `docker-compose.yml`
2. Ensure the host has sufficient resources available
3. Check if other containers or processes are consuming resources

## Security Considerations

The Docker implementation includes several security features:

1. **Non-root User**: Container runs as a non-privileged user
2. **Minimal Base Image**: Uses slim image to reduce attack surface
3. **No Exposed Ports**: No unnecessary network exposure
4. **Minimal Dependencies**: Only essential packages are installed
5. **Volume Permissions**: Proper file permissions for mounted volumes

## Summary

The Docker configuration for the Quit Smoking Bot provides a robust, secure, and maintainable environment for running the application. The configuration focuses on:

- **Security**: Running as non-root with minimal permissions
- **Reliability**: Health checks and automatic recovery
- **Maintainability**: Clear structure and separation of concerns
- **Performance**: Resource limits and optimized image
- **Flexibility**: Environment variable configuration

By leveraging Docker, the bot can be consistently deployed across different environments while maintaining predictable behavior and performance.

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