#!/bin/bash

# Source common functions and variables
source "$(dirname "$0")/common.sh"

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
    print_section "Container Health"
    
    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        # Check container state
        local state=$(docker inspect --format '{{.State.Status}}' $container_id)
        print_message "Container State: $state" "$GREEN"
        
        # Check container health status
        local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id)
        if [ "$health_status" = "healthy" ]; then
            print_message "Container health status: $health_status" "$GREEN"
        else
            print_message "Container health status: $health_status" "$RED"
            
            # Get health check logs if unhealthy
            if [ "$health_status" = "unhealthy" ]; then
                print_message "\nHealth Check Logs:" "$YELLOW"
                # Check if jq is installed
                if command -v jq &> /dev/null; then
                    docker inspect --format '{{json .State.Health.Log}}' $container_id | jq -r '.[] | "Exit Code: \(.ExitCode)\nOutput: \(.Output)\nStart: \(.Start)\nEnd: \(.End)\n"'
                else
                    # Fallback to raw JSON output if jq is not available
                    print_message "jq is not installed. Raw health check logs:" "$YELLOW"
                    docker inspect --format '{{json .State.Health.Log}}' $container_id
                fi
                
                # Check container logs for potential health check failures
                print_message "\nRecent Container Logs (last 20 lines):" "$YELLOW"
                docker logs --tail 20 $container_id
            fi
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
        
        # Check container logs for errors
        print_message "\nRecent Error Logs:" "$GREEN"
        local error_logs=$(docker logs --tail 50 $container_id 2>&1 | grep -i "error\|exception\|fail\|warning\|critical" | tail -10)
        if [ -n "$error_logs" ]; then
            echo "$error_logs"
        else
            print_message "No recent errors found in logs" "$GREEN"
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
        local required_vars=("BOT_TOKEN")
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
        local required_vars=("BOT_TOKEN")
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
check_logs

print_message "\nStatus check completed!" "$GREEN"
