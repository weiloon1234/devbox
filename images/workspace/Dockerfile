# ---- Collector stages: extract PHP CLI + runtime shared libs ----
FROM devbox-php:8.1 AS php81-collector
USER root
RUN mkdir -p /collected/php /collected/lib && \
    cp -a /usr/local/. /collected/php/ && \
    { ldd /usr/local/bin/php 2>/dev/null; \
      find /usr/local/lib/php/extensions -name '*.so' -exec ldd {} \; 2>/dev/null; \
    } | grep -oP '/usr/lib/\S+' | sort -u | \
    xargs -I{} cp -L {} /collected/lib/ 2>/dev/null || true

FROM devbox-php:8.2 AS php82-collector
USER root
RUN mkdir -p /collected/php /collected/lib && \
    cp -a /usr/local/. /collected/php/ && \
    { ldd /usr/local/bin/php 2>/dev/null; \
      find /usr/local/lib/php/extensions -name '*.so' -exec ldd {} \; 2>/dev/null; \
    } | grep -oP '/usr/lib/\S+' | sort -u | \
    xargs -I{} cp -L {} /collected/lib/ 2>/dev/null || true

FROM devbox-php:8.3 AS php83-collector
USER root
RUN mkdir -p /collected/php /collected/lib && \
    cp -a /usr/local/. /collected/php/ && \
    { ldd /usr/local/bin/php 2>/dev/null; \
      find /usr/local/lib/php/extensions -name '*.so' -exec ldd {} \; 2>/dev/null; \
    } | grep -oP '/usr/lib/\S+' | sort -u | \
    xargs -I{} cp -L {} /collected/lib/ 2>/dev/null || true

FROM devbox-php:8.4 AS php84-collector
USER root
RUN mkdir -p /collected/php /collected/lib && \
    cp -a /usr/local/. /collected/php/ && \
    { ldd /usr/local/bin/php 2>/dev/null; \
      find /usr/local/lib/php/extensions -name '*.so' -exec ldd {} \; 2>/dev/null; \
    } | grep -oP '/usr/lib/\S+' | sort -u | \
    xargs -I{} cp -L {} /collected/lib/ 2>/dev/null || true

FROM devbox-php:8.5 AS php85-collector
USER root
RUN mkdir -p /collected/php /collected/lib && \
    cp -a /usr/local/. /collected/php/ && \
    { ldd /usr/local/bin/php 2>/dev/null; \
      find /usr/local/lib/php/extensions -name '*.so' -exec ldd {} \; 2>/dev/null; \
    } | grep -oP '/usr/lib/\S+' | sort -u | \
    xargs -I{} cp -L {} /collected/lib/ 2>/dev/null || true

# ---- Main workspace image ----
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server sudo ca-certificates git curl unzip \
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

# --------------------------------------------------
# PHP CLI (all versions, copied from FPM images)
# --------------------------------------------------
COPY --from=php81-collector /collected/php /opt/php/8.1
COPY --from=php81-collector /collected/lib /opt/php/8.1/lib
COPY --from=php82-collector /collected/php /opt/php/8.2
COPY --from=php82-collector /collected/lib /opt/php/8.2/lib
COPY --from=php83-collector /collected/php /opt/php/8.3
COPY --from=php83-collector /collected/lib /opt/php/8.3/lib
COPY --from=php84-collector /collected/php /opt/php/8.4
COPY --from=php84-collector /collected/lib /opt/php/8.4/lib
COPY --from=php85-collector /collected/php /opt/php/8.5
COPY --from=php85-collector /collected/lib /opt/php/8.5/lib

# Versioned PHP commands (php81, php82, php83, php84, php85)
RUN set -e; for v in 8.1 8.2 8.3 8.4 8.5; do \
      short="$(echo "$v" | tr -d .)"; \
      printf '#!/bin/sh\nexport LD_LIBRARY_PATH="/opt/php/%s/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\nexec /opt/php/%s/bin/php "$@"\n' "$v" "$v" \
        > "/usr/local/bin/php${short}"; \
      chmod +x "/usr/local/bin/php${short}"; \
    done

# php wrapper (reads .php-version, default 8.4)
COPY php-wrapper.sh /usr/local/bin/php
RUN chmod +x /usr/local/bin/php

# Composer (installed once, uses default PHP)
RUN LD_LIBRARY_PATH="/opt/php/8.4/lib" /opt/php/8.4/bin/php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');" && \
    LD_LIBRARY_PATH="/opt/php/8.4/lib" /opt/php/8.4/bin/php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm /tmp/composer-setup.php

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
