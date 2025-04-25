#!/usr/bin/env python3
import datetime
from datetime import timedelta

print('Simulation of prize fund calculation:')
print('------------------------------------')

def calculate_prize_fund(months):
    if months <= 0:
        return 0
    base_amount = 5000
    return base_amount * months

start_date = datetime.datetime(2025, 1, 23, 21, 58)

# Show prize fund for various dates
dates = [
    (start_date, 'January 23, 2025 (start)'),
    (start_date + timedelta(days=31), 'February 23, 2025'),
    (start_date + timedelta(days=31+28), 'March 23, 2025'),
    (start_date + timedelta(days=31+28+31), 'April 23, 2025'),
    (start_date + timedelta(days=31+28+31+30), 'May 23, 2025'),
]

for date, label in dates:
    # Calculate months between
    months_diff = (date.year - start_date.year) * 12 + date.month - start_date.month
    prize = calculate_prize_fund(months_diff + 1)  # +1 because first month counts too
    print(f'{label}: {months_diff} months since start, Prize fund = {prize} rubles') 