#!/usr/bin/env python3
"""
Main entry point for the Telegram Bot Framework

This file serves as the primary entry point and can be used both
for running the bot directly and as a module entry point.
"""

import sys
import os
from pathlib import Path

# Add src to Python path for imports
project_root = Path(__file__).parent.absolute()
src_path = project_root / "src"
sys.path.insert(0, str(src_path))

def main():
    """Main entry point"""
    try:
        # Import the bot module from src
        from src.bot import main as bot_main
        
        # Run the bot
        bot_main()
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("💡 Make sure the src/ directory contains your bot implementation")
        print("📖 See src/ directory for the example bot (quit-smoking-bot)")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error starting bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
