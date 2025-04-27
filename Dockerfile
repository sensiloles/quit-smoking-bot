# Use Python 3.9 slim image
FROM python:3.9-slim

# Set timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Novosibirsk /etc/localtime && echo Asia/Novosibirsk > /etc/timezone

# Create non-root user with the same UID as the host user
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} appuser && \
    useradd -m -u ${USER_ID} -g appuser appuser

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

# Copy application files
COPY . .

# Create data and logs directories
RUN mkdir -p /app/data && \
    mkdir -p /app/logs && \
    mkdir -p /app/default_data

# Set proper permissions
RUN chown -R appuser:appuser /app && \
    chmod 755 /app && \
    chmod 755 /app/data && \
    chmod 755 /app/logs && \
    chmod 755 /app/default_data

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
