# Quit Smoking Bot Management
# Simplified interface using the modern manager.py

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Modern Python manager
MANAGER := python3 manager.py

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help setup install start stop restart status logs clean build monitor code-check dev-setup python-setup

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(GREEN)🤖 Quit Smoking Bot Management$(NC)"
	@echo "======================================"
	@echo ""
	@echo "$(BLUE)📦 Setup & Installation:$(NC)"
	@echo "  $(GREEN)dev-setup$(NC)       Complete development setup (Python + Docker)"
	@echo "  $(GREEN)python-setup$(NC)    Setup Python virtual environment only"
	@echo "  $(GREEN)setup$(NC)           Initial Docker project setup"
	@echo "  $(GREEN)install$(NC)         Full installation (setup + start)"
	@echo ""
	@echo "$(BLUE)🚀 Service Management:$(NC)"
	@echo "  $(GREEN)start$(NC)           Start the bot"
	@echo "  $(GREEN)stop$(NC)            Stop the bot"
	@echo "  $(GREEN)restart$(NC)         Restart the bot"
	@echo ""
	@echo "$(BLUE)📊 Monitoring & Logs:$(NC)"
	@echo "  $(GREEN)status$(NC)          Show bot status"
	@echo "  $(GREEN)logs$(NC)            Show logs"
	@echo "  $(GREEN)logs-follow$(NC)     Follow logs in real-time"
	@echo "  $(GREEN)monitor$(NC)         Advanced monitoring and diagnostics"
	@echo ""
	@echo "$(BLUE)🧹 Maintenance:$(NC)"
	@echo "  $(GREEN)clean$(NC)           Clean up containers and images"
	@echo "  $(GREEN)clean-deep$(NC)      Deep cleanup (removes all data)"
	@echo "  $(GREEN)build$(NC)           Build Docker image"
	@echo ""
	@echo "$(BLUE)🔧 Development:$(NC)"
	@echo "  $(GREEN)code-check$(NC)      Run pre-commit hooks (formatting, linting)"
	@echo ""
	@echo ""
	@echo "$(BLUE)💡 Quick Examples:$(NC)"
	@echo "  make install             # Complete setup and start"
	@echo "  make start               # Start the bot"
	@echo "  make logs-follow         # Watch logs in real-time"
	@echo "  make status              # Check bot status"
	@echo "  make stop                # Stop the bot"

# Setup and installation
setup: ## Initial project setup
	@echo "$(BLUE)🎯 Setting up project...$(NC)"
	@$(MANAGER) setup

install: ## Full installation (setup + start with monitoring)
	@echo "$(BLUE)🚀 Full installation...$(NC)"
	@$(MANAGER) setup
	@$(MANAGER) start --monitoring
	@echo "$(GREEN)✅ Installation completed!$(NC)"

# Service management
start: ## Start the bot
	@echo "$(BLUE)🚀 Starting bot...$(NC)"
	@$(MANAGER) start

start-full: ## Start with monitoring and logging
	@echo "$(BLUE)🚀 Starting bot with full features...$(NC)"
	@$(MANAGER) start --monitoring --logging

stop: ## Stop the bot
	@echo "$(BLUE)🛑 Stopping bot...$(NC)"
	@$(MANAGER) stop

restart: ## Restart the bot
	@echo "$(BLUE)🔄 Restarting bot...$(NC)"
	@$(MANAGER) restart

restart-rebuild: ## Restart with container rebuild
	@echo "$(BLUE)🔄 Restarting with rebuild...$(NC)"
	@$(MANAGER) restart --rebuild

# Monitoring and logs
status: ## Show bot status
	@$(MANAGER) status

status-detailed: ## Show detailed status with diagnostics
	@$(MANAGER) status --detailed

logs: ## Show logs
	@$(MANAGER) logs

logs-follow: ## Follow logs in real-time
	@$(MANAGER) logs --follow

monitor: ## Advanced monitoring and diagnostics
	@echo "$(BLUE)📊 Running advanced monitoring...$(NC)"
	@python3 scripts/monitor.py --mode diagnostics

# Maintenance
clean: ## Clean up containers and images
	@echo "$(BLUE)🧹 Cleaning up...$(NC)"
	@$(MANAGER) clean

clean-deep: ## Deep cleanup (removes all data)
	@echo "$(BLUE)🧹 Deep cleanup...$(NC)"
	@$(MANAGER) clean --deep

build: ## Build Docker image
	@echo "$(BLUE)🔨 Building Docker image...$(NC)"
	@docker-compose -f docker/docker-compose.yml build

# Advanced operations
token: ## Set bot token interactively
	@echo "$(BLUE)🔑 Setting bot token...$(NC)"
	@read -p "Enter your bot token: " token; \
	$(MANAGER) setup --token "$$token"

backup: ## Create backup of bot data
	@echo "$(BLUE)💾 Creating backup...$(NC)"
	@python3 -c "from scripts.modules.actions import action_backup; action_backup()"

diagnose: ## Comprehensive diagnostics
	@python3 scripts/monitor.py --verbose

# Code quality through pre-commit
code-check: ## Run pre-commit hooks (code formatting, linting, etc)
	@echo "$(BLUE)🔧 Running code quality checks via pre-commit...$(NC)"
	@source venv/bin/activate && pre-commit run --all-files

# Development setup
dev-setup: ## Complete development setup (Python + Docker)
	@echo "$(BLUE)🚀 Complete development setup...$(NC)"
	@python3 dev_setup.py
	@echo "$(GREEN)✅ Development environment ready!$(NC)"
	@echo "$(YELLOW)💡 Next: Reload VS Code window and run 'make install'$(NC)"

python-setup: ## Setup Python virtual environment only
	@echo "$(BLUE)🐍 Setting up Python environment...$(NC)"
	@rm -rf venv
	@python3 -m venv venv
	@source venv/bin/activate && pip install -e '.[dev]'
	@echo "$(GREEN)✅ Python environment ready!$(NC)"
	@echo "$(YELLOW)💡 Reload VS Code window to pick up changes$(NC)"
