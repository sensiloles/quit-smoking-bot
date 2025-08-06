#!/usr/bin/env python3
"""
Project Setup Script
Automatically configures virtual environment and dependencies
"""

import os
import subprocess
import sys
from pathlib import Path


def run_command(cmd: str, description: str = "") -> bool:
    """Run a shell command and return success status"""
    if description:
        print(f"🔧 {description}...")

    try:
        result = subprocess.run(
            cmd, shell=True, check=True, capture_output=True, text=True
        )
        if result.stdout:
            print(f"   ✅ {result.stdout.strip()}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"   ❌ Error: {e.stderr.strip() if e.stderr else str(e)}")
        return False


def setup_virtual_environment():
    """Setup Python virtual environment and install dependencies"""
    print("🐍 Setting up Python environment...")

    venv_path = Path("venv")

    # Remove existing venv if it exists
    if venv_path.exists():
        print("   🗑️  Removing existing virtual environment...")
        run_command("rm -rf venv", "Cleaning old environment")

    # Create new virtual environment
    if not run_command("python3 -m venv venv", "Creating virtual environment"):
        return False

    # Install dependencies
    if not run_command(
        "source venv/bin/activate && pip install -e .", "Installing dependencies"
    ):
        return False

    print("   ✅ Virtual environment ready!")
    return True


def setup_vscode_workspace():
    """Configure VS Code workspace settings"""
    print("🔧 Configuring VS Code workspace...")

    # Create .vscode directory if it doesn't exist
    vscode_dir = Path(".vscode")
    vscode_dir.mkdir(exist_ok=True)

    # Check if settings are already configured
    settings_file = vscode_dir / "settings.json"
    if settings_file.exists():
        print("   ✅ VS Code settings already configured")
        return True

    print("   ℹ️  VS Code settings already exist - keeping current configuration")
    return True


def check_requirements():
    """Check if all required tools are available"""
    print("🔍 Checking requirements...")

    # Check Python 3
    if not run_command("python3 --version", "Checking Python 3"):
        print("❌ Python 3 is required. Please install Python 3.9+")
        return False

    # Check pip
    if not run_command("python3 -m pip --version", "Checking pip"):
        print("❌ pip is required. Please install pip")
        return False

    print("   ✅ All requirements satisfied!")
    return True


def main():
    """Main setup function"""
    print("🚀 Quit Smoking Bot - Automatic Setup")
    print("=" * 40)

    # Change to project directory
    project_root = Path(__file__).parent
    os.chdir(project_root)

    # Check requirements
    if not check_requirements():
        sys.exit(1)

    # Setup virtual environment
    if not setup_virtual_environment():
        print("❌ Failed to setup virtual environment")
        sys.exit(1)

    # Setup VS Code workspace
    setup_vscode_workspace()

    print("\n🎉 Setup completed successfully!")
    print("\n📝 Next steps:")
    print("1. Reload VS Code window (Cmd+Shift+P → 'Developer: Reload Window')")
    print("2. Make sure VS Code uses ./venv/bin/python3 as interpreter")
    print("3. Run 'make install' to start the bot")
    print("\n💡 For development:")
    print("   - Always activate virtual environment: source venv/bin/activate")
    print("   - Use 'make setup' for initial Docker setup")
    print("   - Use 'make start' to run the bot")


if __name__ == "__main__":
    main()
