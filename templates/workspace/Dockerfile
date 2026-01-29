FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# -------------------------
# Base system
# -------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    unzip \
    zip \
    build-essential \
    pkg-config \
    openssh-server \
    python3 \
    python3-pip \
    python3-venv \
 && rm -rf /var/lib/apt/lists/*

# -------------------------
# Node.js (LTS)
# -------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get update \
 && apt-get install -y nodejs \
 && npm install -g npm@latest \
 && rm -rf /var/lib/apt/lists/*

# -------------------------
# Go (latest stable)
# -------------------------
RUN GO_VERSION="$(curl -s https://go.dev/VERSION?m=text)" \
 && wget -q https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz \
 && tar -C /usr/local -xzf ${GO_VERSION}.linux-amd64.tar.gz \
 && rm ${GO_VERSION}.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# -------------------------
# Rust (latest stable)
# -------------------------
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# -------------------------
# SSH setup
# -------------------------
RUN mkdir -p /run/sshd \
 && sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

WORKDIR /workspace