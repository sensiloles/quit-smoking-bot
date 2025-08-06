# Universal Telegram Bot Framework Docker Image
FROM python:3.9-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create non-root user for security
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} botuser || true && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash botuser

# Install system dependencies  
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY ../pyproject.toml ./
RUN pip install -e .

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /app/logs && \
    chown -R ${USER_ID}:${GROUP_ID} /app

# Copy application code
COPY --chown=botuser:botuser ../ .

# Switch to non-root user
USER botuser

# Health check will use process monitoring

# Production entrypoint with comprehensive initialization
CMD ["python", "docker/entrypoint.py"]
