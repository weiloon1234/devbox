# ARCHITECTURE.md

## Overview

devbox is a **workspace-oriented, container-first development environment**.

Infrastructure is versioned.  
State is disposable.

---

## High-level diagram

```code
Browser (Safari)
   |
   | HTTPS (*.test)
   v
Traefik (TLS termination)
   |
   v
Workspace Nginx (per workspace)
   |
   +--> PHP-FPM 8.1
   +--> PHP-FPM 8.2
   +--> PHP-FPM 8.3
   +--> PHP-FPM 8.4
   +--> PHP-FPM 8.5
   |
   +--> Proxy (Go / Rust / Node)
   |
   +--> Static / SPA files
```

---

## Core components

### 1. Proxy (Traefik)

- Terminates HTTPS
- Routes `*.{workspace}.test` to correct workspace nginx
- Uses mkcert-generated local certs

### 2. Workspace Runtime

Each workspace consists of:

- `ws-<name>`: tools + SSH + AI execution
- `ws-<name>-nginx`: HTTP routing
- `ws-<name>-phpXX`: PHP-FPM runtimes

### 3. Shared Databases

- MySQL
- PostgreSQL
- Redis

All on a shared Docker network (`devbox`).

---

## Workspace Lifecycle

1. `devbox-ws-new`
2. Docker volumes created
3. SSH seeded
4. Containers started
5. Workspace ready

Destroying the volume deletes all code.

---

## Project Routing Flow

### PHP / Laravel

- `.php-version` determines PHP runtime
- Nginx routes to correct PHP-FPM container

### Go / Rust / Node

- App binds to `0.0.0.0:<port>`
- Nginx reverse proxies to workspace container

### Static / SPA

- Nginx serves files directly

---

## Networking Model

- `proxy` network: external entry (Traefik)
- `devbox` network: internal communication
- No container exposes ports publicly except SSH (localhost only)

---

## Design Principles

- Deterministic
- Disposable
- Reproducible
- AI-safe
- Host-clean
