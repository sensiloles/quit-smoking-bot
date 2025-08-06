# Quit Smoking Bot Docker Image
FROM python:3.9-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create non-root user for security
RUN groupadd -g 1000 botuser || true && \
    useradd -m -u 1000 -g 1000 -s /bin/bash botuser

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install Python dependencies first (for better caching)
COPY ../pyproject.toml ./
RUN pip install -e .

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /app/logs && \
    chown -R botuser:botuser /app

# Copy only necessary application files (not logs, data, cache)
COPY --chown=botuser:botuser ../src ./src
COPY --chown=botuser:botuser ../main.py ./
COPY --chown=botuser:botuser ../docker ./docker
COPY --chown=botuser:botuser ../scripts ./scripts

# Switch to non-root user
USER botuser

# Health check will use process monitoring

# Production entrypoint with comprehensive initialization
CMD ["python", "docker/entrypoint.py"]
