#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Linker              |-/ /--|#
#|/ /---+---------------------+/ /---|#
#
# Places every manifest entry into $HOME, then reports what changed.
#
# Sourced by install/steps/05-config.sh and by install/link.sh. Requires
# install/utils.sh (logging) and install/lib/manifest.sh (the entry lists) to
# have been sourced first, and REPO_DIR to be set.
#
# Everything here is idempotent: a destination that is already the right
# symlink is left alone, so a second run reports only "unchanged".
#
# Caller-tunable:
#   SYNAPSE_DRY_RUN=1    describe the actions, touch nothing
#   SYNAPSE_BACKUP_DIR   where displaced files go (default: timestamped)

: "${SYNAPSE_DRY_RUN:=0}"
: "${SYNAPSE_BACKUP_DIR:=$HOME/.config.backup-$(date +%Y%m%d_%H%M%S)-Synapse}"

SYNAPSE_N_LINKED=0      # created a symlink where nothing was
SYNAPSE_N_REPOINTED=0   # symlink existed but aimed elsewhere
SYNAPSE_N_MIGRATED=0    # a real file/dir was displaced to make room
SYNAPSE_N_UNCHANGED=0   # already correct
SYNAPSE_N_COPIED=0      # copy-once entry placed
SYNAPSE_N_SKIPPED=0     # copy-once entry left alone, or source missing
SYNAPSE_N_FAILED=0
declare -a SYNAPSE_DRIFTED=()   # migrated files whose content differed from the repo

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Internals                                                             │
# ╰───────────────────────────────────────────────────────────────────────╯

# Path as the user thinks of it, for log lines.
_syn_pretty() { echo "~${1#"$HOME"}"; }

_syn_dry() { [[ "$SYNAPSE_DRY_RUN" == "1" ]]; }

# True when git considers the path ignored, so the recursive link form never
# picks up runtime droppings (.zsh_history, .zcompdump) that happen to sit in
# the repo working tree.
_syn_ignored() {
    command -v git &>/dev/null || return 1
    git -C "$REPO_DIR" check-ignore -q -- "$1" 2>/dev/null
}

# Does the destination already carry the same bytes as the repo version?
# Used only to tell the user which displaced files held real customization.
_syn_same_content() {
    local src="$1" dest="$2"
    if [[ -d "$src" ]]; then
        command -v diff &>/dev/null || return 1
        diff -rq "$src" "$dest" &>/dev/null
    else
        cmp -s "$src" "$dest"
    fi
}

# Move a real file/dir out of the way, mirroring its path under the backup dir.
_syn_displace() {
    local dest="$1" src="$2"
    local rel="${dest#"$HOME"/}"
    local dest_p; dest_p="$(_syn_pretty "$dest")"

    local differed=0
    _syn_same_content "$src" "$dest" || differed=1

    if _syn_dry; then
        if [[ $differed -eq 1 ]]; then
            log_warn "would back up (modified) $dest_p"
        else
            log_info "would back up $dest_p"
        fi
    else
        mkdir -p "$SYNAPSE_BACKUP_DIR/$(dirname "$rel")"
        if ! mv "$dest" "$SYNAPSE_BACKUP_DIR/$rel"; then
            log_error "could not back up $dest_p"
            SYNAPSE_N_FAILED=$((SYNAPSE_N_FAILED + 1))
            return 1
        fi
    fi

    SYNAPSE_N_MIGRATED=$((SYNAPSE_N_MIGRATED + 1))
    if [[ $differed -eq 1 ]]; then
        SYNAPSE_DRIFTED+=("$rel")
    fi
    return 0
}

# The one place a symlink is actually created. Handles all four starting
# states: correct link, wrong link, real file, nothing.
_syn_place() {
    local src="$1" dest="$2"
    local src_p dest_p
    src_p="${src#"$REPO_DIR"/}"
    dest_p="$(_syn_pretty "$dest")"

    if [[ ! -e "$src" ]]; then
        log_warn "missing in repo, skipped: $src_p"
        SYNAPSE_N_SKIPPED=$((SYNAPSE_N_SKIPPED + 1))
        return 0
    fi

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink -f "$dest" 2>/dev/null)" == "$(readlink -f "$src")" ]]; then
            SYNAPSE_N_UNCHANGED=$((SYNAPSE_N_UNCHANGED + 1))
            return 0
        fi
        if _syn_dry; then
            log_info "would repoint $dest_p → $src_p"
        else
            ln -sfn "$src" "$dest" || {
                log_error "could not repoint $dest_p"
                SYNAPSE_N_FAILED=$((SYNAPSE_N_FAILED + 1))
                return 0
            }
            log_ok "repointed $dest_p"
        fi
        SYNAPSE_N_REPOINTED=$((SYNAPSE_N_REPOINTED + 1))
        return 0
    fi

    if [[ -e "$dest" ]]; then
        _syn_displace "$dest" "$src" || return 0
    fi

    if _syn_dry; then
        log_info "would link $dest_p → $src_p"
    else
        mkdir -p "$(dirname "$dest")"
        ln -sfn "$src" "$dest" || {
            log_error "could not link $dest_p"
            SYNAPSE_N_FAILED=$((SYNAPSE_N_FAILED + 1))
            return 0
        }
    fi
    SYNAPSE_N_LINKED=$((SYNAPSE_N_LINKED + 1))
    return 0
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Public API — arguments are repo-relative / $HOME-relative             │
# ╰───────────────────────────────────────────────────────────────────────╯

synapse_link_dir() {
    _syn_place "$REPO_DIR/${1%/}" "$HOME/${2%/}"
}

