# 🐳 Docker Configuration

This directory contains all Docker-related configurations for the universal Telegram bot deployment framework.

## 📁 Structure

```
docker/
├── README.md                    # This file
├── Dockerfile                   # Production image definition
├── docker-compose.yml           # Service orchestration (production-ready)
├── .dockerignore               # Build exclusions
├── entrypoint.py               # Production entrypoint
├── ENTRYPOINT.md               # 📖 Entrypoint features documentation
└── Makefile                    # Docker-specific commands
```

## 🚀 Usage

### Production Deployment
```bash
# From project root
docker-compose -f docker/docker-compose.yml up -d
```

### Using Main Makefile Commands
```bash
# Build and start
make install

# Start services
make start

# Stop services
make stop
```

### Using Docker Makefile Commands
```bash
# From docker/ directory
make docker-build       # Build Docker image
make docker-up          # Start services
make docker-down        # Stop services
make docker-logs        # Show logs
make docker-status      # Show container status
make docker-clean       # Clean up containers and images
```

## 🎛️ Production Features

- **Optimized image size** for efficiency
- **Security hardening** with non-root user and minimal privileges
- **Health monitoring** with automatic restarts
- **Log management** with rotation and compression
- **Resource limits** for stability
- **Environment variables** for configuration
- **Data persistence** with mounted volumes

## 🔧 Customization

This Docker setup is designed to be universal for any Telegram bot. To adapt for your bot:

1. **Environment Variables**: Set in `.env` file
2. **Bot Source**: Place bot code in `src/` directory  
3. **Dependencies**: Update `pyproject.toml`
4. **Configuration**: Modify `docker-compose.yml` as needed

## 📊 Features

- **Production-ready entrypoint** with comprehensive initialization and monitoring
- **Health monitoring** and automatic restarts
- **Log management** with rotation and compression
- **Security best practices** (non-root user, minimal privileges)
- **Resource optimization** with limits and reservations
- **Simple deployment** with single compose file

## 📖 Documentation

### Production Entrypoint Features
For detailed information about the production entrypoint script (`entrypoint.py`) and its comprehensive initialization features, see:
- [**ENTRYPOINT.md**](./ENTRYPOINT.md) - Production entrypoint features documentation

### Management Commands
For detailed information about available management commands, run:
```bash
python ../manager.py --help
```