# Telegram Bot Framework Management
# Simple interface for universal Telegram bot operations

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values
SYSTEM_NAME ?= telegram-bot
USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)

# Python manager
MANAGER := python3 manager.py

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help setup start stop restart status logs clean build install dev

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(GREEN)🤖 Telegram Bot Framework Management$(NC)"
	@echo "======================================"
	@echo ""
	@echo "$(BLUE)📦 Setup:$(NC)"
	@echo "  $(GREEN)setup$(NC)           Initial project setup"
	@echo "  $(GREEN)install$(NC)         Full installation (setup + start)"
	@echo ""
	@echo "$(BLUE)🚀 Management:$(NC)"
	@echo "  $(GREEN)start$(NC)           Start the bot"
	@echo "  $(GREEN)stop$(NC)            Stop the bot"
	@echo "  $(GREEN)restart$(NC)         Restart the bot"
	@echo ""
	@echo "$(BLUE)📊 Monitoring:$(NC)"
	@echo "  $(GREEN)status$(NC)          Show bot status"
	@echo "  $(GREEN)logs$(NC)            Show logs"
	@echo "  $(GREEN)logs-follow$(NC)     Follow logs in real-time"
	@echo ""
	@echo "$(BLUE)🧹 Maintenance:$(NC)"
	@echo "  $(GREEN)clean$(NC)           Clean up containers and images"
	@echo "  $(GREEN)build$(NC)           Build Docker image"
	@echo ""
	@echo "$(BLUE)🛠️ Development:$(NC)"
	@echo "  $(GREEN)dev$(NC)             Run bot locally (without Docker)"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make setup               # Initial setup"
	@echo "  make install             # Setup and start"
	@echo "  make start               # Start the bot"
	@echo "  make logs-follow         # Watch logs"
	@echo "  make stop                # Stop the bot"

# Setup and installation
setup: ## Initial project setup
	@echo "$(BLUE)🎯 Setting up project...$(NC)"
	@$(MANAGER) setup

install: setup start ## Full installation (setup + start)
	@echo "$(GREEN)✅ Installation completed!$(NC)"

# Service management
start: ## Start the bot
	@echo "$(BLUE)🚀 Starting bot...$(NC)"
	@$(MANAGER) start

stop: ## Stop the bot
	@echo "$(BLUE)🛑 Stopping bot...$(NC)"
	@$(MANAGER) stop

restart: ## Restart the bot
	@echo "$(BLUE)🔄 Restarting bot...$(NC)"
	@$(MANAGER) restart

# Monitoring
status: ## Show bot status
	@$(MANAGER) status

logs: ## Show logs
	@$(MANAGER) logs

logs-follow: ## Follow logs in real-time
	@$(MANAGER) logs -f

# Maintenance
clean: ## Clean up containers and images
	@echo "$(BLUE)🧹 Cleaning up...$(NC)"
	@$(MANAGER) clean

build: ## Build Docker image
	@echo "$(BLUE)🔨 Building Docker image...$(NC)"
	@docker-compose build

# Development
dev: ## Run bot locally (without Docker)
	@echo "$(BLUE)🛠️ Running bot locally...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found. Run 'make setup' first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)💡 Running bot in development mode...$(NC)"
	@python3 main.py 