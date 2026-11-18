#!/usr/bin/env bash
# VERSION (repo root, plain X.Y.Z) is the single source of Synapse's version.
#   version.sh check    — PR into main: VERSION is X.Y.Z and above the latest v* tag
#   version.sh release  — push to main: tag vX.Y.Z (annotated) and open a draft
#                         GitHub Release with the generated notes; no-op if the tag exists
# Needs the tags fetched (checkout with fetch-depth: 0). Env: GH_TOKEN for release,
# DRY_RUN=1 to only print what release would do.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

version=$(tr -d '[:space:]' < VERSION)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "::error file=VERSION::'$version' is not X.Y.Z"; exit 1; }
tag="v$version"
latest=$(git tag -l 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)

case "${1:-}" in
check)
    if [[ -n "$latest" ]] && { [[ "$tag" == "$latest" ]] ||
        [[ $(printf '%s\n%s\n' "$latest" "$tag" | sort -V | tail -1) != "$tag" ]]; }; then
        echo "::error file=VERSION::VERSION is $version but the latest release is $latest: bump it in a chore(release) PR to dev"
        exit 1
    fi
    echo "VERSION $version > ${latest:-no tag yet}"
    ;;
release)
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        echo "$tag already exists, nothing to do"; exit 0
    fi
    notes=$(mktemp)
    printf '%s\n' '## Summary' '' '<!-- What this release is about, in a few lines. -->' '' \
        '## Upgrading' '' '<!-- Restart Quickshell? Config or data changes? -->' '' > "$notes"
    echo "Tagging $tag on $(git rev-parse --short HEAD) and drafting its release (notes since ${latest:-the first commit})"
    [[ "$DRY_RUN" == 1 ]] && { echo "(dry run, nothing changed)"; exit 0; }
    git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        tag -a "$tag" -m "Synapse $tag"
    git push origin "refs/tags/$tag"
    gh release create "$tag" --draft --verify-tag --title "$tag" \
        --generate-notes ${latest:+--notes-start-tag "$latest"} --notes-file "$notes"
    ;;
*) echo "usage: version.sh check | release" >&2; exit 2 ;;
esac
