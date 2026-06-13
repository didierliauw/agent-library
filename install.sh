#!/usr/bin/env bash
# install.sh — symlink agent-library skills into a host's skills directory.
#
# Why this exists: for hosts WITHOUT a native plugin marketplace (Codex,
# Gemini, Cursor). Claude Code and Copilot CLI have native marketplaces — see
# README — but are included here as a manual fallback.
#
# Usage:
#   ./install.sh <host>              install skills for <host>
#   ./install.sh <host> --dry-run    show what would be linked, change nothing
#   ./install.sh --uninstall <host>  remove links this script created
#   ./install.sh --help
# Hosts: codex gemini cursor claude copilot
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
SKILLS_DIR="$SCRIPT_DIR/skills"

usage() {
  cat >&2 <<'EOF'
Usage:
  install.sh <host>              install skills for <host>
  install.sh <host> --dry-run    show what would be linked, change nothing
  install.sh --uninstall <host>  remove links this script created
  install.sh --help
Hosts: codex gemini cursor claude copilot
EOF
}

target_dir() {
  case "$1" in
    codex|gemini) printf '%s\n' "$HOME/.agents/skills" ;;
    cursor)       printf '%s\n' "$HOME/.cursor/skills" ;;
    claude)       printf '%s\n' "$HOME/.claude/skills" ;;
    copilot)      printf '%s\n' "$HOME/.copilot/skills" ;;
    *) return 1 ;;
  esac
}

DRY_RUN=0; UNINSTALL=0; HOST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --help|-h)   usage; exit 0 ;;
    -*)          echo "unknown option: $1" >&2; usage; exit 2 ;;
    *)           HOST="$1"; shift ;;
  esac
done

if [[ -z "$HOST" ]]; then
  if [[ -t 0 ]]; then
    printf 'Which host? (codex gemini cursor claude copilot): ' >&2
    read -r HOST </dev/tty || { echo "cancelled" >&2; exit 1; }
  else
    echo "no host given" >&2; usage; exit 2
  fi
fi

TARGET=$(target_dir "$HOST") || { echo "unknown host: $HOST" >&2; usage; exit 2; }
[[ -d "$SKILLS_DIR" ]] || { echo "skills dir not found: $SKILLS_DIR" >&2; exit 1; }

shopt -s nullglob
SKILLS=("$SKILLS_DIR"/*/)
shopt -u nullglob
[[ ${#SKILLS[@]} -gt 0 ]] || { echo "no skills under $SKILLS_DIR" >&2; exit 1; }

if [[ "$UNINSTALL" -eq 1 ]]; then
  for s in "${SKILLS[@]}"; do
    name=$(basename "$s"); link="$TARGET/$name"
    if [[ -L "$link" ]]; then
      # We always create links with an absolute target (see install loop), so
      # readlink returns an absolute path and this prefix check is reliable.
      dest=$(readlink "$link")
      case "$dest" in
        "$SCRIPT_DIR"/*)
          if [[ "$DRY_RUN" -eq 1 ]]; then echo "would remove $link"; else rm "$link"; echo "removed $link"; fi ;;
        *) echo "skip $link (not ours: -> $dest)" ;;
      esac
    fi
  done
  exit 0
fi

[[ "$DRY_RUN" -eq 1 ]] || mkdir -p "$TARGET"
for s in "${SKILLS[@]}"; do
  name=$(basename "$s"); src="$SKILLS_DIR/$name"; link="$TARGET/$name"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would link: $link -> $src"
  else
    ln -sfn "$src" "$link"
    echo "linked: $link -> $src"
  fi
done
