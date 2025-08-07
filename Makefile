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
	@echo "  $(GREEN)start$(NC)           Start the bot (Docker)"
	@echo "  $(GREEN)start-local$(NC)     Start the bot locally"
	@echo "  $(GREEN)stop$(NC)            Stop the bot (Docker)"
	@echo "  $(GREEN)stop-local$(NC)      Stop the bot locally"
	@echo "  $(GREEN)restart$(NC)         Restart the bot (Docker)"
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
	@echo "  $(GREEN)check-env$(NC)       Complete environment compatibility check"
	@echo "  $(GREEN)check-versions$(NC)  Check dependency versions only"
	@echo "  $(GREEN)test-local$(NC)      Test bot startup locally"
	@echo "  $(GREEN)start-local$(NC)     Start bot locally (needs .env)"
	@echo "  $(GREEN)stop-local$(NC)      Stop locally running bot"
	@echo "  $(GREEN)test-both-envs$(NC)  Test both local and Docker environments"
	@echo "  $(GREEN)fix-deps$(NC)        Fix dependency issues (force reinstall)"
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

build: ## Build Docker image with automatic cleanup
	@echo "$(BLUE)🔨 Building Docker image...$(NC)"
	@SYSTEM_NAME="$(SYSTEM_NAME)" docker-compose -f docker/docker-compose.yml build
	@echo "$(BLUE)🧹 Cleaning up dangling images after build...$(NC)"
	@source venv/bin/activate && python -c "import sys; sys.path.insert(0, 'scripts'); from scripts.modules.docker_utils import cleanup_project_dangling_images; from scripts.modules.environment import load_env; load_env(); cleanup_project_dangling_images(verbose=False)" 2>/dev/null || echo "$(YELLOW)⚠️  Image cleanup failed, but build completed$(NC)"

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

# Compatibility checks
check-versions: ## Check dependency versions and compatibility
	@echo "$(BLUE)🔍 Checking dependency versions...$(NC)"
	@source venv/bin/activate && python3 -c "import telegram; print(f'✅ python-telegram-bot: {telegram.__version__}')" || echo "$(RED)❌ python-telegram-bot not found$(NC)"
	@source venv/bin/activate && python3 -c "import apscheduler; print(f'✅ APScheduler: {apscheduler.__version__}')" || echo "$(RED)❌ APScheduler not found$(NC)"
	@echo "$(GREEN)Version check completed$(NC)"

check-env: ## Complete environment compatibility check (replaces check_environment.py)
	@source venv/bin/activate && $(MANAGER) check-env

test-local: ## Test bot startup locally
	@echo "$(BLUE)🧪 Testing local bot startup...$(NC)"
	@source venv/bin/activate && python3 src/bot.py --help >/dev/null 2>&1 && echo "$(GREEN)✅ Local bot can start$(NC)" || echo "$(RED)❌ Local bot startup failed$(NC)"

start-local: ## Start bot locally (requires .env with BOT_TOKEN)
	@echo "$(BLUE)🚀 Starting bot locally...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found. Create .env with BOT_TOKEN=your_token$(NC)"; \
		exit 1; \
	fi
	@source venv/bin/activate && python3 src/bot.py && echo "$(GREEN)✅ Local bot started$(NC)" || echo "$(RED)❌ Failed to start local bot$(NC)"

stop-local: ## Stop locally running bot
	@echo "$(BLUE)🛑 Stopping local bot...$(NC)"
	@pkill -f 'src/bot.py' 2>/dev/null && echo "$(GREEN)✅ Local bot stopped$(NC)" || echo "$(YELLOW)⚠️ No local bot was running$(NC)"

test-docker: ## Test Docker bot build
	@echo "$(BLUE)🧪 Testing Docker bot build...$(NC)"
	@$(MANAGER) status >/dev/null 2>&1 && echo "$(GREEN)✅ Docker environment ready$(NC)" || echo "$(RED)❌ Docker environment not ready$(NC)"

test-both-envs: check-env test-local ## Test both local and Docker environments
	@echo "$(GREEN)🎯 Environment compatibility check completed$(NC)"

fix-deps: ## Fix dependency issues (force reinstall)
	@echo "$(BLUE)🔧 Fixing dependency issues...$(NC)"
	@source venv/bin/activate && pip install -U --force-reinstall "python-telegram-bot>=22.0"
	@echo "$(GREEN)✅ Dependencies fixed$(NC)"

# Development setup
dev-setup: ## Complete development setup (Python + Docker)
	@echo "$(BLUE)🚀 Complete development setup...$(NC)"
	@$(MANAGER) dev-setup
	@echo "$(GREEN)✅ Development environment ready!$(NC)"
	@echo "$(YELLOW)💡 Next: Reload VS Code window and run 'make install'$(NC)"

python-setup: ## Setup Python virtual environment only
	@echo "$(BLUE)🐍 Setting up Python environment...$(NC)"
	@$(MANAGER) dev-setup
	@echo "$(GREEN)✅ Python environment ready!$(NC)"
	@echo "$(YELLOW)💡 Reload VS Code window to pick up changes$(NC)"
