# Scripts Directory - Modular Structure

## Structure

```
scripts/
├── bootstrap.sh             # Main entry point - loads all modules
├── modules/                 # Modular utilities directory
│   ├── output.sh            # Output formatting and colored messages
│   ├── environment.sh       # Environment variable validation
│   ├── docker.sh            # Docker management and installation checks
│   ├── errors.sh            # Error handling and debugging utilities
│   ├── service.sh           # Service and container management
│   ├── health.sh            # Health checks and status monitoring
│   ├── conflicts.sh          # Bot conflict detection and resolution
│   ├── args.sh              # Command line argument parsing
│   ├── filesystem.sh         # File system and directory management
│   ├── system.sh            # System service management (systemd)
│   └── testing.sh           # Test execution utilities
├── run.sh                   # Start the bot
├── stop.sh                  # Stop the bot
├── check-service.sh         # Check service status
├── test.sh                  # Run tests
├── install-service.sh       # Install as system service
├── uninstall-service.sh     # Uninstall system service
├── healthcheck.sh           # Health check script
└── entrypoint.sh            # Docker entrypoint
```

## Modules Description

### Core Modules

1. **modules/output.sh** - Color constants and message formatting functions
   - `print_message()`, `print_error()`, `print_warning()`, `print_section()`
   - `debug_print()` for debug output

2. **modules/environment.sh** - Environment validation and configuration
   - `check_bot_token()`, `check_system_name()`, `check_system_display_name()`
   - `load_env_file()`, `update_env_token()`, `check_prerequisites()`

3. **modules/docker.sh** - Docker management and operations
   - `check_docker_installation()`, `start_docker_macos()`, `start_docker_linux()`
   - `check_docker()`, `check_docker_buildx()`, `cleanup_docker()`

### Service Management

4. **modules/service.sh** - Container and service lifecycle management
   - `build_and_start_service()`, `stop_running_instances()`
   - `is_container_running()`, `get_service_status()`

5. **modules/health.sh** - Health monitoring and status checks
   - `is_bot_healthy()`, `is_bot_operational()`, `check_bot_status()`

6. **modules/conflicts.sh** - Bot conflict detection and resolution
   - `detect_remote_bot_conflict()`, `stop_local_bot_instance()`
   - `check_bot_conflicts()` - main conflict resolution function

### Utilities

7. **modules/args.sh** - Command line argument parsing
   - `parse_args()` - unified argument parsing for all scripts

8. **modules/filesystem.sh** - File system operations
   - `setup_data_directories()` - data and logs directory setup

9. **modules/system.sh** - System-level operations
   - `check_root()`, `stop_service()` - systemd service management

10. **modules/testing.sh** - Test execution
    - `run_tests_in_docker()` - Docker-based test execution

11. **modules/errors.sh** - Error handling and debugging
    - `log_docker_compose_error()`, `execute_docker_compose()`

## Usage

All scripts automatically load the modular structure through `bootstrap.sh`. No changes are required for existing usage patterns.

### Examples

```bash
# All scripts work as before
./scripts/run.sh --token YOUR_TOKEN
./scripts/stop.sh --cleanup
./scripts/check-service.sh
./scripts/test.sh --token YOUR_TOKEN
```

## Dependencies

Module loading order is important due to inter-dependencies:

1. Output (no dependencies)
2. Environment (depends on output)
3. Docker (depends on output, environment) 
4. Errors (depends on output, docker)
5. Service (depends on output, environment, docker, errors)
6. Health (depends on output, environment, docker)
7. Conflicts (depends on output, environment, docker)
8. Args (depends on output, environment)
9. Filesystem (depends on output)
10. System (depends on output, environment)
11. Testing (depends on output, errors)

The main `bootstrap.sh` file handles this dependency order automatically. 