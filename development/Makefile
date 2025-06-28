# Development Environment Makefile
# Quick commands for managing the development environment

.PHONY: help start start-systemd stop build clean test setup logs shell test-env test-security test-performance monitor

# Default target
help: ## Show this help message
	@echo "Development Environment Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make run-bot            # 🤖 Run bot in development (ONE COMMAND!)"
	@echo "  make run-bot-quick      # 🚀 Start environment + bot instantly"
	@echo "  make start              # Start development environment"
	@echo "  make shell              # Connect to running environment"
	@echo "  make test-env           # Test environment quality"
	@echo "  make monitor            # Monitor environment health"
	@echo "  make clean              # Interactive cleanup"

start: ## Start development environment (interactive)
	@echo "🚀 Starting development environment..."
	./start-dev.sh

start-basic: ## Start lightweight development environment without systemd
	@echo "🚀 Starting lightweight development environment..."
	./start-dev.sh --basic

start-detached: ## Start development environment in background
	@echo "🚀 Starting development environment in background..."
	./start-dev.sh --detach

start-database: ## Start with database services (PostgreSQL)
	@echo "🚀 Starting development environment with database..."
	docker-compose --profile database up -d

stop: ## Stop development environment
	@echo "🛑 Stopping development environment..."
	docker-compose down

build: ## Build development environment
	@echo "🔨 Building development environment..."
	./start-dev.sh --build

rebuild: ## Force rebuild development environment
	@echo "🔨 Force rebuilding development environment..."
	./start-dev.sh --build --clean

clean: ## Interactive cleanup of development environment
	@echo "🧹 Starting interactive cleanup..."
	./clean-dev.sh

clean-all: ## Complete cleanup (containers, images, volumes, networks)
	@echo "🧹 Performing complete cleanup..."
	./clean-dev.sh --all

clean-containers: ## Remove only containers
	@echo "🧹 Cleaning up containers..."
	./clean-dev.sh --containers

clean-images: ## Remove only images
	@echo "🧹 Cleaning up images..."
	./clean-dev.sh --images

clean-volumes: ## Remove only volumes (⚠️ data will be lost)
	@echo "🧹 Cleaning up volumes..."
	./clean-dev.sh --volumes

clean-system: ## Run Docker system prune (remove unused resources)
	@echo "🧹 Cleaning up Docker system..."
	./clean-dev.sh --system

clean-force: ## Force cleanup without confirmation
	@echo "🧹 Force cleaning development environment..."
	./clean-dev.sh --all --force

run-bot: ## Run bot inside development environment (one command)
	@echo "🤖 Starting bot in development environment..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		docker-compose exec dev-env /workspace/development/scripts/run-bot-dev.sh; \
	else \
		echo "Starting environment and bot..."; \
		docker-compose up -d dev-env redis && sleep 10 && \
		docker-compose exec dev-env /workspace/development/scripts/run-bot-dev.sh; \
	fi

run-bot-quick: ## Quick bot start (start environment + bot in one go)
	@echo "🚀 Quick bot start..."
	./start-dev.sh --detach
	@sleep 15
	@echo "🤖 Starting bot..."
	docker-compose exec dev-env /workspace/development/scripts/run-bot-dev.sh

test: ## Run comprehensive tests
	@echo "🧪 Running tests..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		docker-compose exec dev-env /workspace/development/scripts/test-scripts.sh; \
	else \
		echo "Starting environment for testing..."; \
		docker-compose run --rm dev-env /workspace/development/scripts/test-scripts.sh; \
	fi

test-env: ## Run environment quality tests
	@echo "🧪 Running environment quality tests..."
	./scripts/test-environment.sh

test-env-quick: ## Run quick environment tests
	@echo "🧪 Running quick environment tests..."
	./scripts/test-environment.sh --quick

test-security: ## Run security tests only
	@echo "🔒 Running security tests..."
	./scripts/test-environment.sh --security-only

test-performance: ## Run performance tests only
	@echo "⚡ Running performance tests..."
	./scripts/test-environment.sh --performance-only

test-ci: ## Run tests in CI mode
	@echo "🤖 Running CI tests..."
	./scripts/test-environment.sh --ci --quick

test-report: ## Generate test report
	@echo "📊 Generating test report..."
	./scripts/test-environment.sh --report

setup: ## Setup development environment
	@echo "🔧 Setting up development environment..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		docker-compose exec dev-env /workspace/development/scripts/setup-env.sh; \
	else \
		echo "Starting environment for setup..."; \
		docker-compose run --rm dev-env /workspace/development/scripts/setup-env.sh; \
	fi

shell: ## Connect to running development environment
	@echo "🐚 Connecting to development environment..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		docker-compose exec dev-env bash; \
	elif docker-compose ps -q dev-env-basic | grep -q .; then \
		docker-compose exec dev-env-basic bash; \
	else \
		echo "No running environment found. Starting new session..."; \
		./start-dev.sh; \
	fi

