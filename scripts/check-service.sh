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

# Function to check systemd service status
check_systemd_service() {
    debug_print "Starting systemd service status check"
    print_section "Systemd Service Status"

    debug_print "Checking if service is active: $SYSTEM_NAME.service"
    if systemctl is-active $SYSTEM_NAME.service >/dev/null 2>&1; then
        debug_print "Service is active"
        print_message "Service is active" "$GREEN"
    else
        debug_print "Service is not active"
        print_message "Service is not active" "$RED"
    fi

    debug_print "Checking if service is enabled: $SYSTEM_NAME.service"
    if systemctl is-enabled $SYSTEM_NAME.service &>/dev/null; then
        debug_print "Service is enabled"
        print_message "Service is enabled (starts on boot)" "$GREEN"
    else
        debug_print "Service is not enabled"
        print_message "Service is not enabled" "$YELLOW"
    fi

    debug_print "Getting detailed service status"
    print_message "\nDetailed service status:" "$YELLOW"
    systemctl status $SYSTEM_NAME.service --no-pager
    debug_print "Systemd service check completed"
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
        docker ps -a --filter "name=$SYSTEM_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
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
    free -h | grep -i mem

    # Check disk space
    print_message "\nDisk Space:" "$GREEN"
    df -h | grep -E "(Filesystem|/$|/var)"

    # Check Docker resources
    print_message "\nDocker Resources:" "$GREEN"
    docker info | grep -E "(containers|images|volumes|Name)"
}

# Function to check bot health
check_bot_health_status() {
    print_section "Bot Health"

    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    if [ -n "$container_id" ]; then
        # Get container health status
        local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)

        if [ -z "$health_status" ]; then
            print_message "Container has no health check defined" "$YELLOW"
        else
            print_message "Container health status: $health_status" "$YELLOW"

            # Show last health check
            print_message "\nLast health check:" "$YELLOW"
            docker inspect --format='{{json .State.Health.Log}}' $container_id | jq -r '.[-1].Output' 2>/dev/null || \
            docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $container_id | tail -1
        fi

        # Check if the bot process is running
        if docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
            print_message "\nBot process is running inside container" "$GREEN"

            # Get container start time
            local container_start_time=$(docker inspect --format='{{.State.StartedAt}}' $container_id)
            print_message "Container started at: $container_start_time" "$YELLOW"

            # Check the health file
            if docker exec $container_id test -f /app/health/operational 2>/dev/null; then
                print_message "Health file exists (/app/health/operational)" "$GREEN"
                # Show when the file was last updated
                local file_time=$(docker exec $container_id stat -c %y /app/health/operational 2>/dev/null)
                print_message "Health file last updated: $file_time" "$YELLOW"
            else
                print_message "Health file does not exist (/app/health/operational)" "$RED"
            fi

            # Check for logs that indicate the bot is operational
            if docker logs $container_id --tail 100 2>&1 | grep -q "NEW BOT SESSION STARTED"; then
                print_message "\nFound session marker in logs - this is a fresh session" "$GREEN"

                # Check for operational indicator after session start
                docker_log_with_session_start=$(docker logs $container_id 2>&1 | awk '/NEW BOT SESSION STARTED/{flag=1;next} flag')
                if echo "$docker_log_with_session_start" | grep -q "Application started"; then
                    print_message "Bot is operational (found 'Application started' in logs)" "$GREEN"

                    # Check for conflict errors only in current session
                    if echo "$docker_log_with_session_start" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
                        print_error "\nWARNING: Conflict detected in current session! Another bot instance is running with the same token."
                        print_message "This may prevent your bot from functioning correctly." "$RED"
                    fi
                else
                    print_message "\nCould not find evidence of successful startup in current session" "$YELLOW"
                fi
            elif docker logs $container_id --tail 100 2>&1 | grep -q "Application started"; then
                print_message "\nBot is operational (found 'Application started' in logs)" "$GREEN"

                # Check for recent conflict errors (last 10 lines)
                if docker logs $container_id --tail 10 2>&1 | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
                    print_error "\nWARNING: Recent conflict detected in logs! Another bot instance is running with the same token."
                    print_message "This may prevent your bot from functioning correctly." "$RED"
                fi

                # Inform about old conflict errors if present
                if docker exec $container_id grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates" /app/logs/bot.log 2>/dev/null; then
                    conflict_count=$(docker exec $container_id grep -c "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates" /app/logs/bot.log 2>/dev/null || echo 0)
                    print_message "\nNote: Found historical conflict errors ($conflict_count) in full log file." "$YELLOW"
                    print_message "If health check is failing but no current conflicts, try clearing logs:" "$YELLOW"
                    print_message "docker exec $SYSTEM_NAME sh -c 'echo > /app/logs/bot.log' && docker restart $SYSTEM_NAME" "$YELLOW"
                fi
            elif docker logs $container_id --tail 100 2>&1 | grep -q "\"HTTP/1.1 200 OK\""; then
                print_message "\nBot is making API calls (found successful HTTP requests in logs)" "$GREEN"
            else
                print_message "\nCould not find evidence of bot activity in recent logs" "$YELLOW"
            fi
        else
            print_error "\nBot process is NOT running inside container"
        fi
    else
        print_message "No running container found" "$RED"
    fi
}

