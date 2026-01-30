FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git openssh-server sudo \
    vim less unzip zip build-essential \
    iproute2 net-tools procps tzdata \
  && rm -rf /var/lib/apt/lists/*

# Create SSH runtime dir
RUN mkdir -p /run/sshd

# Create a stable dev user (UID 1000). If UID 1000 already exists, reuse it.
RUN set -eux; \
  if ! getent passwd 1000 >/dev/null; then \
    useradd -m -u 1000 -s /bin/bash ubuntu; \
  fi; \
  usermod -aG sudo ubuntu; \
  echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
  chmod 0440 /etc/sudoers.d/ubuntu; \
  \
  # IMPORTANT: unlock the account (even though password auth will be disabled)
  echo "ubuntu:devbox" | chpasswd

# Harden sshd defaults (bootstrap will enforce again)
RUN sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config \
 && grep -q '^PubkeyAuthentication' /etc/ssh/sshd_config || echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

WORKDIR /workspace