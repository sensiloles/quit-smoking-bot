#!/usr/bin/env python3
import argparse
import json
import os
import sys
from datetime import datetime

import requests

def load_admins():
    """Load admin list from JSON file."""
    try:
        with open('/app/data/bot_admins.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("Error: bot_admins.json not found")
        return []

def send_message(token, chat_id, text):
    """Send message to specified chat_id."""
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML"
    }
    try:
        response = requests.post(url, json=data)
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException as e:
        print(f"Error sending message: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Send test results to admins')
    parser.add_argument('--token', required=True, help='Telegram bot token')
    args = parser.parse_args()

    # Load admin list
    admins = load_admins()
    if not admins:
        print("No admins found")
        sys.exit(1)

    # Read test results
    try:
        with open('/app/test_results.txt', 'r') as f:
            test_results = f.read()
    except FileNotFoundError:
        print("Error: test_results.txt not found")
        sys.exit(1)

    # Format message
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    message = (
        f"<b>Test Results - {timestamp}</b>\n\n"
        f"{test_results}"
    )

    # Send to all admins
    success = False
    for admin in admins:
        if send_message(args.token, admin, message):
            success = True

    if not success:
        print("Failed to send test results to any admin")
        sys.exit(1)

if __name__ == "__main__":
    main()
