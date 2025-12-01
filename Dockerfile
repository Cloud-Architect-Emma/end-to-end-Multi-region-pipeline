# Stage 1: Build Python app
FROM python:3.12-slim AS app

# Use bash with pipefail for all RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt
COPY . .
ENV PATH=/root/.local/bin:$PATH
EXPOSE 5000
CMD ["python", "app.py"]

# Stage 2: Jenkins CI/CD agent
FROM ubuntu:22.04 AS ci-agent

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ARG DOCKER_COMPOSE_VERSION=1.29.2

# Essentials (all pinned versions)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates=20230829~22.04.1 \
    curl=7.81.0-1ubuntu1 \
    gnupg=2.2.35-1ubuntu1 \
    lsb-release=11.1.0ubuntu1 \
    git=1:2.34.1-1ubuntu1 \
    wget=1.21-2ubuntu1 \
    unzip=6.0-26ubuntu1 \
    python3=3.10.13-1ubuntu0.22.04.1 \
    python3-pip=22.3.1-1ubuntu1 \
    build-essential=12.9ubuntu3 \
    apt-transport-https=2.4.5 \
    jq=1.6-2ubuntu0.2 && \
    rm -rf /var/lib/apt/lists/*

# Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli=24.0.2~3-0~ubuntu-jammy && \
    rm -rf /var/lib/apt/lists/*

# Docker Compose v1.x
RUN curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

# Node + NPM (pinned)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs=20.17.0-1nodesource1 && \
    npm install -g npm@11.6.4 && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm -f kubectl

# Syft, Trivy, Gitleaks
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin && \
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin && \
    curl -sL "https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_Linux_x86_64.tar.gz" \
    | tar -xz -C /tmp && mv /tmp/gitleaks /usr/local/bin/gitleaks

# Python tooling (pinned)
RUN pip3 install --no-cache-dir pytest==7.4.0 flake8==6.1.0

# Playwright CLI
RUN npm i -g @microsoft/playwright-cli || true

WORKDIR /workspace
ENV PATH="/workspace/node_modules/.bin:${PATH}"

# Create jenkins user
RUN useradd -m -u 1000 jenkins && mkdir -p /home/jenkins/.ssh && chown -R jenkins:jenkins /home/jenkins

ENTRYPOINT ["/bin/bash"]
