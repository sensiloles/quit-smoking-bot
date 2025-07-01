# Use Python 3.9 slim image
FROM python:3.9-slim as base

# Set timezone and environment variables
ENV TZ=Asia/Novosibirsk \
    PYTHONUNBUFFERED=1 \
    IN_CONTAINER=true \
    BUILD_ID=latest

# Set timezone
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

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
    apt-utils \
    curl \
    && curl -fsSL https://get.docker.com -o get-docker.sh \
    && sh get-docker.sh \
    && rm get-docker.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt requirements-dev.txt ./
# Install dependencies from requirements files
RUN pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt

# Copy setup.py and install the current package in editable mode
COPY setup.py /app/
RUN pip install --no-cache-dir -e .

# Create necessary directories
RUN mkdir -p /app/data /app/logs /app/health \
    && chown -R appuser:appuser /app \
    && chmod 755 /app /app/data /app/logs /app/health

# Copy application files
COPY --chown=appuser:appuser . .

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Switch to non-root user
USER appuser

# Add PATH for user-installed packages
ENV PATH="/home/appuser/.local/bin:${PATH}"

# Create volumes for data persistence
VOLUME /app/data
VOLUME /app/logs

# Set entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]

# Add healthcheck - using dedicated script for better diagnostics
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /app/scripts/health.sh --mode docker
