# 🚀 Production Entrypoint Features

The `docker/entrypoint.py` provides enterprise-grade container initialization for robust bot deployment.

## 🛡️ What Entrypoint Does

### **1. Environment Initialization**

- **Auto-creates directories**: `/app/data`, `/app/logs` with correct permissions
- **Creates missing files**: `bot_admins.json`, `bot_users.json`, `quotes.json`
- **Sets up Python paths**: Ensures proper module imports
- **Permission management**: Secure file permissions (644/755)
- **Docker image cleanup**: Removes dangling images specific to this project

### **2. Process Management**

- **Clean startup**: Terminates any existing bot processes before start
- **Graceful shutdown**: SIGTERM → SIGKILL escalation for clean stops
- **Process isolation**: Prevents conflicts with multiple instances

### **3. Log Management**

- **Log rotation**: Archives old logs with timestamps (`bot_YYYYMMDD_HHMMSS.log`)
- **Archive cleanup**: Keeps only 5 most recent log archives
- **Session logging**: Clear session markers in logs
- **Health logging**: Separate health monitoring log (`health.log`)

### **4. Health Monitoring**

- **Background daemon**: Continuous health checks every 30 seconds
- **Health status logging**: Persistent health history
- **Integration**: Uses `scripts/modules/health.py` for checks
- **Operational monitoring**: Ensures bot is responding to Telegram API

### **5. Production Initialization**

```bash
# What entrypoint does on startup:
1. Terminate existing processes
2. Setup health monitoring system
3. Setup data directory and files
4. Rotate and setup logs
5. Start background health monitor
6. Launch bot with proper environment
```

## 📊 Log Structure Created

```
/app/logs/
├── bot.log                    # Current session log
├── health.log                 # Health monitoring log
└── archive/                   # Rotated log archives
    ├── bot_20250806_105439.log
    ├── bot_20250805_142301.log
    └── ...                    # (keeps 5 most recent)
```

## 🔍 Health Monitoring

The entrypoint starts a background daemon that:

- Runs health checks every 30 seconds
- Logs health status to `/app/logs/health.log`
- Uses `quick_health_check()` from modules
- Provides continuous monitoring without external dependencies

## 🎯 Production Benefits

### **For VPS Deployment:**

- **Zero-configuration startup**: Just `docker run` and it works
- **Fault tolerance**: Automatic cleanup and recovery
- **Monitoring**: Built-in health tracking without external tools
- **Maintenance**: Automatic log management prevents disk filling

### **For Bot Creation:**

- **Clean environment**: Consistent startup every time
- **Debug friendly**: Clear session logs and health tracking
- **Production-ready**: Optimized entrypoint for production deployment

### **For Quit Smoking Bot:**

- **Bot-agnostic**: Works with any Telegram bot using this structure
- **Configurable**: Respects environment variables
- **Extensible**: Easy to add more initialization steps

## 🔧 Integration with manager.py

The entrypoint integrates seamlessly with the management system:

```bash
# manager.py uses the entrypoint automatically
python3 manager.py start          # Uses entrypoint via Docker
python3 manager.py logs           # Shows entrypoint-managed logs
python3 manager.py status         # Shows entrypoint health info

# View entrypoint-specific features:
docker exec quit-smoking-bot cat /app/logs/health.log  # Health monitoring
docker exec quit-smoking-bot ls -la /app/logs/         # Log structure
```

## ⚡ Performance Impact

- **Startup time**: +5-10 seconds for full initialization
- **Memory**: +~5MB for health daemon
- **CPU**: Negligible (health checks every 30s)
- **Storage**: Managed via log rotation

**Trade-off**: Slightly slower startup for significantly more robust operation.

## 🎯 Perfect For

✅ **Production VPS deployments**
✅ **Long-running bot services**
✅ **Quit Smoking Bot**
✅ **Unattended operation**
✅ **Enterprise environments**

This entrypoint transforms a simple bot into a production-ready service with monitoring, logging, and fault tolerance built-in.
