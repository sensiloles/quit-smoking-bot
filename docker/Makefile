# Docker-specific Makefile for universal bot deployment
# This file provides Docker commands with proper file paths

# Docker compose file
DOCKER_COMPOSE_BASE := docker/docker-compose.yml

.PHONY: docker-help docker-build docker-up docker-down docker-logs docker-clean

docker-help: ## Show Docker-specific commands
	@echo "🐳 Docker Management Commands"
	@echo "================================"
	@echo ""
	@echo "🏗️  Build & Deploy:"
	@echo "  docker-build         Build Docker image with auto-cleanup"
	@echo "  docker-up            Start services"
	@echo "  docker-down          Stop services"
	@echo ""
	@echo "📊 Monitoring:"
	@echo "  docker-logs          Show logs"
	@echo "  docker-status        Show container status"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  docker-clean         Clean up containers and images"
	@echo ""


docker-build: ## Build Docker image with automatic cleanup
	@echo "🔨 Building Docker image..."
	@docker-compose --env-file .env -f $(DOCKER_COMPOSE_BASE) build
	@echo "🧹 Cleaning up dangling images after build..."
	@source venv/bin/activate && python -c "import sys; sys.path.insert(0, 'scripts'); from scripts.modules.docker_utils import cleanup_project_dangling_images; from scripts.modules.environment import load_env; load_env(); cleanup_project_dangling_images(verbose=False)" 2>/dev/null || echo "⚠️  Image cleanup failed, but build completed"

docker-up: ## Start services
	@echo "🚀 Starting services..."
	@docker-compose --env-file .env -f $(DOCKER_COMPOSE_BASE) up -d

docker-down: ## Stop services
	@echo "🛑 Stopping Docker services..."
	@docker-compose --env-file .env -f $(DOCKER_COMPOSE_BASE) down

docker-logs: ## Show logs
	@docker-compose --env-file .env -f $(DOCKER_COMPOSE_BASE) logs -f

docker-status: ## Show container status
	@docker-compose --env-file .env -f $(DOCKER_COMPOSE_BASE) ps

docker-clean: ## Clean up containers and images
	@echo "🧹 Cleaning up Docker resources..."
	@docker-compose --env-file .env -f $(DOCKER_COMPOSE_BASE) down --rmi local --volumes --remove-orphans
	@docker system prune -f
