# File Permissions Management

This document describes the automated file permissions system for the quit-smoking-bot project.

## Overview

The project implements a secure, automated permission management system that:
- Automatically configures permissions after git clone
- Uses secure defaults (755 for directories, 644 for files)
- Eliminates unsafe permission practices
- Provides centralized permission management via **Makefile**

## Automatic Setup

### After Git Clone
Permissions are automatically configured via git hooks:
```bash
git clone https://github.com/sensiloles/quit-smoking-bot.git
# Project setup runs automatically via post-checkout hook
```

### Manual Setup
**Recommended approach using Makefile:**
```bash
make setup              # Full project setup (recommended)
make permissions        # Just permission setup
```

**Legacy approach:**
```bash
./scripts/bootstrap.sh  # Full bootstrap
./scripts/setup-permissions.sh  # Just permissions
```

## Permission Scheme

| Path | Permission | Description |
|------|------------|-------------|
| `data/` | 755 | Directory: owner rwx, group/other rx |
| `logs/` | 755 | Directory: owner rwx, group/other rx |
| `data/*.json` | 644 | Files: owner rw, group/other r |
| `logs/*.log` | 644 | Files: owner rw, group/other r |
| `scripts/*.sh` | 755 | Scripts: executable by owner, readable by all |

## Security Features

- **No 777 permissions**: Eliminates world-writable security risks
- **Minimal access**: Files readable by group/others, writable only by owner
- **Secure defaults**: Conservative permissions that work with Docker
- **Idempotent operations**: Safe to run multiple times

## Management Commands

### Makefile Commands (Recommended)
```bash
make permissions        # Setup secure file permissions
make setup              # Initial project setup (includes permissions)
make env-check          # Check environment configuration
make docker-check       # Verify Docker installation
```

### Legacy Scripts (Still Supported)
```bash
./scripts/setup-permissions.sh  # Permission setup script
./scripts/bootstrap.sh          # Full project bootstrap
```

## Architecture

```
Management Layer:
├── Makefile                     # Primary management interface
├── .git/hooks/post-checkout     # Automatic setup after clone

Legacy Scripts (for compatibility):
├── scripts/
    ├── setup-permissions.sh     # Permission setup script
    ├── bootstrap.sh            # Full project initialization
    └── modules/
        └── filesystem.sh       # Legacy filesystem operations
```

## Integration Points

The permission system is integrated into:
- **Git hooks**: `.git/hooks/post-checkout` calls `make setup`
- **Makefile**: Primary interface for all operations
- **Build scripts**: `scripts/start.py` calls permission setup
- **Docker builds**: Dockerfile sets container permissions

## Troubleshooting

### Permission Denied Errors
```bash
# Reset permissions using Makefile
make permissions

# Or legacy script
./scripts/setup-permissions.sh
```

### Git Hook Not Working
```bash
# Make git hook executable
chmod +x .git/hooks/post-checkout

# Or run setup manually
make setup
```

### Docker Permission Issues
The system is designed to work with Docker's user mapping. If you encounter issues:
```bash
# Check current permissions
ls -la data/ logs/

# Reset with Makefile
make permissions

# Check Docker configuration
make docker-check
```

## Migration from Legacy System

The new **Makefile-based system** provides:
- ✅ **Standardized interface**: Common `make` commands
- ✅ **Better organization**: Clear command categories
- ✅ **Enhanced functionality**: Environment checks, Docker validation
- ✅ **Backward compatibility**: Legacy scripts still work

### Migration Path
1. **New projects**: Use `make setup` instead of bash scripts
2. **Existing projects**: Both approaches work, Makefile recommended
3. **CI/CD**: Can switch to `make` commands gradually

**No manual migration required** - the system automatically applies secure permissions on first use. 