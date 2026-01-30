# devbox

**Portable, resettable, AI‑safe Docker development environment for macOS.**

This repository contains **ONLY infrastructure, templates, and bootstrap logic**.  
No application source code lives here.

---

## Why devbox exists

devbox is designed for developers who:

- Want a **clean macOS** (no Homebrew services, no Valet pollution)
- Want **all source code isolated inside Docker volumes**
- Want **AI agents** to safely:
  - modify code
  - run git pull / commit / push
  - install dependencies
- Want to **format macOS and recover in minutes**
- Need **multiple isolated workspaces** (personal, client, private, etc.)
- Need **multiple PHP versions per project** (like Valet, but deterministic)

---

## Core guarantees

- macOS filesystem remains clean
- All application code lives inside Docker volumes
- Workspaces are disposable by design
- Reset = full clean slate
- Infrastructure is portable via git
- AI cannot damage host OS or host files

---

## What this repo is NOT

- ❌ Not an application repo
- ❌ Not a place to store secrets
- ❌ Not a place to store SSH private keys
- ❌ Not a place to store TLS certs
- ❌ Not a place to store workspace state

---

## High‑level architecture

```code
macOS
│
├─ devbox repo (infra only, git)
│
├─ Docker
│   ├─ proxy (Traefik, HTTPS)
│   ├─ shared db (MySQL / Postgres / Redis)
│   ├─ workspace runtime
│   │   ├─ ws-<name>          (tools + SSH)
│   │   ├─ ws-<name>-nginx    (HTTP routing)
│   │   ├─ ws-<name>-php81
│   │   ├─ ws-<name>-php83
│   │   └─ ws-<name>-php84
│
└─ Docker volumes
    ├─ dev_ws_<name>_code     ← ALL source code
    ├─ devbox_mysql
    ├─ devbox_pg
    └─ devbox_redis
```

---

## Repo structure

```code
devbox/
├─ README.md
├─ .gitignore
├─ keys/                         # LOCAL ONLY (gitignored)
│  └─ <workspace>_id_ed25519.pub
├─ proxy/                        # HTTPS reverse proxy (Traefik)
│  ├─ docker-compose.yml
│  └─ certs-config/tls.yml
├─ db/                           # Shared DB stack
│  └─ docker-compose.yml
├─ runtime/
│  └─ php/                       # PHP-FPM image (8.1 / 8.3 / 8.4)
├─ templates/
│  └─ workspace/
│     ├─ Dockerfile             # Workspace tools image
│     ├─ docker-compose.yml.tpl
│     ├─ bootstrap.sh.tpl
│     └─ nginx.conf.tpl
├─ generated/                   # LOCAL ONLY (gitignored)
│  └─ workspaces/
└─ scripts/
   ├─ devbox.sh              # CLI router (single entrypoint)
   ├─ lib/
   │  └─ ws-meta.sh          # shared helper
   ├─ core/
   │  ├─ up.sh, down.sh, bootstrap.sh, install.sh
   │  ├─ refresh.sh, fresh.sh, reset.sh
   │  ├─ doctor.sh, tls-status.sh
   ├─ workspace/
   │  ├─ new.sh, list.sh, ssh.sh, php.sh, delete.sh
   │  ├─ add-project.sh, mount.sh, umount.sh
   │  ├─ mount-all.sh, umount-all.sh, nginx-reload.sh
   └─ db/
      ├─ mysql.sh, psql.sh, redis.sh
```

---

## Workspace model (IMPORTANT)

Workspaces are **generated locally** and never committed.

Each workspace:

- Has one code volume: `dev_ws_<name>_code`
- Has SSH access (localhost only)
- Has its own nginx
- Has PHP 8.1 / 8.3 / 8.4 available
- Shares MySQL / Postgres / Redis
- Can proxy Go / Rust / Node backends

Deleting the volume deletes all code — **by design**.

---

## SSH key policy

- Only **public keys** exist here
- `keys/*.pub` are required and local‑only
- Private keys stay on macOS
- Missing keys cause bootstrap failure

---

## Prerequisites (macOS)

Required:

- Docker Desktop
- mkcert

Recommended:

- dnsmasq wildcard for `.test`
- SSHFS (for IDE access using macOS toolchains)
- Android Studio / Xcode (for Flutter builds)

---

Recommended:

- dnsmasq (wildcard DNS for `*.test`)
  - devbox installer can configure this automatically

---

## Local HTTPS / TLS

devbox automatically generates **local-only TLS certificates** during installation.

- Uses `mkcert`
- Certificates are trusted by Safari
- Files are gitignored
- Regenerated automatically if deleted

No manual TLS setup is required.

---

## First‑time setup (fresh macOS)

```bash
git clone <this-repo>
cd devbox

# restore your public keys
ls keys/*.pub

# install helper commands
./scripts/devbox.sh install
source ~/.zshrc

# build images + start infra
devbox bootstrap
```

Result:

- HTTPS proxy on 80/443
- Shared MySQL / Postgres / Redis
- No workspaces yet

---

## Create a workspace

```bash
devbox workspace new
```

You will be prompted for:

- workspace name
- SSH port
- public key

---

## List / access workspaces

```bash
devbox workspace list
devbox workspace ssh personal
```

---

## Add a project (interactive)

```bash
devbox workspace add-project
```

Supported project types:

- Laravel / PHP
- Static site
- SPA (Vite build)
- Proxy (Go / Rust / Node backend)

This generates nginx stubs and reloads nginx automatically.

---

## PHP version per project

Inside project root:

```code
/workspace/projects/<project>/.php-version
```

Example:

```code
8.1
```

Supported:

- 8.1
- 8.2
- 8.3
- 8.4
- 8.5

Nginx routes to the correct PHP‑FPM container automatically.

---

## Shared database access

From macOS:

```bash
devbox db mysql
devbox db psql
devbox db redis
```

Inside containers:

- MySQL → devbox-mysql:3306 (root:root)
- Postgres → devbox-postgres:5432 (root:root)
- Redis → devbox-redis:6379

---

## Flutter / Dart workflow

- Flutter runs on macOS
- Code lives inside Docker volume
- Workspace mounted via SSHFS
- Android Studio opens mounted path
- Containers do NOT install Flutter/Dart

This avoids SDK conflicts and keeps builds fast.

---

## Reset EVERYTHING (danger)

```bash
devbox reset
```

This:

- Stops all workspaces
- Deletes all workspace code volumes
- Deletes shared DB volumes

After reset: **clean slate**.

---

## Design principles

- Infrastructure is versioned
- State is disposable
- Containers are cattle, not pets
- AI is sandboxed
- macOS stays pristine

---

This repository is intentionally strict.