# A source ending in "/" links every file beneath it, recursively, recreating
# the subdirectory layout as real directories so runtime files can join them.
synapse_link_file() {
    local src="$1" dest="$2"

    if [[ "$src" != */ ]]; then
        _syn_place "$REPO_DIR/$src" "$HOME/$dest"
        return 0
    fi

    local src_root="$REPO_DIR/${src%/}" dest_root="$HOME/${dest%/}"
    if [[ ! -d "$src_root" ]]; then
        log_warn "missing in repo, skipped: ${src%/}"
        SYNAPSE_N_SKIPPED=$((SYNAPSE_N_SKIPPED + 1))
        return 0
    fi

    local f rel excl skip
    while IFS= read -r f; do
        rel="${f#"$src_root"/}"
        if _syn_ignored "$f"; then
            continue
        fi

        skip=0
        for excl in "${SYNAPSE_LINK_EXCLUDE[@]}"; do
            if [[ "${src%/}/$rel" == "$excl" ]]; then skip=1; break; fi
        done
        if [[ $skip -eq 1 ]]; then
            continue
        fi

        _syn_place "$f" "$dest_root/$rel"
    done < <(find "$src_root" \( -type f -o -type l \) | sort)
    return 0
}

synapse_copy_once() {
    local src="$REPO_DIR/$1" dest="$HOME/$2"
    local dest_p; dest_p="$(_syn_pretty "$dest")"

    if [[ ! -e "$src" ]]; then
        log_warn "missing in repo, skipped: $1"
        SYNAPSE_N_SKIPPED=$((SYNAPSE_N_SKIPPED + 1))
        return 0
    fi
    # -e is false for a dangling symlink, so test -L too and leave it alone.
    if [[ -e "$dest" || -L "$dest" ]]; then
        SYNAPSE_N_SKIPPED=$((SYNAPSE_N_SKIPPED + 1))
        return 0
    fi

    if _syn_dry; then
        log_info "would copy $dest_p (user-owned from here on)"
    else
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest" || {
            log_error "could not copy $dest_p"
            SYNAPSE_N_FAILED=$((SYNAPSE_N_FAILED + 1))
            return 0
        }
    fi
    SYNAPSE_N_COPIED=$((SYNAPSE_N_COPIED + 1))
    return 0
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Manifest walk                                                         │
# ╰───────────────────────────────────────────────────────────────────────╯

synapse_run_manifest() {
    local entry

    for entry in "${SYNAPSE_LINK_DIRS[@]}";  do synapse_link_dir  "${entry%%|*}" "${entry#*|}"; done
    for entry in "${SYNAPSE_LINK_FILES[@]}"; do synapse_link_file "${entry%%|*}" "${entry#*|}"; done
    for entry in "${SYNAPSE_COPY_ONCE[@]}";  do synapse_copy_once "${entry%%|*}" "${entry#*|}"; done

    for entry in "${SYNAPSE_USER_DIRS[@]}"; do
        _syn_dry || mkdir -p "$HOME/$entry"
    done

    # Wallpapers are user media: seeded, never linked, so deleting one doesn't
    # dirty the repo.
    if [[ -d "$REPO_DIR/$SYNAPSE_WALLPAPER_SRC" ]] && ! _syn_dry; then
        cp -r -n "$REPO_DIR/$SYNAPSE_WALLPAPER_SRC/." "$HOME/$SYNAPSE_WALLPAPER_DEST/" 2>/dev/null || true
    fi

    # Selects the active starship theme — only created when absent, so the
    # user's choice survives a reinstall.
    local sl="$HOME/$SYNAPSE_STARSHIP_LINK"
    if [[ ! -e "$sl" && ! -L "$sl" ]]; then
        if _syn_dry; then
            log_info "would link $(_syn_pretty "$sl") → $SYNAPSE_STARSHIP_TARGET"
        else
            mkdir -p "$(dirname "$sl")"
            ln -sfn "$SYNAPSE_STARSHIP_TARGET" "$sl" && \
                SYNAPSE_N_LINKED=$((SYNAPSE_N_LINKED + 1))
        fi
    fi

    return 0
}

synapse_link_summary() {
    echo ""
    if _syn_dry; then
        log_info "Dry run — nothing was changed."
    fi

    log_ok "${SYNAPSE_N_LINKED} linked · ${SYNAPSE_N_REPOINTED} repointed · ${SYNAPSE_N_UNCHANGED} already correct"
    if [[ $SYNAPSE_N_COPIED -gt 0 ]]; then
        log_info "${SYNAPSE_N_COPIED} user-owned file(s) copied"
    fi
    if [[ $SYNAPSE_N_SKIPPED -gt 0 ]]; then
        log_info "${SYNAPSE_N_SKIPPED} skipped (already present or not bundled)"
    fi

    if [[ $SYNAPSE_N_MIGRATED -gt 0 ]]; then
        echo ""
        log_warn "${SYNAPSE_N_MIGRATED} existing file(s) replaced by symlinks."
        log_info "Backed up to: $(_syn_pretty "$SYNAPSE_BACKUP_DIR")"
    fi

    # The only part of the backup worth a human's attention: files that did not
    # match the repo, i.e. real local customization.
    if [[ ${#SYNAPSE_DRIFTED[@]} -gt 0 ]]; then
        echo ""
        log_warn "${#SYNAPSE_DRIFTED[@]} of those differed from the repo version:"
        local d
        for d in "${SYNAPSE_DRIFTED[@]}"; do
            log_info "~/$d"
        done
        echo ""
        log_info "Re-apply anything you want to keep, then commit it to the repo —"
        log_info "edits to the linked files now live in your checkout."
    fi

    if [[ $SYNAPSE_N_FAILED -gt 0 ]]; then
        echo ""
        log_error "${SYNAPSE_N_FAILED} operation(s) failed — see above."
        return 1
    fi
    return 0
}
