import logging
import random
from typing import List

from .config import QUOTES_FILE
from .utils import load_json_file

logger = logging.getLogger(__name__)


class QuotesManager:
    def __init__(self):
        self.quotes: List[str] = self._load_quotes()

    def _load_quotes(self) -> List[str]:
        """Load motivational quotes from file."""
        quotes = load_json_file(QUOTES_FILE, [])

        # Create extended quotes list to cover 20 years (240 months)
        if quotes and len(quotes) < 240:
            extended_quotes = quotes.copy()
            for i in range(len(quotes), 240):
                extended_quotes.append(quotes[i % len(quotes)])
            return extended_quotes
        return quotes

    def get_random_quote(self, user_id: str = "global") -> str:
        """Get a random quote."""
        if not self.quotes:
            return (
                "Each day without cigarettes is a victory over yourself. - Mark Twain"
            )

        # Select a random quote
        return random.choice(self.quotes)
