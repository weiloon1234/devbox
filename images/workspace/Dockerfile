FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server sudo ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# Create/normalize workspace user (ubuntu, uid 1000)
# Works whether ubuntu already exists or not
# --------------------------------------------------
RUN set -eux; \
    # Ensure group 1000 exists (name doesn't matter, but keep it clean)
    if ! getent group 1000 >/dev/null; then groupadd -g 1000 ubuntu; fi; \
    \
    # Create ubuntu if missing
    if ! id -u ubuntu >/dev/null 2>&1; then \
      useradd -m -u 1000 -g 1000 -s /bin/bash ubuntu; \
    fi; \
    \
    # Force ubuntu to uid/gid 1000
    if [ "$(id -u ubuntu)" != "1000" ]; then usermod -u 1000 ubuntu; fi; \
    if [ "$(id -g ubuntu)" != "1000" ]; then usermod -g 1000 ubuntu; fi; \
    \
    # Ensure home+shell
    usermod -d /home/ubuntu -m -s /bin/bash ubuntu; \
    \
    # Sudo + NOPASSWD
    usermod -aG sudo ubuntu; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    chmod 0440 /etc/sudoers.d/ubuntu; \
    \
    # IMPORTANT: unlock user for SSH pubkey auth (no password needed)
    passwd -d ubuntu || true; \
    usermod -U ubuntu || true; \
    \
    # Basic perms
    mkdir -p /home/ubuntu/.ssh; \
    chmod 700 /home/ubuntu/.ssh; \
    chown -R ubuntu:ubuntu /home/ubuntu

# --------------------------------------------------
# SSH setup
# --------------------------------------------------
RUN mkdir -p /var/run/sshd \
 && ssh-keygen -A \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?UsePAM.*/UsePAM no/' /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]