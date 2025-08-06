# Docker-specific Makefile for universal bot deployment
# This file provides Docker commands with proper file paths

# Docker compose files
DOCKER_COMPOSE_BASE := docker/docker-compose.yml
DOCKER_COMPOSE_DEV := docker/docker-compose.dev.yml
DOCKER_COMPOSE_PROD := docker/docker-compose.prod.yml

# Environment detection
ENV ?= prod

.PHONY: docker-help docker-build docker-up docker-down docker-logs docker-clean

docker-help: ## Show Docker-specific commands
	@echo "🐳 Docker Management Commands"
	@echo "================================"
	@echo ""
	@echo "🏗️  Build & Deploy:"
	@echo "  docker-build         Build Docker image"
	@echo "  docker-up            Start services (ENV=dev|prod)"
	@echo "  docker-down          Stop services"
	@echo ""
	@echo "📊 Monitoring:"
	@echo "  docker-logs          Show logs"
	@echo "  docker-status        Show container status"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  docker-clean         Clean up containers and images"
	@echo ""
	@echo "💡 Examples:"
	@echo "  make docker-up ENV=dev     # Development mode"
	@echo "  make docker-up ENV=prod    # Production mode"

docker-build: ## Build Docker image
	@echo "🔨 Building Docker image..."
	@docker-compose -f $(DOCKER_COMPOSE_BASE) build

docker-up: ## Start services (ENV=dev|prod)
	@echo "🚀 Starting services in $(ENV) mode..."
ifeq ($(ENV),dev)
	@docker-compose -f $(DOCKER_COMPOSE_BASE) -f $(DOCKER_COMPOSE_DEV) up -d
else
	@docker-compose -f $(DOCKER_COMPOSE_BASE) -f $(DOCKER_COMPOSE_PROD) up -d
endif

docker-down: ## Stop services
	@echo "🛑 Stopping Docker services..."
	@docker-compose -f $(DOCKER_COMPOSE_BASE) down

docker-logs: ## Show logs
	@docker-compose -f $(DOCKER_COMPOSE_BASE) logs -f

docker-status: ## Show container status  
	@docker-compose -f $(DOCKER_COMPOSE_BASE) ps

docker-clean: ## Clean up containers and images
	@echo "🧹 Cleaning up Docker resources..."
	@docker-compose -f $(DOCKER_COMPOSE_BASE) down --rmi local --volumes --remove-orphans
	@docker system prune -f