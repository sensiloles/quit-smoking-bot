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

# Script execution settings
SCRIPT_DIR := ./scripts
SCRIPT_FLAGS ?= 
DEBUG ?= 0
VERBOSE ?= 0
DRY_RUN ?= 0

# Export variables for scripts
export SYSTEM_NAME
export SYSTEM_DISPLAY_NAME
export USER_ID
export GROUP_ID
export DEBUG
export VERBOSE
export DRY_RUN

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Docker Compose command with profiles
COMPOSE := docker-compose
COMPOSE_PROFILES := $(COMPOSE)

COMPOSE_MONITOR := $(COMPOSE) --profile monitoring
COMPOSE_LOGGING := $(COMPOSE) --profile logging
COMPOSE_ALL := $(COMPOSE) --profile monitoring --profile logging

.PHONY: help setup permissions bootstrap install start stop restart status logs clean prune build rebuild dev monitor monitor-compose ps exec shell health health-status health-monitor diagnostics check

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
	@echo "  $(GREEN)start$(NC)           Start the bot services with health monitoring"
	@echo "  $(GREEN)stop$(NC)            Stop the bot services"
	@echo "  $(GREEN)restart$(NC)         Restart the bot services"
	@echo "  $(GREEN)build$(NC)           Build Docker containers"
	@echo "  $(GREEN)rebuild$(NC)         Force rebuild Docker containers (no cache)"
	@echo ""
	@echo "$(BLUE)📊 Monitoring & Debugging:$(NC)"
	@echo "  $(GREEN)status$(NC)          Show service status"
	@echo "  $(GREEN)logs$(NC)            View bot logs (follow)"
	@echo "  $(GREEN)logs-all$(NC)        View all service logs"
	@echo "  $(GREEN)health$(NC)          Check bot health status"
	@echo "  $(GREEN)check$(NC)           Comprehensive service diagnostics"
	@echo "  $(GREEN)shell$(NC)           Open shell in bot container"
	@echo ""
	@echo "$(BLUE)🛠️  Development:$(NC)"
	@echo "  $(GREEN)dev$(NC)             Start development environment (alias for start)"
	@echo "  $(GREEN)monitor$(NC)         Start continuous health monitoring"
	@echo ""
	@echo "$(BLUE)🧹 Cleanup:$(NC)"
	@echo "  $(GREEN)clean$(NC)           Stop services and remove containers"
	@echo "  $(GREEN)prune$(NC)           Deep cleanup (containers, images, volumes)"
	@echo "  $(GREEN)uninstall$(NC)       Complete uninstallation (keeps data)"
	@echo ""
	@echo "$(BLUE)🔧 Advanced:$(NC)"
	@echo "  $(GREEN)env-check$(NC)       Check environment configuration"
	@echo "  $(GREEN)docker-check$(NC)    Check Docker installation"
	@echo "  $(GREEN)config$(NC)          Show Docker Compose configuration"
	@echo ""
	@echo "$(BLUE)🛠️  Script Options:$(NC)"
	@echo "  DEBUG=1              Enable debug output"
	@echo "  VERBOSE=1            Enable verbose output"
	@echo "  DRY_RUN=1            Show what would be done without executing"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make setup                    # Initial project setup"
	@echo "  make install DEBUG=1         # Full installation with debug output"
	@echo "  make start VERBOSE=1         # Start with verbose output"
	@echo "  make logs                    # View logs"
	@echo "  make stop                    # Stop the bot"

# ==============================================================================
# SETUP AND INITIALIZATION
# ==============================================================================

setup: ## Initial project setup (recommended after clone)
	@echo "$(BLUE)🎯 Running bootstrap script...$(NC)"
	@$(SCRIPT_DIR)/bootstrap.sh

permissions: ## Setup secure file permissions
	@echo "$(BLUE)🔐 Setting up secure permissions...$(NC)"
	@$(SCRIPT_DIR)/setup-permissions.sh

bootstrap: setup ## Alias for setup

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
	@$(SCRIPT_DIR)/run.sh --install $(SCRIPT_FLAGS)

start: permissions ## Start the bot services with health monitoring
	@echo "$(BLUE)🚀 Starting bot services with health monitoring...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would start services with: $(COMPOSE_MONITOR) up -d$(NC)"; \
	else \
		$(COMPOSE_MONITOR) up -d; \
		echo "$(GREEN)✅ Bot started with health monitoring$(NC)"; \
		$(MAKE) status; \
	fi

