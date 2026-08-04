#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Relink              |-/ /--|#
#|/ /---+---------------------+/ /---|#
#
# Re-applies the deploy manifest and nothing else — no packages, no services,
# no sudo. Safe to run any time.
#
# Run this after a `git pull` that added a new config file: existing symlinks
# keep working on their own, but a brand new file needs a link created for it.
# UpdateService invokes this automatically after it pulls.
#
#   ./install/link.sh              apply
#   ./install/link.sh --dry-run    show what would happen, change nothing

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) export SYNAPSE_DRY_RUN=1 ;;
        -h|--help)
            sed -n '7,17p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0 ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1 ;;
    esac
done

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Repo resolution                                                       │
# ╰───────────────────────────────────────────────────────────────────────╯
# This script lives at <repo>/install/link.sh, so its own location is the most
# reliable answer. repo-path is only consulted when that fails.

REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_PATH_FILE="$HOME/.config/Synapse/repo-path"

if [[ ! -d "$REPO_DIR/config" && -f "$REPO_PATH_FILE" ]]; then
    REPO_DIR="$(< "$REPO_PATH_FILE")"
fi

if [[ ! -d "$REPO_DIR/config" ]]; then
    echo "Could not locate the Synapse repo (looked in $REPO_DIR)." >&2
    exit 1
fi

# shellcheck source=install/utils.sh
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=install/lib/manifest.sh
source "$SCRIPT_DIR/lib/manifest.sh"
# shellcheck source=install/lib/link.sh
source "$SCRIPT_DIR/lib/link.sh"

# Keep repo-path honest — running this from a different checkout retargets the
# shell to it, which is exactly what a user moving their repo would expect.
if [[ "$SYNAPSE_DRY_RUN" != "1" ]]; then
    mkdir -p "$(dirname "$REPO_PATH_FILE")"
    printf '%s\n' "$REPO_DIR" > "$REPO_PATH_FILE"
fi

echo ""
log_info "Repo:  $REPO_DIR"
log_info "Target: $HOME"
echo ""

synapse_run_manifest
synapse_link_summary
