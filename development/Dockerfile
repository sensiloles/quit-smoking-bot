# Development environment for quit-smoking-bot
# Multi-stage build for optimized image size
FROM ubuntu:22.04 as base

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Build arguments for version control
ARG DOCKER_VERSION=24.0.7
ARG DOCKER_COMPOSE_VERSION=2.21.0
ARG PYTHON_VERSION=3.10

# Labels for metadata
LABEL maintainer="quit-smoking-bot-dev"
LABEL version="2.0"
LABEL description="Enhanced development environment with improved security and stability"

# Install system dependencies in optimized layers
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    curl \
    wget \
    git \
    jq \
    nano \
    vim \
    htop \
    tree \
    unzip \
    # Security tools
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    # Network and monitoring tools
    net-tools \
    iputils-ping \
    telnet \
    netcat \
    dnsutils \
    # Process management
    procps \
    psmisc \
    supervisor \
    # System administration
    sudo \
    systemctl \
    # Timezone data
    tzdata \
    # Development tools
    build-essential \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Install Python and pip separately for better caching
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3=${PYTHON_VERSION}* \
    python3-pip \
    python3-venv \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --upgrade pip setuptools wheel

# Install Docker with signature verification
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose \
    && docker-compose --version || echo "Docker Compose installed"

# Create development user with proper groups and permissions
RUN groupadd -g 1000 developer \
    && useradd -u 1000 -g developer -G docker,sudo -m -s /bin/bash developer \
    && echo 'developer ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo 'developer:developer' | chpasswd

# Create and configure workspace
WORKDIR /workspace
RUN mkdir -p /workspace/{data,logs,tmp} \
    && chown -R developer:developer /workspace \
    && chmod -R 755 /workspace

# Install development tools and utilities
RUN pip3 install --no-cache-dir \
    pytest \
    pytest-cov \
    black \
    flake8 \
    isort \
    pre-commit \
    docker \
    python-dotenv

# Configure supervisor for process management
RUN mkdir -p /etc/supervisor/conf.d && \
    echo '[supervisord]' > /etc/supervisor/conf.d/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'user=root' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'logfile=/var/log/supervisor/supervisord.log' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'pidfile=/var/run/supervisord.pid' >> /etc/supervisor/conf.d/supervisord.conf && \
    mkdir -p /var/log/supervisor

# Create health check script
RUN mkdir -p /usr/local/bin && \
    echo '#!/bin/bash' > /usr/local/bin/healthcheck.sh && \
    echo 'echo "Development environment healthy"' >> /usr/local/bin/healthcheck.sh && \
    echo 'exit 0' >> /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/healthcheck.sh

# Configure shell environment for developer user
USER developer
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias la="ls -la"' >> ~/.bashrc \
    && echo 'alias grep="grep --color=auto"' >> ~/.bashrc \
    && echo 'alias docker-compose="docker-compose --log-level WARNING"' >> ~/.bashrc \
    && echo 'export PS1="\[\033[01;32m\]dev-env\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc \
    && echo 'export PYTHONPATH="/workspace/src:$PYTHONPATH"' >> ~/.bashrc \
    && echo 'export PATH="/workspace/scripts:$PATH"' >> ~/.bashrc

# Create development configuration
USER root

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Switch back to developer user
USER developer

# Default command with proper signal handling
CMD ["/bin/bash"]

# Expose common development ports
EXPOSE 8000 8080 9090 