# 🐳 Docker Configuration

This directory contains all Docker-related configurations for the universal Telegram bot deployment framework.

## 📁 Structure

```
docker/
├── README.md                    # This file
├── Dockerfile                   # Production image definition
├── docker-compose.yml           # Service orchestration
├── .dockerignore               # Build exclusions
├── docker-compose.dev.yml      # Development overrides
├── docker-compose.prod.yml     # Production overrides
├── entrypoint.py               # Production entrypoint
├── ENTRYPOINT.md               # 📖 Entrypoint features documentation
├── healthcheck.sh              # Health check script (optional)
└── init-bot.sh                 # Bot initialization script (optional)
```

## 🚀 Usage

### Development
```bash
# From project root
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up -d
```

### Production  
```bash
# From project root
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml up -d
```

### Single Environment (Simple)
```bash
# From project root
docker-compose -f docker/docker-compose.yml up -d
```

## 🎛️ Environment-Specific Configurations

### Development Features
- Volume mounts for live code reloading
- Debug logging enabled
- Development tools included
- Exposed debug ports

### Production Features
- Optimized image size
- Security hardening
- Health monitoring
- Log management
- Resource limits

## 🔧 Customization

This Docker setup is designed to be universal for any Telegram bot. To adapt for your bot:

1. **Environment Variables**: Set in `.env` file
2. **Bot Source**: Place bot code in `src/` directory  
3. **Dependencies**: Update `pyproject.toml`
4. **Configuration**: Modify `docker-compose.yml` as needed

## 📊 Features

- **Production-ready entrypoint** with initialization and monitoring
- **Multi-environment support** (dev/staging/prod)
- **Health monitoring** and automatic restarts
- **Log management** with rotation
- **Security best practices** (non-root user, minimal image)
- **Resource optimization** with limits and reservations

## 📖 Documentation

### Production Entrypoint Features
For detailed information about the production entrypoint script (`entrypoint.py`) and its comprehensive initialization features, see:
- [**ENTRYPOINT.md**](./ENTRYPOINT.md) - Production entrypoint features documentation

### Management Commands
For detailed information about available management commands, run:
```bash
python ../manager.py --help
```