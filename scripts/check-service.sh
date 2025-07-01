#!/bin/bash

# Source bootstrap (loads all modules)
source "$(dirname "$0")/bootstrap.sh"


show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Check the status of the Telegram bot service and provide comprehensive diagnostics."
    echo ""
    echo "Options:"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Show comprehensive status of the bot service"
}

# Parse arguments for this script
parse_arguments_check_service() {
    debug_print "Starting argument parsing for check-service script"
    while [[ "$#" -gt 0 ]]; do
        debug_print "Processing argument: $1"
        case $1 in
            --help)
                debug_print "Help requested"
                show_help
                exit 0
                ;;
            *)
                debug_print "Unknown argument: $1"
                print_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    debug_print "Argument parsing completed"
    return 0
}

# Parse script-specific arguments
debug_print "Starting check-service.sh script with arguments: $@"
parse_arguments_check_service "$@"

# Function to check Docker Compose service status
check_docker_compose_service() {
    debug_print "Starting Docker Compose service status check"
    print_section "Docker Compose Service Status"
    
    # Check if docker-compose.yml exists
    if [[ -f "docker-compose.yml" ]]; then
        print_message "✅ Configuration file exists: docker-compose.yml" "$GREEN"
        
        # Check if service is running
        local running_services=$(docker-compose ps --services --filter "status=running" 2>/dev/null || echo "")
        local all_services=$(docker-compose ps --services 2>/dev/null || echo "")
        
        if [[ -n "$running_services" ]]; then
            print_message "✅ Services running: $running_services" "$GREEN"
            
            # Show full compose status
            print_message "\nFull Docker Compose status:" "$BLUE"
            docker-compose ps 2>/dev/null || print_message "Failed to get compose status" "$RED"
        else
            print_message "❌ Service status: NOT RUNNING" "$RED"
            if [[ -n "$all_services" ]]; then
                print_message "   Available services: $all_services" "$RED"
            fi
        fi
    else
        print_message "❌ Configuration file not found: docker-compose.yml" "$RED"
        print_message "   Service is not configured for Docker Compose" "$RED"
    fi
    
    debug_print "Docker Compose service check completed"
}

# Function to check Docker containers
check_docker_containers() {
    debug_print "Starting Docker containers check"
    print_section "Docker Containers"

    debug_print "Searching for containers with name: $SYSTEM_NAME"
    local containers=$(docker ps -a --filter "name=$SYSTEM_NAME" --format "{{.Names}}")
    if [ -z "$containers" ]; then
        debug_print "No containers found"
        print_message "No $SYSTEM_NAME containers found" "$YELLOW"
    else
        debug_print "Found containers: $containers"
        print_message "Found containers:" "$GREEN"
        docker ps -a --filter "name=$SYSTEM_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
        
        # Show resource usage for running containers
        local running_containers=$(docker ps -q --filter "name=$SYSTEM_NAME")
        if [ -n "$running_containers" ]; then
            print_message "\nContainer resource usage:" "$BLUE"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $running_containers
        fi
    fi
    debug_print "Docker containers check completed"
}

# Function to check Docker images
check_docker_images() {
    debug_print "Starting Docker images check"
    print_section "Docker Images"

    debug_print "Searching for images with name: $SYSTEM_NAME"
    local images=$(docker images | grep $SYSTEM_NAME)
    if [ -z "$images" ]; then
        debug_print "No images found"
        print_message "No $SYSTEM_NAME images found" "$YELLOW"
    else
        debug_print "Found images"
        print_message "Found images:" "$GREEN"
        docker images | head -1  # Header
        docker images | grep $SYSTEM_NAME
    fi
    debug_print "Docker images check completed"
}

# Function to check Docker volumes
check_docker_volumes() {
    print_section "Docker Volumes"

    local volumes=$(docker volume ls | grep $SYSTEM_NAME)
    if [ -z "$volumes" ]; then
        print_message "No $SYSTEM_NAME volumes found" "$YELLOW"
    else
        print_message "Found volumes:" "$GREEN"
        docker volume ls | head -1  # Header
        docker volume ls | grep $SYSTEM_NAME
        
        # Show volume details
        print_message "\nVolume details:" "$BLUE"
        for volume in $(docker volume ls --format "{{.Name}}" | grep $SYSTEM_NAME); do
            print_message "Volume: $volume" "$YELLOW"
            docker volume inspect $volume --format "  Mountpoint: {{.Mountpoint}}"
            docker volume inspect $volume --format "  Created: {{.CreatedAt}}"
        done
    fi
}