shell-root: ## Connect as root user (for debugging)
	@echo "🐚 Connecting as root user..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		docker-compose exec --user root dev-env bash; \
	else \
		echo "Environment not running. Please start it first."; \
		exit 1; \
	fi

logs: ## Show logs from development environment
	@echo "📋 Showing development environment logs..."
	docker-compose logs -f

logs-app: ## Show application logs only
	@echo "📋 Showing application logs..."
	docker-compose logs -f dev-env

logs-redis: ## Show Redis logs
	@echo "📋 Showing Redis logs..."
	docker-compose logs -f redis

status: ## Show status of development environment
	@echo "📊 Development environment status:"
	@docker-compose ps
	@echo ""
	@echo "🔍 Container health status:"
	@docker inspect quit-smoking-bot-dev --format='{{.State.Health.Status}}' 2>/dev/null || echo "Health check not available"

health: ## Check environment health
	@echo "🩺 Checking environment health..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		docker-compose exec dev-env /usr/local/bin/healthcheck.sh; \
	else \
		echo "Environment not running"; \
		exit 1; \
	fi

monitor: ## Start real-time monitoring
	@echo "📊 Starting environment monitoring..."
	@echo "Press Ctrl+C to stop"
	@while true; do \
		clear; \
		echo "=== Development Environment Monitor ==="; \
		echo "Time: $$(date)"; \
		echo ""; \
		echo "Container Status:"; \
		docker-compose ps; \
		echo ""; \
		echo "Resource Usage:"; \
		docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" quit-smoking-bot-dev quit-smoking-bot-redis-dev 2>/dev/null || echo "Containers not running"; \
		echo ""; \
		echo "Health Status:"; \
		docker inspect quit-smoking-bot-dev --format='Container: {{.State.Health.Status}}' 2>/dev/null || echo "Health check not available"; \
		echo ""; \
		sleep 5; \
	done

# Advanced targets
test-scripts: ## Test only script syntax and help commands
	@echo "🧪 Testing script syntax..."
	@docker-compose run --rm dev-env bash -c "cd /workspace && find scripts/ development/scripts/ -name '*.sh' -exec bash -n {} \;"

test-integration: ## Run integration tests (requires BOT_TOKEN)
	@echo "🧪 Running integration tests..."
	@docker-compose run --rm dev-env bash -c "cd /workspace && ./scripts/test.sh"

test-docker: ## Test Docker configuration validity
	@echo "🧪 Testing Docker configuration..."
	@docker-compose config -q && echo "✅ docker-compose.yml is valid" || echo "❌ docker-compose.yml has errors"
	@docker build --dry-run -f Dockerfile . >/dev/null 2>&1 && echo "✅ Dockerfile is valid" || echo "❌ Dockerfile has errors"

install-deps: ## Install test dependencies
	@echo "📦 Installing test dependencies..."
	@pip3 install -r requirements-test.txt --user

update-deps: ## Update test dependencies
	@echo "📦 Updating test dependencies..."
	@pip3 install -r requirements-test.txt --user --upgrade

benchmark: ## Run performance benchmarks
	@echo "⚡ Running performance benchmarks..."
	@if docker-compose ps -q dev-env | grep -q .; then \
		echo "Container startup time:"; \
		time docker-compose restart dev-env; \
		echo ""; \
		echo "Python import time:"; \
		docker-compose exec dev-env bash -c "time python3 -c 'import sys, os, json'"; \
		echo ""; \
		echo "Resource usage:"; \
		docker stats --no-stream quit-smoking-bot-dev; \
	else \
		echo "Environment not running"; \
		exit 1; \
	fi

# Security targets
security-scan: ## Run security scans
	@echo "🔒 Running security scans..."
	@echo "Checking Docker security..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image quit-smoking-bot-dev || echo "Trivy not available"
	@echo ""
	@echo "Checking container configuration..."
	@docker inspect quit-smoking-bot-dev --format='Privileged: {{.HostConfig.Privileged}}' || echo "Container not running"

# Maintenance targets
update: ## Update development environment
	@echo "🔄 Updating development environment..."
	@git pull origin main
	@docker-compose pull
	@./start-dev.sh --build

backup: ## Backup development data
	@echo "💾 Backing up development data..."
	@mkdir -p ../backups
	@docker run --rm -v quit-smoking-bot-dev-home:/data -v $(PWD)/../backups:/backup ubuntu tar czf /backup/dev-home-$$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "✅ Backup completed in ../backups/"

restore: ## Restore development data (requires backup file)
	@echo "📥 Restoring development data..."
	@echo "Available backups:"
	@ls -la ../backups/dev-home-*.tar.gz 2>/dev/null || echo "No backups found"
	@read -p "Enter backup filename: " backup && \
	docker run --rm -v quit-smoking-bot-dev-home:/data -v $(PWD)/../backups:/backup ubuntu tar xzf /backup/$$backup -C /data

# Quick development shortcuts
dev: start ## Alias for start
dev-basic: start-basic ## Alias for start-basic  
down: stop ## Alias for stop 