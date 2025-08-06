# 🚀 Development Guide

Complete development setup guide for the Quit Smoking Bot project.

## 🏃‍♂️ Quick Start

**For new developers**: This will automatically configure everything you need.

### One-Command Setup

```bash
make dev-setup
```

This command will:

- ✅ Create Python virtual environment
- ✅ Install all dependencies (including APScheduler)
- ✅ Configure VS Code settings
- ✅ Set up development environment

### After Setup

1. **Reload VS Code**: Press `Cmd+Shift+P` → "Developer: Reload Window"
2. **Verify Setup**: Check that imports work (no red underlines in `src/bot.py`)
3. **Create .env file**: Copy from `.env.example` and add your bot token
4. **Start Development**: Use `make start` to run the bot

### Alternative Commands

```bash
# Python environment only
make python-setup

# Docker setup for production
make setup

# View all commands
make help
```

## ⚙️ Manual Setup (if needed)

If automatic setup doesn't work, follow these steps:

### 1. Python Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -e .
```

### 2. Environment Configuration

```bash
# Create environment file
cp .env.example .env

# Edit with your bot token
nano .env
```

### 3. Docker Setup (for production)

```bash
# Docker environment setup
make setup

# Start the bot
make start
```

## 🎯 IDE Setup Guide

This section helps you configure **VS Code** or **Cursor IDE** to properly show linting errors and format code automatically.

> **🔄 Works for both**: VS Code and Cursor use identical configuration since Cursor is built on VS Code.

### Why don't I see linting errors in my IDE?

**Common issues:**

- ❌ IDE uses system Python instead of virtual environment
- ❌ Ruff extension is not installed or configured
- ❌ IDE doesn't read `pyproject.toml` configuration
- ❌ Wrong Python interpreter selected

### Step 1: Install Extensions

Your IDE should automatically suggest these extensions when you open the project:

**Required:**

- `charliermarsh.ruff` - **Main linter and formatter**
- `ms-python.python` - **Python language support**

**Recommended:**

- `ms-python.vscode-pylance` - Enhanced Python IntelliSense
- `tamasfe.even-better-toml` - Better TOML file support
- `redhat.vscode-yaml` - YAML file support

**How to install:**

1. Open Extensions tab: `Cmd+Shift+X` (Mac) / `Ctrl+Shift+X` (Windows/Linux)
2. Search for "Ruff" and install `charliermarsh.ruff`
3. Search for "Python" and install `ms-python.python`

### Step 2: Select Python Interpreter

**This is the most important step!**

1. **Open Command Palette:**

   - Mac: `Cmd+Shift+P`
   - Windows/Linux: `Ctrl+Shift+P`

2. **Type:** `Python: Select Interpreter`

3. **Choose:** `./venv/bin/python3` (should show path like `/path/to/project/venv/bin/python3`)

4. **Verify:** Bottom-left corner should show `Python 3.x.x ('venv': venv)`

### Step 3: Verify Configuration

Check that `.vscode/settings.json` contains these key settings:

```json
{
  "python.defaultInterpreterPath": "./venv/bin/python3",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": "explicit",
    "source.fixAll.ruff": "explicit"
  },
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.organizeImports.ruff": "explicit",
      "source.fixAll.ruff": "explicit"
    }
  },
  "ruff.nativeServer": "on",
  "ruff.importStrategy": "fromEnvironment",
  "ruff.path": ["./venv/bin/ruff"]
}
```

> **💡 Tip:** This file should already exist in your project. If not, create it manually.

### Step 4: Test the Setup

**Open a Python file** (e.g., `src/bot.py`) and verify:

✅ **You should see:**

- 🔴 Red/yellow underlines for errors
- 💡 Light bulb icons for auto-fixes
- 🛠️ Hover tooltips with error descriptions

✅ **Test auto-formatting:**

- Make some formatting mess (extra spaces, wrong indentation)
- Save file: `Cmd+S` (Mac) / `Ctrl+S` (Windows/Linux)
- Code should automatically format

✅ **Test real-time linting:**

- Type some invalid Python syntax
- Errors should appear immediately as you type

## 🔧 Available Commands

### Development

- `make dev-setup` - Complete development environment setup
- `make python-setup` - Python environment only
- `make code-check` - Run linting and formatting

### Bot Management

- `make install` - Full installation and startup
- `make start` - Start the bot
- `make stop` - Stop the bot
- `make restart` - Restart the bot
- `make status` - Check bot status
- `make logs` - View logs

### Maintenance

- `make clean` - Clean Docker containers
- `make build` - Build Docker image

## 🐛 Troubleshooting

### Quick Fixes

If imports still show errors:

1. Run `make python-setup`
2. Reload VS Code window
3. Check Python interpreter: `Cmd+Shift+P` → "Python: Select Interpreter" → `./venv/bin/python3`

### Import Errors

If you see import errors like "apscheduler.schedulers.asyncio could not be resolved":

1. Run `make python-setup` to recreate virtual environment
2. Reload VS Code window
3. Check that VS Code uses the correct Python interpreter

### Virtual Environment Issues

```bash
# Recreate environment
rm -rf venv
make python-setup
```

### Linting Not Working?

**Check Ruff installation:**

```bash
source venv/bin/activate
ruff --version  # Should show: ruff 0.x.x
```

**Test manually:**

```bash
ruff check src/bot.py  # Should show same errors as IDE
```

### Wrong Python Interpreter?

**Check status bar:**

- Bottom-left should show: `Python 3.x.x ('venv': venv)`
- If shows system Python, repeat Step 2 above

### Extensions Not Loaded?

1. **Reload window:** `Cmd+R` (Mac) / `Ctrl+R` (Windows/Linux)
2. **Check extensions:** Go to Extensions tab and verify Ruff is installed
3. **Check Output:** View → Output → Select "Ruff" for error messages

### Still Not Working?

**Compare with terminal:**

```bash
make code-check  # Should show same errors as IDE
```

If terminal shows errors but IDE doesn't → configuration issue
If both show no errors → setup is working correctly!

## 📁 Project Structure

```
quit-smoking-bot/
├── venv/                 # Virtual environment (auto-created)
├── src/                  # Bot source code
├── scripts/              # Management scripts
├── docker/               # Docker configuration
├── .vscode/              # VS Code settings (auto-configured)
├── dev_setup.py          # Automatic setup script
├── Makefile              # Build commands
├── pyproject.toml        # Python dependencies
└── .env.example          # Environment template
```

## 🎯 First Time Setup Checklist

- [ ] Run `make dev-setup`
- [ ] Reload VS Code window
- [ ] Verify Python interpreter is `./venv/bin/python3`
- [ ] Check that imports work (no red underlines)
- [ ] Copy `.env.example` to `.env` and add your `BOT_TOKEN`
- [ ] Run `make start` to test the bot

## 📊 VS Code vs Cursor

| Feature              | VS Code                    | Cursor                     |
| -------------------- | -------------------------- | -------------------------- |
| **Setup Process**    | ✅ Identical               | ✅ Identical               |
| **Extensions**       | ✅ Same marketplace        | ✅ Same marketplace        |
| **Settings**         | ✅ `.vscode/settings.json` | ✅ `.vscode/settings.json` |
| **Hotkeys**          | ✅ Same shortcuts          | ✅ Same shortcuts          |
| **Python Support**   | ✅ Full support            | ✅ Full support + AI chat  |
| **Ruff Integration** | ✅ Native support          | ✅ Native support          |

> **🎯 Bottom line:** This setup works identically in both IDEs!

## ✨ What You'll Get

After completing this setup:

🎯 **Real-time feedback:**

- Errors highlighted as you type
- Instant feedback on code quality
- Auto-fixes available via 💡 icon

🎨 **Automatic formatting:**

- Code formatted on every save
- Imports sorted automatically
- Consistent code style

🔄 **Perfect consistency:**

- IDE shows same errors as `make code-check`
- No surprises during pre-commit checks
- Team-wide code quality standards

## 🎯 Final Verification

**Test consistency between IDE and terminal:**

```bash
# Terminal check
make code-check

# Should match what you see in IDE:
# - Same error count
# - Same error types
# - Same file locations
```

**Both should show:** ✅ All checks passed (or same errors)

## 🚀 Pro Tips

**Keyboard shortcuts:**

- `Cmd/Ctrl + Shift + P` → Command palette
- `Cmd/Ctrl + ,` → Open settings
- `Cmd/Ctrl + Shift + X` → Extensions
- `F1` → Quick command access

**Useful commands:**

- `Python: Select Interpreter` → Switch Python version
- `Python: Refresh` → Reload Python environment
- `Ruff: Restart Server` → Restart Ruff if stuck

## 💡 Development Tips

- Always work within the virtual environment
- Use `make code-check` before committing
- All dependencies are managed in `pyproject.toml`
- VS Code settings are automatically configured
- Use `make help` to see all available commands

---

**🎉 Happy coding!** Your development environment should now be fully configured and ready to use.