# Function to check Docker networks
check_docker_networks() {
    print_section "Docker Networks"

    local networks=$(docker network ls | grep $SYSTEM_NAME)
    if [ -z "$networks" ]; then
        print_message "No custom $SYSTEM_NAME networks found" "$YELLOW"
    else
        print_message "Found networks:" "$GREEN"
        docker network ls | head -1  # Header
        docker network ls | grep $SYSTEM_NAME
    fi
    
    # Show container network connections
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        print_message "\nContainer network details:" "$BLUE"
        docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}Network: {{$net}}, IP: {{$config.IPAddress}}{{if $config.Aliases}}, Aliases: {{join $config.Aliases ", "}}{{end}}{{"\n"}}{{end}}' $container_id
    fi
}

# Function to check project files
check_project_files() {
    print_section "Project Files"

    # Check data directory
    if [ -d "./data" ]; then
        print_message "✅ Data directory exists" "$GREEN"
        print_message "   Size: $(du -sh ./data | cut -f1)" "$YELLOW"
        local file_count=$(find ./data -type f | wc -l)
        print_message "   Files: $file_count" "$YELLOW"
    else
        print_message "❌ Data directory not found" "$YELLOW"
    fi

    # Check logs directory
    if [ -d "./logs" ]; then
        print_message "✅ Logs directory exists" "$GREEN"
        print_message "   Size: $(du -sh ./logs | cut -f1)" "$YELLOW"
        local log_files=$(find ./logs -name "*.log" | wc -l)
        print_message "   Log files: $log_files" "$YELLOW"
    else
        print_message "❌ Logs directory not found" "$YELLOW"
    fi

    # Check Docker compose files
    if [ -f "docker-compose.yml" ]; then
        print_message "✅ docker-compose.yml exists" "$GREEN"
    else
        print_message "❌ docker-compose.yml not found" "$RED"
    fi

    if [ -f "docker-compose.override.yml" ]; then
        print_message "✅ docker-compose.override.yml exists" "$GREEN"
    else
        print_message "ℹ️  docker-compose.override.yml not found (optional)" "$BLUE"
    fi

    # Check environment file
    if [ -f ".env" ]; then
        print_message "✅ .env file exists" "$GREEN"
    else
        print_message "❌ .env file not found" "$RED"
    fi

    # Check Dockerfile
    if [ -f "Dockerfile" ]; then
        print_message "✅ Dockerfile exists" "$GREEN"
    else
        print_message "❌ Dockerfile not found" "$RED"
    fi
}

