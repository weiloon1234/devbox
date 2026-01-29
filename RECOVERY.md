# RECOVERY.md

## Goal

Recover a fully working dev environment on a **fresh macOS** in under **10 minutes**.

---

## Requirements

- macOS
- Internet access
- GitHub / Git access
- SSH private keys available
- Docker Desktop installer

---

## Step-by-step Recovery

### 1. Install system tools (5 minutes)

- Install Docker Desktop
- Install mkcert
- (Optional) install dnsmasq for `.test` wildcard

---

### 2. Clone devbox (1 minute)

```bash
git clone <your-devbox-repo>
cd devbox
```

---

### 3. Restore SSH public keys (1 minute)

Copy your public keys into:

```text
devbox/keys/
  personal_id_ed25519.pub
  private_id_ed25519.pub
```

---

### 4. Install helper commands (1 minute)

```bash
./scripts/install
source ~/.zshrc
```

---

### 5. Bootstrap infrastructure (2 minutes)

```bash
devbox-bootstrap
```

This will:

- Build workspace images
- Start Traefik
- Start shared databases

---

### 6. Recreate workspaces (optional)

```bash
devbox-ws-new
```

Each workspace starts empty by design.

---

## Total Time

~8–10 minutes on a normal connection.

---

## Philosophy

Nothing is precious.
Everything is rebuildable.

If recovery takes longer than 10 minutes, the design failed.
