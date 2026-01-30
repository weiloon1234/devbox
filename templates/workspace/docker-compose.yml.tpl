services:
  ws-__WS_NAME__:
    image: devbox-workspace:latest
    container_name: ws-__WS_NAME__
    restart: unless-stopped
    working_dir: /workspace

    entrypoint: ["/bin/bash", "/bootstrap.sh"]
    command:
      - -lc
      - |
        set -e
        mkdir -p /run/sshd
        /usr/sbin/sshd -D -e

    ports:
      - "127.0.0.1:__SSH_PORT__:22"

    volumes:
      - __CODE_VOLUME__:/workspace
      - ../../keys/__PUBKEY_FILE__:/seed/authorized_keys:ro
      - ../../keys/__PRIVKEY_FILE__:/seed/id_key:ro
      - ./bootstrap.sh:/bootstrap.sh:ro

    networks:
      - proxy
      - devbox

  ws-__WS_NAME__-php81:
    image: devbox-php:8.1
    container_name: ws-__WS_NAME__-php81
    restart: unless-stopped
    volumes:
      - __CODE_VOLUME__:/workspace
    networks:
      - devbox

  ws-__WS_NAME__-php83:
    image: devbox-php:8.3
    container_name: ws-__WS_NAME__-php83
    restart: unless-stopped
    volumes:
      - __CODE_VOLUME__:/workspace
    networks:
      - devbox

  ws-__WS_NAME__-php82:
    image: devbox-php:8.2
    container_name: ws-__WS_NAME__-php82
    restart: unless-stopped
    volumes:
      - __CODE_VOLUME__:/workspace
    networks:
      - devbox

  ws-__WS_NAME__-php84:
    image: devbox-php:8.4
    container_name: ws-__WS_NAME__-php84
    restart: unless-stopped
    volumes:
      - __CODE_VOLUME__:/workspace
    networks:
      - devbox

  ws-__WS_NAME__-php85:
    image: devbox-php:8.5
    container_name: ws-__WS_NAME__-php85
    restart: unless-stopped
    volumes:
      - __CODE_VOLUME__:/workspace
    networks:
      - devbox

  ws-__WS_NAME__-nginx:
    image: nginx:alpine
    container_name: ws-__WS_NAME__-nginx
    restart: unless-stopped
    depends_on:
      - ws-__WS_NAME__-php81
      - ws-__WS_NAME__-php83
      - ws-__WS_NAME__-php84
    volumes:
      - __CODE_VOLUME__:/workspace:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - proxy
      - devbox
    labels:
      - traefik.enable=true
      - traefik.http.routers.ws-__WS_NAME__.rule=HostRegexp(`{proj:[a-z0-9-]+}.__WS_NAME__.test`)
      - traefik.http.routers.ws-__WS_NAME__.entrypoints=websecure
      - traefik.http.routers.ws-__WS_NAME__.tls=true
      - traefik.http.services.ws-__WS_NAME__.loadbalancer.server.port=80

volumes:
  __CODE_VOLUME__:
    name: __CODE_VOLUME__

networks:
  proxy:
    external: true
    name: proxy
  devbox:
    external: true
    name: devbox