# Function to check logs
check_logs() {
    print_section "Recent Logs"

    # Check Docker container logs
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        print_message "Docker container logs (last 20 lines):" "$YELLOW"
        docker logs --tail 20 $container_id 2>&1
        
        print_message "\nContainer log file info:" "$BLUE"
        docker exec $container_id sh -c 'if [ -f /app/logs/bot.log ]; then echo "Log file size: $(du -sh /app/logs/bot.log | cut -f1)"; echo "Last modified: $(stat -c %y /app/logs/bot.log)"; else echo "No log file found in container"; fi' 2>/dev/null || echo "Cannot access container filesystem"
    else
        print_message "No running container found for log inspection" "$YELLOW"
    fi

    # Check local log files
    if [ -d "./logs" ] && [ "$(ls -A ./logs 2>/dev/null)" ]; then
        print_message "\nLocal log files:" "$YELLOW"
        for logfile in ./logs/*.log; do
            if [ -f "$logfile" ]; then
                echo "=== $(basename "$logfile") (last 5 lines) ==="
                tail -5 "$logfile"
                echo ""
            fi
        done
    fi
}

# Function to check system resources
check_resources() {
    print_section "System Resources"

    # Check CPU usage
    print_message "System CPU Usage:" "$GREEN"
    if command -v top >/dev/null 2>&1; then
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Usage: " 100 - $1"%"}'
    else
        print_message "top command not available" "$YELLOW"
    fi

    # Check memory usage
    print_message "\nSystem Memory Usage:" "$GREEN"
    if command -v free >/dev/null 2>&1; then
        free -h | grep -E "(Mem:|Swap:)"
    else
        print_message "free command not available" "$YELLOW"
    fi

    # Check disk space
    print_message "\nDisk Space:" "$GREEN"
    df -h | grep -E "(Filesystem|/$|/var)" | head -3

    # Check Docker system info
    print_message "\nDocker System Info:" "$GREEN"
    if command -v docker >/dev/null 2>&1; then
        echo "Containers: $(docker ps -q | wc -l) running, $(docker ps -aq | wc -l) total"
        echo "Images: $(docker images -q | wc -l) total"
        echo "Volumes: $(docker volume ls -q | wc -l) total"
        echo "Networks: $(docker network ls -q | wc -l) total"
        
        # Docker space usage
        print_message "\nDocker Space Usage:" "$BLUE"
        docker system df 2>/dev/null || echo "Cannot get Docker space usage"
    fi
}

# Function to check bot health (using unified health module)
check_bot_health_status() {
    print_section "Bot Health"
    
    # Use the unified health diagnostics
    ./scripts/health.sh --mode diagnostics
    
    # Add additional container-specific diagnostics
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        print_message "\nContainer Details:" "$BLUE"
        local container_start_time=$(docker inspect --format='{{.State.StartedAt}}' $container_id)
        local container_status=$(docker inspect --format='{{.State.Status}}' $container_id)
        local restart_count=$(docker inspect --format='{{.RestartCount}}' $container_id)
        
        print_message "Container status: $container_status" "$YELLOW"
        print_message "Container started: $container_start_time" "$YELLOW"
        print_message "Restart count: $restart_count" "$YELLOW"
        
        # Check for operational indicators in logs
        print_message "\nBot operational indicators:" "$BLUE"
        if docker logs $container_id --tail 50 2>&1 | grep -q "Application started"; then
            print_message "✅ Bot reports 'Application started'" "$GREEN"
        else
            print_message "❌ No 'Application started' message found in recent logs" "$YELLOW"
        fi

        if docker logs $container_id --tail 50 2>&1 | grep -q "\"HTTP/1.1 200 OK\""; then
            print_message "✅ Bot making successful API calls" "$GREEN"
        else
            print_message "❌ No successful API calls detected in recent logs" "$YELLOW"
        fi
    fi
}

# Function to report overall status
report_overall_status() {
    print_section "Overall Status Summary"

    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    local compose_running=false
    local container_running=false
    local bot_running=false
    local health_check_ok=false

    # Check Docker Compose status
    if docker-compose ps --services --filter "status=running" 2>/dev/null | grep -q "."; then
        compose_running=true
        print_message "✅ Docker Compose: Services running" "$GREEN"
    else
        print_message "❌ Docker Compose: No services running" "$RED"
    fi

    # Check container status
    if [ -n "$container_id" ]; then
        container_running=true
        print_message "✅ Docker container: Running" "$GREEN"

        if docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
            bot_running=true
            print_message "✅ Bot process: Running" "$GREEN"
        else
            print_message "❌ Bot process: Not running" "$RED"
        fi

        local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
        if [ "$health_status" = "healthy" ]; then
            health_check_ok=true
            print_message "✅ Health check: Healthy" "$GREEN"
        elif [ -n "$health_status" ] && [ "$health_status" != "<no value>" ]; then
            print_message "⚠️  Health check: $health_status" "$YELLOW"
        else
            print_message "ℹ️  Health check: Not configured" "$BLUE"
        fi
    else
        print_message "❌ Docker container: Not running" "$RED"
    fi

    # Overall summary
    print_section "Summary"
    if $compose_running && $container_running && $bot_running; then
        if $health_check_ok; then
            print_message "🎉 Bot is fully operational and healthy!" "$GREEN"
        else
            print_message "✅ Bot is operational (health check pending or not configured)" "$GREEN"
        fi
    elif $compose_running && $container_running; then
        print_message "⚠️  Container is running but bot process may have issues" "$YELLOW"
    elif $compose_running; then
        print_message "⚠️  Services are configured but container is not running properly" "$YELLOW"
    else
        print_message "❌ Bot is not operational - services are down" "$RED"
    fi

    # Available commands
    print_section "Available Commands"
    print_message "Status commands:" "$YELLOW"
    print_message "  docker-compose ps                 # Show service status" "$BLUE"
    print_message "  docker ps -a --filter name=$SYSTEM_NAME  # Show containers" "$BLUE"
    if [ -n "$container_id" ]; then
        print_message "  docker logs $SYSTEM_NAME           # Show container logs" "$BLUE"
        print_message "  docker exec -it $SYSTEM_NAME sh    # Access container shell" "$BLUE"
    fi
    
    print_message "\nManagement commands:" "$YELLOW"
    print_message "  ./scripts/run.sh                  # Start the bot" "$BLUE"
    print_message "  ./scripts/stop.sh                 # Stop the bot" "$BLUE"
    print_message "  docker-compose restart            # Restart services" "$BLUE"
    print_message "  docker-compose logs -f            # Follow logs" "$BLUE"
}

# Run all check functions
check_prerequisites() {
    # Check system name
    if ! check_system_name; then
        exit 1
    fi

    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed. Cannot check bot status."
        exit 1
    fi

    # Check if docker-compose is installed
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "docker-compose is not installed. Cannot check bot status."
        exit 1
    fi

    return 0
}

# Main function
main() {
    # Ensure SYSTEM_NAME is set
    if [ -z "$SYSTEM_NAME" ]; then
        print_error "SYSTEM_NAME is not set. Cannot check bot status."
        exit 1
    fi

    print_header "Bot Service Status Check"
    print_message "Checking status of $SYSTEM_NAME bot service..." "$YELLOW"

    # Run prerequisite checks
    check_prerequisites

    # Run all check functions
    check_docker_compose_service
    check_docker_containers
    check_docker_images
    check_docker_volumes
    check_docker_networks
    check_project_files
    check_logs
    check_resources
    check_bot_health_status
    report_overall_status
    
    print_success "Status check completed"
}

# Run main function
main
