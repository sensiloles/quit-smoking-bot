import datetime
import logging

from .config import (
    BOT_TIMEZONE,
    NOTIFICATION_DAY,
    NOTIFICATION_HOUR,
    NOTIFICATION_MINUTE,
    START_DATE,
    STATUS_MESSAGE,
)
from .quotes import QuotesManager
from .utils import calculate_period, calculate_prize_fund

logger = logging.getLogger(__name__)


class StatusManager:
    def __init__(self, quotes_manager: QuotesManager):
        self.quotes_manager = quotes_manager

    def get_status_info(self, user_id: str = "global") -> str:
        """Generate status information about the non-smoking period."""
        now = datetime.datetime.now(BOT_TIMEZONE)
        duration = now - START_DATE.replace(tzinfo=BOT_TIMEZONE)

        # If we haven't reached the start date yet
        if duration.total_seconds() < 0:
            return f"🚫 The smoke-free period hasn't started yet. Start date: {START_DATE.strftime('%d.%m.%Y %H:%M')}"

        # Calculate years, months and days
        years, months, days = calculate_period(START_DATE, now)

        # Calculate prize fund - using the current month, not months elapsed
        # If we're on or past the 23rd of the month, we count the current month fully
        # Otherwise, we count up to the previous month
        current_month_idx = 0
        if now.day >= NOTIFICATION_DAY:
            # If we're on or past the notification day, count current month fully
            current_month_idx = years * 12 + months
        else:
            # If we're before the notification day, count up to previous month
            current_month_idx = years * 12 + months - 1

        # Make sure we never go below 0 (for the very start)
        current_month_idx = max(0, current_month_idx)

        prize_fund = calculate_prize_fund(current_month_idx)

        # Get next prize fund amount
        next_prize_fund = calculate_prize_fund(current_month_idx + 1)
        prize_increase = next_prize_fund - prize_fund

        # Calculate date of next prize fund increase
        # Move to next month's 23rd
        if now.day <= NOTIFICATION_DAY:
            # If today is before or on the 23rd of the current month
            next_date = now.replace(
                day=NOTIFICATION_DAY,
                hour=NOTIFICATION_HOUR,
                minute=NOTIFICATION_MINUTE,
                second=0,
                microsecond=0,
            )
        # If today is after the 23rd, move to next month
        elif now.month == 12:
            next_date = now.replace(
                year=now.year + 1,
                month=1,
                day=NOTIFICATION_DAY,
                hour=NOTIFICATION_HOUR,
                minute=NOTIFICATION_MINUTE,
                second=0,
                microsecond=0,
            )
        else:
            next_date = now.replace(
                month=now.month + 1,
                day=NOTIFICATION_DAY,
                hour=NOTIFICATION_HOUR,
                minute=NOTIFICATION_MINUTE,
                second=0,
                microsecond=0,
            )

        # Calculate days until next update
        days_until_next = (next_date - now).days + (
            1 if (next_date - now).seconds > 0 else 0
        )

        # Get random motivational quote that's different from the last one
        quote = self.quotes_manager.get_random_quote(user_id)

        # Format the message using template
        return STATUS_MESSAGE.format(
            years=years,
            months=months,
            days=days,
            prize_fund=prize_fund,
            next_increase_date=next_date.strftime("%d.%m.%Y"),
            next_increase_time=next_date.strftime("%H:%M"),
            timezone=BOT_TIMEZONE.zone if BOT_TIMEZONE.zone != "UTC" else "(UTC)",
            increase_amount=prize_increase,
            quote=quote,
        )
