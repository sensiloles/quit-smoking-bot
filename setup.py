from setuptools import setup
import os

# Простое получение имени из окружения
system_name = os.environ.get("SYSTEM_NAME", "quit-smoking-bot")

setup(
    name=system_name,
    version="0.1",
    install_requires=[
        "python-telegram-bot==20.8",
        "pytz==2023.3",
        "apscheduler==3.10.4",
        "python-dotenv==1.0.1",
    ],
    python_requires=">=3.9",
)
