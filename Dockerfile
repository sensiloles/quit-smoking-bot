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

# Create data and logs directories with proper permissions
RUN mkdir -p /app/data && \
    chown -R appuser:appuser /app/data && \
    mkdir -p /app/logs && \
    chown -R appuser:appuser /app/logs && \
    chmod 777 /app/logs

# Make health check script executable
RUN chmod +x /app/scripts/healthcheck.sh

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
VOLUME /app/logs

# Set entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]

# Add healthcheck - using dedicated script for better diagnostics
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /app/scripts/healthcheck.sh
