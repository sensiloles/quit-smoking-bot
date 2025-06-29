# Makefile for Quit Smoking Bot Management
# This file provides a centralized interface for all bot operations

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values
SYSTEM_NAME ?= quit-smoking-bot
SYSTEM_DISPLAY_NAME ?= "Quit Smoking Bot"
USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Docker Compose command with profiles
COMPOSE := docker-compose
COMPOSE_PROFILES := $(COMPOSE)
COMPOSE_TEST := $(COMPOSE) --profile test
COMPOSE_MONITOR := $(COMPOSE) --profile monitoring
COMPOSE_LOGGING := $(COMPOSE) --profile logging
COMPOSE_ALL := $(COMPOSE) --profile monitoring --profile logging --profile test

.PHONY: help setup permissions bootstrap install start stop restart status logs test clean prune build rebuild dev monitor ps exec shell health check

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(GREEN)🤖 Quit Smoking Bot Management$(NC)"
	@echo "==============================="
	@echo ""
	@echo "$(BLUE)📦 Setup Commands:$(NC)"
	@echo "  $(GREEN)setup$(NC)           Initial project setup (recommended after clone)"
	@echo "  $(GREEN)permissions$(NC)     Setup secure file permissions"
	@echo "  $(GREEN)bootstrap$(NC)       Full project bootstrap (alias for setup)"
	@echo "  $(GREEN)install$(NC)         Full installation with Docker setup"
	@echo "  $(GREEN)env-template$(NC)    Create .env template file"
	@echo ""
	@echo "$(BLUE)🚀 Service Management:$(NC)"
	@echo "  $(GREEN)start$(NC)           Start the bot services"
	@echo "  $(GREEN)stop$(NC)            Stop the bot services"
	@echo "  $(GREEN)restart$(NC)         Restart the bot services"
	@echo "  $(GREEN)build$(NC)           Build Docker containers"
	@echo "  $(GREEN)rebuild$(NC)         Force rebuild Docker containers (no cache)"
	@echo ""
	@echo "$(BLUE)📊 Monitoring & Debugging:$(NC)"
	@echo "  $(GREEN)status$(NC)          Show service status"
	@echo "  $(GREEN)ps$(NC)              Alias for status"
	@echo "  $(GREEN)logs$(NC)            View bot logs (follow)"
	@echo "  $(GREEN)logs-all$(NC)        View all service logs"
	@echo "  $(GREEN)health$(NC)          Check bot health status"
	@echo "  $(GREEN)check$(NC)           Comprehensive service diagnostics"
	@echo "  $(GREEN)shell$(NC)           Open shell in bot container"
	@echo ""
	@echo "$(BLUE)🧪 Testing & Development:$(NC)"
	@echo "  $(GREEN)test$(NC)            Run tests"
	@echo "  $(GREEN)test-unit$(NC)       Run unit tests only"
	@echo "  $(GREEN)test-integration$(NC) Run integration tests only"
	@echo "  $(GREEN)dev$(NC)             Start development environment with monitoring"
	@echo "  $(GREEN)monitor$(NC)         Start with health monitoring"
	@echo ""
	@echo "$(BLUE)🧹 Cleanup:$(NC)"
	@echo "  $(GREEN)clean$(NC)           Stop services and remove containers"
	@echo "  $(GREEN)prune$(NC)           Deep cleanup (containers, images, volumes)"
	@echo "  $(GREEN)uninstall$(NC)       Complete uninstallation (keeps data)"
	@echo ""
	@echo "$(BLUE)🔧 Advanced:$(NC)"
	@echo "  $(GREEN)backup$(NC)          Backup bot data"
	@echo "  $(GREEN)restore$(NC)         Restore bot data (usage: make restore BACKUP=filename)"
	@echo "  $(GREEN)update$(NC)          Update and restart bot"
	@echo "  $(GREEN)env-check$(NC)       Check environment configuration"
	@echo "  $(GREEN)docker-check$(NC)    Check Docker installation"
	@echo "  $(GREEN)config$(NC)          Show Docker Compose configuration"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make setup                    # Initial project setup"
	@echo "  make install                  # Full installation with Docker"
	@echo "  make start                    # Start the bot"
	@echo "  make test                     # Run tests"
	@echo "  make logs                     # View logs"
	@echo "  make stop                     # Stop the bot"

