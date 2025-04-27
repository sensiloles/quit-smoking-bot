from setuptools import setup, find_packages
import os

# Get system name from environment variable with a default fallback
system_name = os.environ.get("SYSTEM_NAME")

setup(
    name=system_name,
    version="0.1",
    packages=find_packages(),
    package_dir={'': '.'},
    include_package_data=True,
    install_requires=[
        "python-telegram-bot==20.8",
        "pytz==2023.3",
        "apscheduler==3.10.4",
        "python-dotenv==1.0.1",
    ],
    python_requires='>=3.9',
)
