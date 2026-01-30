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
    sudo \
 && rm -rf /var/lib/apt/lists/*

# -------------------------
# Create workspace user (uid 1000) - Ubuntu 24.04 friendly
# -------------------------
RUN set -eux; \
    # create group ubuntu@1000 if missing
    if ! getent group 1000 >/dev/null; then groupadd -g 1000 ubuntu; fi; \
    # create user ubuntu@1000 if missing
    if ! id -u ubuntu >/dev/null 2>&1; then useradd -m -u 1000 -g 1000 -s /bin/bash ubuntu; fi; \
    # ensure not locked (pubkey auth must allow user)
    passwd -d ubuntu || true; \
    usermod -U ubuntu || true; \
    # passwordless sudo (optional but convenient)
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    chmod 0440 /etc/sudoers.d/ubuntu; \
    mkdir -p /home/ubuntu/.ssh; \
    chown -R ubuntu:ubuntu /home/ubuntu

# -------------------------
# SSHD config (drop-in; avoid sed on main config)
# -------------------------
RUN mkdir -p /run/sshd /etc/ssh/sshd_config.d
COPY sshd_config.d/10-devbox.conf /etc/ssh/sshd_config.d/10-devbox.conf

# -------------------------
# Node.js (LTS)
# -------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get update \
 && apt-get install -y nodejs \
 && npm install -g npm@latest \
 && rm -rf /var/lib/apt/lists/*

# -------------------------
# Go (latest stable, correct arch)
# -------------------------
RUN set -eux; \
    GO_VERSION="$(curl -s https://go.dev/VERSION?m=text)"; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      amd64) GO_ARCH="amd64" ;; \
      arm64) GO_ARCH="arm64" ;; \
      *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
    esac; \
    wget -q "https://go.dev/dl/${GO_VERSION}.linux-${GO_ARCH}.tar.gz"; \
    tar -C /usr/local -xzf "${GO_VERSION}.linux-${GO_ARCH}.tar.gz"; \
    rm "${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

ENV PATH="/usr/local/go/bin:${PATH}"

# -------------------------
# Rust (latest stable)
# -------------------------
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /workspace