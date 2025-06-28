# Development Environment

This directory contains tools for quickly deploying a Linux development environment for testing scripts on any operating system using Docker.

## Quick Start

### Option 1: Interactive Start Script (Recommended)

```bash
# Start full development environment (with systemd)
./development/start-dev.sh

# Start lightweight environment (without systemd)
./development/start-dev.sh --basic

# Start in background mode
./development/start-dev.sh --detach

# Force rebuild and clean start
./development/start-dev.sh --build --clean
```

### Option 2: Using Makefile

```bash
cd development

make start          # Start full environment (with systemd)
make start-basic    # Start lightweight environment (no systemd)
make start-detached # Start in background
make stop           # Stop environment
make build          # Build environment
make clean          # Interactive cleanup
make clean-all      # Complete cleanup (all resources)
make clean-force    # Force cleanup without confirmation
make test           # Run comprehensive tests
make shell          # Connect to running environment
make help           # Show all available commands
```

### Option 3: Direct Docker Compose

```bash
cd development

# Interactive session
docker-compose run --rm dev-env

# Background service
docker-compose up -d dev-env
docker-compose exec dev-env bash

# Stop
docker-compose down
```

## What's Included

- **Ubuntu 22.04** base system
- **Docker + docker-compose** for container testing
- **systemd** for service testing (in `--systemd` mode)
- **Python 3.10+** with pip
- **Development tools**: curl, jq, git, nano, vim, bash-completion
- **Project mounted** at `/workspace`
- **Persistent home directory** for your development files

## Directory Structure

```
development/
├── README.md              # This file
├── start-dev.sh           # Main development environment launcher
├── Dockerfile             # Ubuntu 22.04 development image
├── docker-compose.yml     # Container orchestration
├── Makefile              # Convenient development commands
└── scripts/
    ├── setup-env.sh       # Environment setup inside container
    └── test-scripts.sh    # Comprehensive script testing
```

## start-dev.sh Usage

The `start-dev.sh` script is the main entry point for the development environment.

### Command Line Options

- `--basic` - Start lightweight environment without systemd
- `--build` - Force rebuild of development image
- `--clean` - Clean up containers and volumes before starting
- `--detach` - Start in detached mode (background)
- `--help` - Show help message

### Examples

```bash
# Full development environment (default - with systemd)
./development/start-dev.sh

# Lightweight development (without systemd)
./development/start-dev.sh --basic

# Background development server
./development/start-dev.sh --detach

# Clean rebuild
./development/start-dev.sh --clean --build

# Connect to running background instance
cd development && make shell
```

## Development Environments

### Full Environment (`dev-env`)

- **Purpose**: Complete development and service testing (default)
- **Features**: Docker daemon, systemd support, privileged mode, Python tools
- **Command**: `./start-dev.sh` or `make start`
- **Use for**: All development tasks, script testing, service installation, Docker operations

### Lightweight Environment (`dev-env-basic`)

- **Purpose**: Basic development and simple testing
- **Features**: Docker-in-Docker (no daemon), Python development tools
- **Command**: `./start-dev.sh --basic` or `make start-basic`
- **Use for**: Simple script testing, basic development (when systemd not needed)

## Common Development Tasks

### 1. Testing Scripts

```bash
# Inside the container
cd /workspace

# Test all scripts comprehensively
./development/scripts/test-scripts.sh

# Test specific functionality
./scripts/run.sh --help
./scripts/test.sh
```

### 2. Service Installation Testing

```bash
# Start full environment (systemd enabled by default)
./development/start-dev.sh

# Inside the container
sudo ./scripts/install-service.sh --token YOUR_BOT_TOKEN
sudo systemctl status quit-smoking-bot.service
sudo journalctl -u quit-smoking-bot.service -f
```

### 3. Environment Setup

```bash
# Inside any container
./development/scripts/setup-env.sh

# This will:
# - Create default .env file
# - Set script permissions
# - Create necessary directories
# - Test Docker and systemd availability
```

### 4. Background Development

```bash
# Start in background
./development/start-dev.sh --detach

# Connect when needed
cd development && make shell

# Or directly
docker-compose exec dev-env bash

# Stop when done
make stop
```

## Cleanup System

The development environment includes a comprehensive cleanup system that mirrors the production cleanup functionality. This system helps manage Docker resources and keep your development environment clean.

### Cleanup Commands

#### Using Makefile (Recommended)

```bash
cd development

make clean              # Interactive cleanup (prompts for confirmation)
make clean-all          # Complete cleanup of all resources
make clean-containers   # Remove only containers
make clean-images       # Remove only images
make clean-volumes      # Remove only volumes (⚠️ data will be lost)
make clean-system       # Run Docker system prune
make clean-force        # Force cleanup without confirmation
```

#### Using Script Directly

