# SECURITY.md

## Threat Model

devbox is designed under the assumption that:

- AI agents **may be powerful**
- AI agents **may make mistakes**
- AI agents **must never access host OS state**

### In-scope threats

- Accidental deletion or modification of application code
- AI installing malicious dependencies
- AI misconfiguring services
- AI attempting filesystem traversal

### Out-of-scope threats

- Compromised Docker Desktop daemon
- Malicious macOS kernel / root compromise
- Physical access to developer machine

---

## Security Boundaries

### macOS (Trusted Boundary)

- No source code lives on macOS
- No runtime services installed (no Valet, no PHP, no DB)
- SSH private keys remain on host only
- Flutter / Android / Xcode SDKs remain on host only

### Docker Containers (Untrusted / Disposable)

- All code lives inside Docker named volumes
- AI agents operate **only inside containers**
- Containers are resettable at any time
- No bind mounts into macOS filesystem

---

## AI Containment Strategy

### What AI is allowed to do

- Edit code inside workspace volumes
- Run git pull / commit / push
- Install dependencies (npm, composer, go mod, cargo)
- Run application servers inside containers

### What AI cannot do

- Access macOS filesystem
- Access SSH private keys
- Install host-level services
- Modify devbox infrastructure repo (unless explicitly allowed)

### Hard barriers

- No writable bind mounts to macOS
- Workspace volumes only mounted inside containers
- SSH access limited to localhost
- No Docker socket mounted into containers

---

## SSH & Key Management

- Only **public keys** are injected into containers
- Public keys are local-only and gitignored
- Private keys never leave macOS
- If required public keys are missing, bootstrap fails

---

## TLS & Networking

- TLS certificates generated via mkcert (local trust)
- Certificates are local-only and gitignored
- Traefik handles TLS termination
- Workspace nginx only listens internally

---

## Reset as a Security Control

`devbox reset`:

- Stops all containers
- Deletes all workspace volumes
- Deletes shared DB volumes

Reset is treated as a **security feature**, not a failure.

---

## Design Philosophy

> Assume AI will eventually make a mistake.  
> Make that mistake harmless.

devbox enforces this by design.
