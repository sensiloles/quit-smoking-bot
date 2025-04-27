import pytest
import os

@pytest.fixture(scope="session") # Use session scope for efficiency
def bot_token():
    """Pytest fixture to provide the bot token from environment variable."""
    token = os.environ.get("BOT_TOKEN")
    if not token:
        pytest.skip("BOT_TOKEN environment variable not set, skipping integration tests requiring token.")
    return token