```bash
cd development

# Interactive mode (recommended for beginners)
./clean-dev.sh

# Complete cleanup
./clean-dev.sh --all

# Selective cleanup
./clean-dev.sh --containers
./clean-dev.sh --images
./clean-dev.sh --volumes
./clean-dev.sh --networks
./clean-dev.sh --build-cache
./clean-dev.sh --system

# Force mode (no confirmation prompts)
./clean-dev.sh --all --force
```

### Cleanup Options Explained

- **`--containers`**: Removes development containers only
- **`--images`**: Removes development Docker images
- **`--volumes`**: ⚠️ Removes volumes (persistent data will be lost)
- **`--networks`**: Removes development networks
- **`--build-cache`**: Removes Docker build cache
- **`--system`**: Runs `docker system prune` to remove unused resources
- **`--all`**: Performs complete cleanup of all above resources
- **`--force`**: Skips confirmation prompts

### When to Use Cleanup

- **Regular cleanup**: Use `make clean` weekly to remove unused resources
- **Troubleshooting**: Use `make clean-all` when facing build or connection issues
- **Disk space**: Use `make clean-system` to free up disk space
- **Fresh start**: Use `make clean-force` for automated scripts

### Cleanup Safety

- **Interactive mode**: Always prompts before dangerous operations
- **Selective cleanup**: Only removes development resources, not production
- **Volume warning**: Explicitly warns before removing volumes
- **Force mode**: Available for automation but requires `--force` flag

### Examples

```bash
# Regular maintenance
make clean              # Will ask what to clean

# Troubleshooting issues
make clean-all          # Complete cleanup

# Preparing for fresh build
make clean-containers clean-images

# Freeing disk space
make clean-system

# Automated cleanup (CI/CD)
make clean-force
```

## Available Commands Inside Container

### Environment Setup
```bash
./development/scripts/setup-env.sh    # Setup development environment
```

### Testing
```bash
./development/scripts/test-scripts.sh # Comprehensive script testing
./scripts/test.sh                     # Run bot tests (requires BOT_TOKEN)
```

### Bot Operations
```bash
./scripts/run.sh --help               # Show bot startup options
./scripts/run.sh --development        # Start bot in development mode
./scripts/check-service.sh            # Check bot status
```

### Service Management (default mode)
```bash
sudo ./scripts/install-service.sh     # Install as systemd service
sudo ./scripts/uninstall-service.sh   # Uninstall service
sudo systemctl status quit-smoking-bot.service
./scripts/run.sh --help               # All Docker operations supported
```

## Environment Variables

The development environment sets these variables:

- `SYSTEM_NAME=quit-smoking-bot`
- `SYSTEM_DISPLAY_NAME=Quit Smoking Bot`
- `DEVELOPMENT=1` (in `.env` file)

## Persistent Data

The following directories persist between container sessions:

- `/home/developer` - Your development files and settings
- `/workspace` - The project directory (mounted from host)

## Troubleshooting

### Docker Issues

```bash
# Clean restart
./development/start-dev.sh --clean --build

# Check Docker daemon
docker version

# Check compose file
cd development && docker-compose config
```

### Permission Issues

```bash
# Inside container
sudo chown -R $(id -u):$(id -g) /workspace
```

### systemd Issues

```bash
# Default mode includes systemd support
./development/start-dev.sh

# For issues with systemd, try basic mode
./development/start-dev.sh --basic

# Check systemd status inside container
systemctl is-system-running
```

### Connection Issues

```bash
# Check running containers
docker ps

# Connect to specific container
docker-compose exec dev-env bash
docker-compose exec dev-env-basic bash

# View logs
docker-compose logs -f
```

## Requirements

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+ or docker-compose 1.27+)
- **2GB+ free disk space** for images and volumes
- **Host Docker socket access** (for Docker-in-Docker)

## Advanced Usage

### Custom Image Building

```bash
cd development
docker-compose build --no-cache dev-env
```

### Volume Management

```bash
# List development volumes
docker volume ls | grep development

# Remove development volumes
docker-compose down -v
```

### Network Debugging

```bash
# Inside container
curl -s https://api.telegram.org/bot<TOKEN>/getMe
```

## Integration with Main Project

This development environment is designed to:

1. **Test all project scripts** before deployment
2. **Validate service installation** on Linux systems
3. **Provide consistent environment** across different host OS
4. **Enable safe experimentation** without affecting host system

## Tips and Best Practices

1. **Always test scripts** in development environment before production
2. **Default mode** includes full systemd and Docker daemon support
3. **Use basic mode** only for simple script testing without service features
4. **Set BOT_TOKEN in .env** for full functionality testing
5. **Use background mode** for long-running development sessions
6. **Clean up regularly** with `make clean` to save disk space

---

**Note**: This development environment simulates a Linux production environment and is particularly useful for testing on macOS and Windows systems where systemd is not available natively.
