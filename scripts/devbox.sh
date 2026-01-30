#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────
red()  { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

usage() {
  bold "devbox — portable Docker development environment"
  echo ""
  bold "Core commands:"
  echo "  devbox up [--no-mount]       Start infrastructure + workspaces"
  echo "  devbox down                  Stop everything"
  echo "  devbox bootstrap             Build images + start infra"
  echo "  devbox install [--dry-run]   Install devbox + dependencies"
  echo "  devbox refresh [flags]       Rebuild + restart everything"
  echo "  devbox fresh [flags]         Nuclear rebuild (stop, nuke, rebuild)"
  echo "  devbox reset                 Delete all volumes (danger)"
  echo "  devbox doctor                Health check"
  echo ""
  bold "TLS:"
  echo "  devbox tls status            Show TLS certificate status"
  echo ""
  bold "Workspace commands:"
  echo "  devbox workspace new         Create a new workspace"
  echo "  devbox workspace list        List workspaces + status"
  echo "  devbox workspace ssh <name>  SSH into a workspace"
  echo "  devbox workspace php <ws> <project> <cmd...>"
  echo "                               Run PHP command in project"
  echo "  devbox workspace delete <name>"
  echo "                               Delete a workspace"
  echo "  devbox workspace add-project Interactive project setup"
  echo "  devbox workspace mount <name>"
  echo "                               SSHFS mount a workspace"
  echo "  devbox workspace umount <name>"
  echo "                               Unmount a workspace"
  echo "  devbox workspace mount-all   Mount all workspaces"
  echo "  devbox workspace umount-all  Unmount all workspaces"
  echo "  devbox workspace nginx-reload <name>"
  echo "                               Reload nginx in a workspace"
  echo ""
  bold "Database commands:"
  echo "  devbox db mysql              Open MySQL CLI"
  echo "  devbox db psql               Open PostgreSQL CLI"
  echo "  devbox db redis              Open Redis CLI"
  echo ""
  bold "Aliases:"
  echo "  ws → workspace,  ls → list,  rm → delete"
}

# ── Main dispatch ────────────────────────────────────────────────────
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  # ── Core commands (no subgroup) ──
  up|down|bootstrap|install|refresh|fresh|reset|doctor)
    exec "$SCRIPTS_DIR/core/$CMD.sh" "$@"
    ;;

  # ── TLS group ──
  tls)
    SUB="${1:-}"
    shift 2>/dev/null || true
    case "$SUB" in
      status) exec "$SCRIPTS_DIR/core/tls-status.sh" "$@" ;;
      *)
        red "Unknown tls command: $SUB"
        echo "Usage: devbox tls status"
        exit 1
        ;;
    esac
    ;;

  # ── Workspace group ──
  workspace|ws)
    SUB="${1:-}"
    shift 2>/dev/null || true

    # Aliases
    case "$SUB" in
      ls) SUB="list" ;;
      rm) SUB="delete" ;;
    esac

    case "$SUB" in
      new|list|ssh|php|delete|add-project|mount|umount|mount-all|umount-all|nginx-reload)
        exec "$SCRIPTS_DIR/workspace/$SUB.sh" "$@"
        ;;
      "")
        red "Missing workspace subcommand."
        echo "Usage: devbox workspace <command>"
        echo "Commands: new, list, ssh, php, delete, add-project, mount, umount, mount-all, umount-all, nginx-reload"
        exit 1
        ;;
      *)
        red "Unknown workspace command: $SUB"
        echo "Usage: devbox workspace <command>"
        echo "Commands: new, list, ssh, php, delete, add-project, mount, umount, mount-all, umount-all, nginx-reload"
        exit 1
        ;;
    esac
    ;;

  # ── Database group ──
  db)
    SUB="${1:-}"
    shift 2>/dev/null || true
    case "$SUB" in
      mysql|psql|redis)
        exec "$SCRIPTS_DIR/db/$SUB.sh" "$@"
        ;;
      "")
        red "Missing db subcommand."
        echo "Usage: devbox db <mysql|psql|redis>"
        exit 1
        ;;
      *)
        red "Unknown db command: $SUB"
        echo "Usage: devbox db <mysql|psql|redis>"
        exit 1
        ;;
    esac
    ;;

  # ── Help ──
  help|-h|--help)
    usage
    ;;

  # ── Unknown ──
  *)
    red "Unknown command: $CMD"
    echo "Run 'devbox help' for usage."
    exit 1
    ;;
esac
