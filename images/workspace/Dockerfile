FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------
# Base system packages
# -----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    openssh-server \
    sudo \
    vim \
    less \
    unzip \
    zip \
    build-essential \
    iproute2 \
    net-tools \
    procps \
    tzdata \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Workspace + SSH runtime dirs
# (ownership fixed at runtime)
# -----------------------------
RUN mkdir -p /workspace /run/sshd

WORKDIR /workspace

EXPOSE 22