stop: ## Stop the bot services
	@echo "$(BLUE)🛑 Stopping bot services...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would stop services with: $(COMPOSE) down --remove-orphans$(NC)"; \
	else \
		$(COMPOSE) down --remove-orphans; \
	fi

restart: stop start ## Restart the bot services

build: ## Build Docker containers
	@echo "$(BLUE)🔨 Building Docker containers...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would build containers with: $(COMPOSE) build$(NC)"; \
	else \
		$(COMPOSE) build; \
	fi

rebuild: ## Force rebuild Docker containers (no cache)
	@echo "$(BLUE)🔨 Force rebuilding Docker containers...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would rebuild containers with: $(COMPOSE) build --no-cache$(NC)"; \
	else \
		$(COMPOSE) build --no-cache; \
	fi

# ==============================================================================
# MONITORING AND DEBUGGING
# ==============================================================================

status: ## Show service status
	@echo "$(BLUE)📊 Service Status:$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would check service status with: $(COMPOSE) ps$(NC)"; \
		echo "$(YELLOW)[DRY-RUN] Would check if container is running$(NC)"; \
	else \
		$(COMPOSE) ps; \
		echo ""; \
		if [ -n "$$(docker ps -q --filter name=$(SYSTEM_NAME) 2>/dev/null)" ]; then \
			echo "$(GREEN)✅ Bot is running$(NC)"; \
		else \
			echo "$(RED)❌ Bot is not running$(NC)"; \
		fi \
	fi

logs: ## View bot logs (follow)
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would view bot logs with: $(COMPOSE) logs -f bot$(NC)"; \
	else \
		$(COMPOSE) logs -f bot; \
	fi

logs-all: ## View all service logs
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would view all service logs with: $(COMPOSE_ALL) logs -f$(NC)"; \
	else \
		$(COMPOSE_ALL) logs -f; \
	fi

health: ## Quick health check (Docker mode)
	@echo "$(BLUE)🔍 Running health check...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would run: $(SCRIPT_DIR)/health-monitor.sh --mode docker$(NC)"; \
	else \
		$(SCRIPT_DIR)/health-monitor.sh --mode docker; \
	fi

health-status: ## Current health status snapshot
	@echo "$(BLUE)📊 Health status snapshot...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would run: $(SCRIPT_DIR)/health-monitor.sh --mode status$(NC)"; \
	else \
		$(SCRIPT_DIR)/health-monitor.sh --mode status; \
	fi

health-monitor: ## Single monitoring check
	@echo "$(BLUE)🔍 Running monitoring check...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would run: $(SCRIPT_DIR)/health-monitor.sh --mode monitor$(NC)"; \
	else \
		$(SCRIPT_DIR)/health-monitor.sh --mode monitor; \
	fi

diagnostics: ## Comprehensive system diagnostics
	@echo "$(BLUE)🔬 Running comprehensive diagnostics...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would run: $(SCRIPT_DIR)/health-monitor.sh --mode diagnostics$(NC)"; \
	else \
		$(SCRIPT_DIR)/health-monitor.sh --mode diagnostics; \
	fi

check: ## Comprehensive service diagnostics
	@$(SCRIPT_DIR)/check-service.sh $(SCRIPT_FLAGS)

exec: ## Execute command in bot container (usage: make exec CMD="command")
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would execute: $(COMPOSE) exec bot $(CMD)$(NC)"; \
	else \
		$(COMPOSE) exec bot $(CMD); \
	fi

shell: ## Open shell in bot container
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would open shell with: $(COMPOSE) exec bot sh$(NC)"; \
	else \
		$(COMPOSE) exec bot sh; \
	fi

# ==============================================================================
# DEVELOPMENT
# ==============================================================================

dev: start ## Start development environment (alias for start)
	@echo "$(GREEN)✅ Development environment started$(NC)"
	@$(MAKE) logs

monitor: ## Start continuous health monitoring
	@echo "$(BLUE)🔄 Starting continuous health monitoring...$(NC)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY-RUN] Would run: $(SCRIPT_DIR)/health-monitor.sh --mode monitor --continuous$(NC)"; \
	else \
		$(SCRIPT_DIR)/health-monitor.sh --mode monitor --continuous; \
	fi

monitor-compose: ## Start with Docker Compose health monitoring service
	@echo "$(BLUE)📊 Starting Docker Compose health monitoring...$(NC)"
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


uninstall: ## Complete uninstallation (keeps data)
	@echo "$(BLUE)🗑️  Uninstalling bot...$(NC)"
	@$(SCRIPT_DIR)/stop.sh --uninstall $(SCRIPT_FLAGS)
	@echo "$(GREEN)✅ Bot uninstalled$(NC)"

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