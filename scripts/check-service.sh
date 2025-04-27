#!/bin/bash

# Source common functions and variables
source "$(dirname "$0")/common.sh"


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
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    return 0
}

# Parse script-specific arguments
parse_arguments_check_service "$@"

# Function to check systemd service status
check_systemd_service() {
    print_section "Systemd Service Status"
    
    if systemctl is-active $SYSTEM_NAME.service >/dev/null 2>&1; then
        print_message "Service is active" "$GREEN"
    else
        print_message "Service is not active" "$RED"
    fi
    
    if systemctl is-enabled $SYSTEM_NAME.service &>/dev/null; then
        print_message "Service is enabled (starts on boot)" "$GREEN"
    else
        print_message "Service is not enabled" "$YELLOW"
    fi
    
    print_message "\nDetailed service status:" "$YELLOW"
    systemctl status $SYSTEM_NAME.service --no-pager
}

# Function to check Docker containers
check_docker_containers() {
    print_section "Docker Containers"
    
    local containers=$(docker ps -a --filter "name=$SYSTEM_NAME" --format "{{.Names}}")
    if [ -z "$containers" ]; then
        print_message "No $SYSTEM_NAME containers found" "$YELLOW"
    else
        print_message "Found containers:" "$GREEN"
        docker ps -a --filter "name=$SYSTEM_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    fi
}

# Function to check Docker images
check_docker_images() {
    print_section "Docker Images"
    
    local images=$(docker images | grep $SYSTEM_NAME)
    if [ -z "$images" ]; then
        print_message "No $SYSTEM_NAME images found" "$YELLOW"
    else
        print_message "Found images:" "$GREEN"
        docker images | grep $SYSTEM_NAME
    fi
}

# Function to check Docker volumes
check_docker_volumes() {
    print_section "Docker Volumes"
    
    local volumes=$(docker volume ls | grep $SYSTEM_NAME)
    if [ -z "$volumes" ]; then
        print_message "No $SYSTEM_NAME volumes found" "$YELLOW"
    else
        print_message "Found volumes:" "$GREEN"
        docker volume ls | grep $SYSTEM_NAME
    fi
}

# Function to check project files
check_project_files() {
    print_section "Project Files"
    
    # Check data directory
    if [ -d "./data" ]; then
        print_message "Data directory exists" "$GREEN"
        print_message "Data directory size: $(du -sh ./data | cut -f1)" "$YELLOW"
    else
        print_message "Data directory not found" "$YELLOW"
    fi
    
    # Check logs directory
    if [ -d "./logs" ]; then
        print_message "Logs directory exists" "$GREEN"
        print_message "Logs directory size: $(du -sh ./logs | cut -f1)" "$YELLOW"
    else
        print_message "Logs directory not found" "$YELLOW"
    fi
    
    # Check service file
    if [ -f "/etc/systemd/system/$SYSTEM_NAME.service" ]; then
        print_message "Service file exists" "$GREEN"
    else
        print_message "Service file not found" "$YELLOW"
    fi
    
    # Check Docker compose files
    if [ -f "docker-compose.yml" ]; then
        print_message "docker-compose.yml exists" "$GREEN"
    else
        print_message "docker-compose.yml not found" "$YELLOW"
    fi
    
    if [ -f "docker-compose.override.yml" ]; then
        print_message "docker-compose.override.yml exists" "$GREEN"
    else
        print_message "docker-compose.override.yml not found" "$YELLOW"
    fi
}

# Function to check network connections
check_network() {
    print_section "Network Connections"
    
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        print_message "Container network settings:" "$GREEN"
        # Get network mode
        local network_mode=$(docker inspect --format '{{.HostConfig.NetworkMode}}' $container_id)
        print_message "Network Mode: $network_mode" "$YELLOW"
        
        # Get exposed ports
        local ports=$(docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' $container_id)
        if [ -n "$ports" ]; then
            print_message "Exposed Ports: $ports" "$YELLOW"
        else
            print_message "No ports exposed" "$YELLOW"
        fi
        
        # Get IP addresses for all networks
        print_message "\nContainer IP addresses:" "$GREEN"
        docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}{{printf "Network: %s\nIP: %s\n" $net $config.IPAddress}}{{end}}' $container_id
        
        # Get network aliases
        local aliases=$(docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}{{printf "Network: %s\nAliases: %s\n" $net $config.Aliases}}{{end}}' $container_id)
        if [ -n "$aliases" ]; then
            print_message "\nNetwork Aliases:" "$GREEN"
            echo "$aliases"
        fi
    else
        print_message "No running container found to check network" "$YELLOW"
    fi
}

# Function to check logs
check_logs() {
    print_section "Recent Logs"
    
    # Check systemd logs
    print_message "Systemd service logs (last 10 lines):" "$YELLOW"
    journalctl -u $SYSTEM_NAME.service -n 10 --no-pager
    
    # Check Docker container logs
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        print_message "\nDocker container logs (last 10 lines):" "$YELLOW"
        docker logs --tail 10 $container_id
    fi
}

