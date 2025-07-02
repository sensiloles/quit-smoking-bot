# Use Python 3.9 slim image
FROM python:3.9-slim as base

# Set essential environment variables
ENV PYTHONUNBUFFERED=1 \
    IN_CONTAINER=true \
    BUILD_ID=latest

# Create non-root user with the same UID as the host user
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN if ! getent group ${GROUP_ID} > /dev/null 2>&1; then \
        groupadd -g ${GROUP_ID} appuser; \
    else \
        groupadd appuser; \
    fi && \
    useradd -m -u ${USER_ID} -g appuser appuser

# Install system packages as root
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt ./
# Install dependencies from requirements file
RUN pip install --no-cache-dir -r requirements.txt

# Copy setup.py and install the current package in editable mode
COPY setup.py /app/
RUN pip install --no-cache-dir -e .

# Create necessary directories
RUN mkdir -p /app/data /app/logs \
    && chown -R appuser:appuser /app \
    && chmod 755 /app /app/data /app/logs

# Copy application files
COPY --chown=appuser:appuser . .

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Switch to non-root user
USER appuser

# Add PATH for user-installed packages
ENV PATH="/home/appuser/.local/bin:${PATH}"

# Set entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