# Function to report overall status
report_overall_status() {
    print_section "Overall Status"

    local container_id=$(docker ps -q --filter "name=$SYSTEM_NAME")
    local service_active=false
    local container_running=false
    local bot_running=false
    local health_check_ok=false

    if systemctl is-active $SYSTEM_NAME.service >/dev/null 2>&1; then
        service_active=true
        print_message "Systemd service: ACTIVE" "$GREEN"
    else
        print_message "Systemd service: NOT ACTIVE" "$RED"
    fi

    if [ -n "$container_id" ]; then
        container_running=true
        print_message "Docker container: RUNNING" "$GREEN"

        if docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
            bot_running=true
            print_message "Bot process: RUNNING" "$GREEN"
        else
            print_message "Bot process: NOT RUNNING" "$RED"
        fi

        local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
        if [ "$health_status" = "healthy" ]; then
            health_check_ok=true
            print_message "Health check: PASSED" "$GREEN"
        else
            print_message "Health check: $health_status" "$YELLOW"
        fi
    else
        print_message "Docker container: NOT RUNNING" "$RED"
    fi

    print_message "\nSummary:" "$YELLOW"
    if $service_active && $container_running && $bot_running && $health_check_ok; then
        print_message "Bot is fully operational" "$GREEN"
    elif $service_active && $container_running && $bot_running; then
        print_message "Bot is operational but health check may not have passed" "$YELLOW"
    elif $service_active && $container_running; then
        print_message "Bot container is running but bot process is not" "$RED"
    elif $service_active; then
        print_message "Service is active but container is not running" "$RED"
    else
        print_message "Bot is not operational" "$RED"
    fi

    if [ -f "/etc/systemd/system/$SYSTEM_NAME.service" ]; then
        print_message "\nAvailable commands:" "$YELLOW"
        print_message "  Start: sudo systemctl start $SYSTEM_NAME.service" "$YELLOW"
        print_message "  Stop: sudo systemctl stop $SYSTEM_NAME.service" "$YELLOW"
        print_message "  Restart: sudo systemctl restart $SYSTEM_NAME.service" "$YELLOW"
        print_message "  Status: sudo systemctl status $SYSTEM_NAME.service" "$YELLOW"
        print_message "  Logs: sudo journalctl -u $SYSTEM_NAME.service" "$YELLOW"

        if [ -n "$container_id" ]; then
            print_message "  Container logs: docker logs $container_id" "$YELLOW"
        fi
    else
        print_message "\nService is not installed." "$YELLOW"
    fi
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
        print_warning "docker-compose is not installed. Limited checks will be performed."
    fi

    # Check if jq is installed (for parsing JSON)
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq is not installed. Some health checks may not display properly."
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

    print_message "Checking status of $SYSTEM_NAME bot service..." "$YELLOW"

    # Run prerequisite checks
    check_prerequisites

    # Run all check functions
    check_systemd_service
    check_docker_containers
    check_docker_images
    check_docker_volumes
    check_project_files
    check_network
    check_logs
    check_resources
    check_bot_health_status
    report_overall_status
}

# Run main function
main
