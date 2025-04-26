# Use Python 3.9 slim image
FROM python:3.9-slim

# Set timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Novosibirsk /etc/localtime && echo Asia/Novosibirsk > /etc/timezone

# Create non-root user
RUN useradd -m -u 1000 appuser

# Install system packages as root
RUN apt-get update && apt-get install -y \
    procps \
    apt-utils \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Add build argument
ARG BUILD_ID=latest
ENV BUILD_ID=${BUILD_ID}

# Copy application files and set permissions
COPY . .
RUN chown -R appuser:appuser /app

# Create data directory with proper permissions
RUN mkdir -p /app/data && \
    chown -R appuser:appuser /app/data

# Install Python packages as root
RUN pip install --no-cache-dir . requests pytest

# Switch to non-root user
USER appuser

# Set environment variables
ENV IN_CONTAINER=true
ENV TZ=Asia/Novosibirsk
ENV PATH="/home/appuser/.local/bin:${PATH}"

# Create volume for data persistence
VOLUME /app/data

# Set entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep -f python > /dev/null || exit 1
