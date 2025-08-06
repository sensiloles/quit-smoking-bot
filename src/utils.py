import datetime
import json
import logging
from pathlib import Path
from typing import Any, Union

from .config import MAX_PRIZE_FUND, MONTHLY_AMOUNT, PRIZE_FUND_INCREASE

logger = logging.getLogger(__name__)


def load_json_file(filename: Union[str, Path], default_value: Any = None) -> Any:
    """Generic function to load data from a JSON file."""
    if default_value is None:
        default_value = []

    filepath = Path(filename)
    if filepath.exists():
        try:
            with open(filepath, encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Error loading from {filepath}: {e}")
            return default_value
    else:
        logger.info(f"File {filepath} not found, using default value")
        return default_value


def save_json_file(filename: Union[str, Path], data: Any) -> None:
    """Generic function to save data to a JSON file."""
    filepath = Path(filename)
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.error(f"Error saving to {filepath}: {e}")


def calculate_period(
    start_date: datetime.datetime,
    end_date: datetime.datetime,
) -> tuple[int, int, int]:
    """Calculate years, months and days between two dates."""
    years = end_date.year - start_date.year
    months = end_date.month - start_date.month
    days = end_date.day - start_date.day

    if days < 0:
        # Borrow from months
        months -= 1
        # Add days from previous month
        last_day = (end_date.replace(day=1) - datetime.timedelta(days=1)).day
        days += last_day

    if months < 0:
        # Borrow from years
        years -= 1
        months += 12

    return years, months, days


def calculate_prize_fund(months: int) -> int:
    """Calculate the prize fund based on the number of months.

    Prize fund increases by PRIZE_FUND_INCREASE each month,
    starting from MONTHLY_AMOUNT, up to MAX_PRIZE_FUND.
    """
    if months < 0:
        return 0

    prize_fund = MONTHLY_AMOUNT + (months * PRIZE_FUND_INCREASE)
    return min(prize_fund, MAX_PRIZE_FUND)