# ==============================================================================
# SETUP AND INITIALIZATION
# ==============================================================================

setup: permissions env-template ## Initial project setup (recommended after clone)
	@echo "$(GREEN)🎉 Project setup completed!$(NC)"
	@echo "$(BLUE)📋 Next steps:$(NC)"
	@echo "  1. Update .env file with your bot token"
	@echo "  2. Run: make start"

permissions: ## Setup secure file permissions
	@echo "$(BLUE)🔐 Setting up secure permissions...$(NC)"
	@mkdir -p data logs
	@chmod 755 data logs
	@if [ -f "data/bot_users.json" ]; then chmod 644 data/*.json; fi
	@if [ -f "logs/bot.log" ]; then chmod 644 logs/*.log; fi
	@find scripts -name "*.sh" -type f -exec chmod 755 {} \; 2>/dev/null || true
	@echo "$(GREEN)✅ Permissions set: directories (755), files (644), scripts (755)$(NC)"

bootstrap: setup ## Full project bootstrap (alias for setup)

env-template: ## Create .env template file
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)📝 Creating .env template...$(NC)"; \
		echo '# Telegram Bot Configuration' > .env; \
		echo 'BOT_TOKEN="your_telegram_bot_token_here"' >> .env; \
		echo '' >> .env; \
		echo '# System Configuration' >> .env; \
		echo 'SYSTEM_NAME="quit-smoking-bot"' >> .env; \
		echo 'SYSTEM_DISPLAY_NAME="Quit Smoking Bot"' >> .env; \
		echo '' >> .env; \
		echo '# Timezone (optional)' >> .env; \
		echo 'TZ="Asia/Novosibirsk"' >> .env; \
		echo '' >> .env; \
		echo '# Notification Settings (optional)' >> .env; \
		echo 'NOTIFICATION_DAY="23"' >> .env; \
		echo 'NOTIFICATION_HOUR="21"' >> .env; \
		echo 'NOTIFICATION_MINUTE="58"' >> .env; \
		echo "$(GREEN)✅ Created .env template$(NC)"; \
	else \
		echo "$(YELLOW)ℹ️  .env file already exists$(NC)"; \
	fi

# ==============================================================================
# SERVICE MANAGEMENT
# ==============================================================================

install: setup build ## Full installation with Docker setup
	@echo "$(BLUE)🔧 Installing bot with Docker setup...$(NC)"
	@./scripts/run.sh --install

start: permissions ## Start the bot services
	@echo "$(BLUE)🚀 Starting bot services...$(NC)"
	@$(COMPOSE) up -d
	@$(MAKE) status

stop: ## Stop the bot services
	@echo "$(BLUE)🛑 Stopping bot services...$(NC)"
	@$(COMPOSE) down --remove-orphans

restart: stop start ## Restart the bot services

build: ## Build Docker containers
	@echo "$(BLUE)🔨 Building Docker containers...$(NC)"
	@$(COMPOSE) build

rebuild: ## Force rebuild Docker containers (no cache)
	@echo "$(BLUE)🔨 Force rebuilding Docker containers...$(NC)"
	@$(COMPOSE) build --no-cache

# ==============================================================================
# MONITORING AND DEBUGGING
# ==============================================================================

status: ## Show service status
	@echo "$(BLUE)📊 Service Status:$(NC)"
	@$(COMPOSE) ps
	@echo ""
	@if [ -n "$$(docker ps -q --filter name=$(SYSTEM_NAME))" ]; then \
		echo "$(GREEN)✅ Bot is running$(NC)"; \
	else \
		echo "$(RED)❌ Bot is not running$(NC)"; \
	fi

ps: status ## Alias for status

logs: ## View bot logs (follow)
	@$(COMPOSE) logs -f bot

logs-all: ## View all service logs
	@$(COMPOSE_ALL) logs -f

health: ## Check bot health status
	@echo "$(BLUE)🏥 Health Check:$(NC)"
	@if [ -n "$$(docker ps -q --filter name=$(SYSTEM_NAME))" ]; then \
		docker inspect --format='{{.State.Health.Status}}' $(SYSTEM_NAME) 2>/dev/null || echo "No health check configured"; \
	else \
		echo "$(RED)❌ Container not running$(NC)"; \
	fi

check: ## Comprehensive service diagnostics
	@./scripts/check-service.sh

exec: ## Execute command in bot container (usage: make exec CMD="command")
	@$(COMPOSE) exec bot $(CMD)

shell: ## Open shell in bot container
	@$(COMPOSE) exec bot sh

# ==============================================================================
# TESTING AND DEVELOPMENT
# ==============================================================================

test: ## Run tests
	@echo "$(BLUE)🧪 Running tests...$(NC)"
	@$(COMPOSE_TEST) run --rm test

test-unit: ## Run unit tests only
	@$(COMPOSE_TEST) run --rm test pytest tests/unit/ -v

test-integration: ## Run integration tests only
	@$(COMPOSE_TEST) run --rm test pytest tests/integration/ -v

dev: ## Start development environment with monitoring
	@echo "$(BLUE)🛠️  Starting development environment...$(NC)"
	@$(COMPOSE_MONITOR) up -d
	@echo "$(GREEN)✅ Development environment started with monitoring$(NC)"
	@$(MAKE) logs

monitor: ## Start with health monitoring
	@echo "$(BLUE)📊 Starting with health monitoring...$(NC)"
	@$(COMPOSE_MONITOR) up -d

# ==============================================================================
# CLEANUP
# ==============================================================================

clean: stop ## Stop services and remove containers
	@echo "$(BLUE)🧹 Cleaning up containers...$(NC)"
	@$(COMPOSE_ALL) down --remove-orphans
	@docker container prune -f

prune: clean ## Deep cleanup (containers, images, volumes)
	@echo "$(BLUE)🧹 Deep cleanup...$(NC)"
	@docker image prune -f
	@docker volume prune -f
	@echo "$(YELLOW)⚠️  Data directory preserved$(NC)"

uninstall: ## Complete uninstallation (keeps data)
	@echo "$(BLUE)🗑️  Uninstalling bot...$(NC)"
	@./scripts/stop.sh --uninstall
	@echo "$(GREEN)✅ Bot uninstalled (data preserved)$(NC)"

# ==============================================================================
# ADVANCED OPERATIONS
# ==============================================================================

backup: ## Backup bot data
	@echo "$(BLUE)💾 Creating backup...$(NC)"
	@mkdir -p backups
	@tar -czf backups/bot-data-$(shell date +%Y%m%d_%H%M%S).tar.gz data/
	@echo "$(GREEN)✅ Backup created in backups/$(NC)"

restore: ## Restore bot data (usage: make restore BACKUP=filename)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)❌ Please specify backup file: make restore BACKUP=filename$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)📥 Restoring from $(BACKUP)...$(NC)"
	@tar -xzf $(BACKUP)
	@$(MAKE) permissions
	@echo "$(GREEN)✅ Data restored$(NC)"

update: ## Update and restart bot
	@echo "$(BLUE)🔄 Updating bot...$(NC)"
	@git pull
	@$(MAKE) rebuild
	@$(MAKE) start
	@echo "$(GREEN)✅ Bot updated and restarted$(NC)"

# ==============================================================================
# UTILITY TARGETS
# ==============================================================================

env-check: ## Check environment configuration
	@echo "$(BLUE)🔍 Environment Check:$(NC)"
	@echo "SYSTEM_NAME: $(SYSTEM_NAME)"
	@echo "USER_ID: $(USER_ID)"
	@echo "GROUP_ID: $(GROUP_ID)"
	@if [ -f .env ]; then \
		echo "$(GREEN)✅ .env file exists$(NC)"; \
		if grep -q "your_telegram_bot_token_here" .env; then \
			echo "$(RED)❌ Please update BOT_TOKEN in .env file$(NC)"; \
		else \
			echo "$(GREEN)✅ BOT_TOKEN configured$(NC)"; \
		fi \
	else \
		echo "$(RED)❌ .env file missing$(NC)"; \
	fi

docker-check: ## Check Docker installation
	@echo "$(BLUE)🐳 Docker Check:$(NC)"
	@if command -v docker >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Docker installed: $$(docker --version)$(NC)"; \
	else \
		echo "$(RED)❌ Docker not installed$(NC)"; \
	fi
	@if command -v docker-compose >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Docker Compose installed: $$(docker-compose --version)$(NC)"; \
	else \
		echo "$(RED)❌ Docker Compose not installed$(NC)"; \
	fi

config: ## Show Docker Compose configuration
	@$(COMPOSE) config

# Quick aliases for common operations
up: start
down: stop
build-force: rebuild 