# Function to check system resources
check_resources() {
    print_section "System Resources"
    
    # Check CPU usage
    print_message "CPU Usage:" "$GREEN"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
    
    # Check memory usage
    print_message "\nMemory Usage:" "$GREEN"
    free -h | grep "Mem:" | awk '{print "Total: " $2 ", Used: " $3 ", Free: " $4}'
    
    # Check disk usage
    print_message "\nDisk Usage:" "$GREEN"
    df -h / | tail -1 | awk '{print "Total: " $2 ", Used: " $3 ", Free: " $4}'
}

# Function to check container health
check_container_health() {
    print_section "Container Health Status"
    
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        # Get container health status
        local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
        
        print_message "Container Health Status: $health_status" "$BLUE"
        
        # Use our is_bot_healthy function to check health
        if is_bot_healthy; then
            print_message "Docker Healthcheck: PASSED" "$GREEN"
        else
            print_message "Docker Healthcheck: FAILED" "$RED"
            print_message "\nHealthcheck details:" "$YELLOW"
            # Show the last health check log
            docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $container_id | tail -2
        fi
        
        # Check for error logs
        print_message "\nRecent error logs:" "$YELLOW"
        local error_logs=$(docker logs --tail 50 $container_id 2>&1 | grep -i "error\|exception\|fail\|warning\|critical" | tail -10)
        if [ -n "$error_logs" ]; then
            echo "$error_logs"
        else
            print_message "No recent errors found in logs" "$GREEN"
        fi
        
        # Check container resource limits and usage
        print_message "\nContainer Resource Usage:" "$GREEN"
        local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" $container_id)
        local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" $container_id)
        local mem_limit=$(docker inspect --format '{{.HostConfig.Memory}}' $container_id)
        
        print_message "CPU Usage: $cpu_usage" "$YELLOW"
        print_message "Memory Usage: $mem_usage / $mem_limit" "$YELLOW"
        
        # Check for resource constraints
        if [ "$cpu_usage" = "100%" ]; then
            print_message "WARNING: Container is using 100% CPU" "$RED"
        fi
        
        # Check container uptime and restart count
        local uptime=$(docker inspect --format '{{.State.StartedAt}}' $container_id)
        local restart_count=$(docker inspect --format '{{.RestartCount}}' $container_id)
        print_message "\nContainer Uptime: $uptime" "$YELLOW"
        print_message "Restart Count: $restart_count" "$YELLOW"
        
        if [ "$restart_count" -gt 0 ]; then
            print_message "Container has been restarted $restart_count times" "$RED"
            print_message "Last Exit Code: $(docker inspect --format '{{.State.ExitCode}}' $container_id)" "$YELLOW"
        fi
        
        # Check container ports
        print_message "\nContainer Ports:" "$GREEN"
        local ports=$(docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' $container_id)
        if [ -n "$ports" ]; then
            echo "$ports"
        else
            print_message "No ports exposed" "$YELLOW"
        fi
        
        # Check container volumes
        print_message "\nContainer Volumes:" "$GREEN"
        local volumes=$(docker inspect --format '{{range .Mounts}}{{printf "Source: %s\nDestination: %s\nMode: %s\n" .Source .Destination .Mode}}{{end}}' $container_id)
        if [ -n "$volumes" ]; then
            echo "$volumes"
        else
            print_message "No volumes mounted" "$YELLOW"
        fi
        
        # Check container environment variables
        print_message "\nContainer Environment:" "$GREEN"
        local env_vars=$(docker inspect --format '{{range .Config.Env}}{{printf "%s\n" .}}{{end}}' $container_id | grep -v "PASSWORD\|TOKEN\|KEY\|SECRET")
        if [ -n "$env_vars" ]; then
            echo "$env_vars"
        else
            print_message "No environment variables found" "$YELLOW"
        fi
        
        # Check for missing required environment variables
        print_message "\nRequired Environment Variables Check:" "$GREEN"
        local required_vars=("BOT_TOKEN" "SYSTEM_NAME" "SYSTEM_DISPLAY_NAME")
        local missing_vars=()
        for var in "${required_vars[@]}"; do
            if ! docker inspect --format '{{range .Config.Env}}{{printf "%s\n" .}}{{end}}' $container_id | grep -q "^$var="; then
                missing_vars+=("$var")
            fi
        done
        
        if [ ${#missing_vars[@]} -gt 0 ]; then
            print_message "Missing required environment variables:" "$RED"
            for var in "${missing_vars[@]}"; do
                print_message "- $var" "$RED"
            done
        else
            print_message "All required environment variables are set" "$GREEN"
        fi
    else
        print_message "No running container found to check health" "$RED"
        
        # Check if container exists but is stopped
        local stopped_container=$(docker ps -a -q --filter "name=$SYSTEM_NAME" --filter "status=exited")
        if [ -n "$stopped_container" ]; then
            print_message "\nContainer exists but is stopped" "$YELLOW"
            print_message "Last Exit Code: $(docker inspect --format '{{.State.ExitCode}}' $stopped_container)" "$YELLOW"
            print_message "Last Error: $(docker inspect --format '{{.State.Error}}' $stopped_container)" "$YELLOW"
            
            # Show last logs of stopped container
            print_message "\nLast logs before container stopped:" "$YELLOW"
            docker logs --tail 20 $stopped_container
        fi
    fi
}

# Function to check environment variables
check_environment() {
    print_section "Environment Configuration"
    
    # Check if .env file exists
    if [ -f ".env" ]; then
        print_message "Environment file (.env) exists" "$GREEN"
        
        # Check for required environment variables
        local required_vars=("BOT_TOKEN" "SYSTEM_NAME" "SYSTEM_DISPLAY_NAME")
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" .env; then
                print_message "$var is set" "$GREEN"
            else
                print_message "$var is missing" "$RED"
            fi
        done
    else
        print_message "Environment file (.env) not found" "$RED"
    fi
}

# Function to check Docker configuration
check_docker_config() {
    print_section "Docker Configuration"
    
    # Check Docker version
    print_message "Docker Version:" "$GREEN"
    docker --version
    
    # Check Docker daemon status
    if systemctl is-active docker &>/dev/null; then
        print_message "\nDocker daemon is running" "$GREEN"
    else
        print_message "\nDocker daemon is not running" "$RED"
    fi
    
    # Check Docker compose version
    print_message "\nDocker Compose Version:" "$GREEN"
    docker-compose --version
}

# Function to check if bot is fully operational
check_bot_operation() {
    print_section "Bot Operational Status"
    
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -z "$container_id" ]; then
        print_message "No running container found. Bot is not operational." "$RED"
        return 1
    fi
    
    # Check if bot is healthy
    print_message "Checking Docker health status:" "$BLUE"
    if is_bot_healthy; then
        print_message "Health status: HEALTHY" "$GREEN"
    else
        print_message "Health status: NOT HEALTHY" "$RED"
    fi
    
    # Check if bot is operational
    print_message "\nChecking operational status:" "$BLUE"
    if is_bot_operational; then
        print_message "Operational status: OPERATIONAL" "$GREEN"
    else
        print_message "Operational status: NOT OPERATIONAL" "$RED"
    fi
    
    # Get container logs
    local logs=$(docker logs $container_id 2>&1)
    
    print_message "\nDetailed Bot Status Checks:" "$BLUE"
    # Check for successful connections to Telegram API
    if echo "$logs" | grep -q "HTTP Request: POST https://api.telegram.org/bot.*getUpdates \"HTTP/1.1 200 OK\""; then
        print_message "✓ Bot successfully connected to Telegram API" "$GREEN"
    else
        print_message "✗ No successful Telegram API connections detected" "$RED"
    fi
    
    # Check for Application started message
    if echo "$logs" | grep -q "telegram.ext.Application - INFO - Application started"; then
        print_message "✓ Telegram application successfully started" "$GREEN"
    else
        print_message "✗ No application start message detected" "$RED"
    fi
    
    # Check for Scheduler started
    if echo "$logs" | grep -q "apscheduler.scheduler - INFO - Scheduler started"; then
        print_message "✓ Scheduler successfully started" "$GREEN"
    else
        print_message "✗ No scheduler start message detected" "$RED"
    fi
    
    # Count getUpdates calls with 200 OK
    local getUpdates_count=$(echo "$logs" | grep -c "getUpdates \"HTTP/1.1 200 OK\"")
    if [ $getUpdates_count -ge 2 ]; then
        print_message "✓ Bot has made $getUpdates_count successful API calls" "$GREEN"
    else
        print_message "✗ Less than 2 successful API calls detected ($getUpdates_count)" "$RED"
    fi
    
    # Check for critical errors
    if echo "$logs" | grep -q "telegram.error.Conflict: Conflict: terminated by other getUpdates request"; then
        print_message "‼️ CRITICAL: Detected conflict with another bot instance" "$RED"
        print_message "This usually means another bot with the same token is running elsewhere" "$YELLOW"
        print_message "Recommendations:" "$YELLOW"
        print_message "1. Check for any other instances of this bot" "$YELLOW"
        print_message "2. Wait a few minutes for the Telegram API to release the connection" "$YELLOW"
        print_message "3. Restart this bot" "$YELLOW"
    fi
    
    local error_count=$(echo "$logs" | grep -c "ERROR")
    if [ $error_count -gt 0 ]; then
        print_message "‼️ Found $error_count ERROR entries in the logs" "$RED"
        print_message "\nRecent ERROR logs:" "$YELLOW"
        echo "$logs" | grep "ERROR" | tail -5
    else
        print_message "✓ No ERROR entries found in logs" "$GREEN"
    fi
    
    # Final verdict - based on our is_bot_operational function
    if is_bot_operational; then
        print_message "\nBOT STATUS: OPERATIONAL" "$GREEN"
        return 0
    else
        print_message "\nBOT STATUS: NOT FULLY OPERATIONAL" "$RED"
        return 1
    fi
}

# Main script
print_message "Starting comprehensive status check of $SYSTEM_NAME service..." "$BLUE"

# Run all checks
check_systemd_service
check_docker_containers
check_docker_images
check_docker_volumes
check_project_files
check_network
check_resources
check_container_health
check_environment
check_docker_config
check_bot_operation
check_logs

print_message "\nStatus check completed!" "$GREEN"
