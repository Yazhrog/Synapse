#!/usr/bin/env bash
# Keeps the Synapse Roadmap board in step with the branches:
#   roadmap.sh done <before> <after>  — push to dev: the issues closed by the
#                                       merged PRs of the push go to Done (still open)
#   roadmap.sh close [<after>]        — push to main: every open Done issue is closed
# Env: GH_TOKEN (needs repo + project), GITHUB_REPOSITORY (owner/name),
#      PROJECT_NUMBER (default 1), DRY_RUN=1 to only print what would change.
set -euo pipefail

REPO="${GITHUB_REPOSITORY:?}"
OWNER="${REPO%%/*}"
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
DRY_RUN="${DRY_RUN:-0}"

run() { if [[ "$DRY_RUN" == 1 ]]; then echo "  (dry run, nothing changed)"; else "$@"; fi; }

# Project id, Status field id and its Done option id.
load_project() {
    local data
    data=$(gh api graphql -f owner="$OWNER" -F number="$PROJECT_NUMBER" -f query='
      query($owner: String!, $number: Int!) {
        user(login: $owner) { projectV2(number: $number) {
          id
          field(name: "Status") { ... on ProjectV2SingleSelectField { id options { id name } } }
        } }
      }')
    PROJECT_ID=$(jq -r '.data.user.projectV2.id' <<<"$data")
    STATUS_FIELD=$(jq -r '.data.user.projectV2.field.id' <<<"$data")
    DONE_OPTION=$(jq -r '.data.user.projectV2.field.options[] | select(.name == "Done") | .id' <<<"$data")
    [[ -n "$DONE_OPTION" ]] || { echo "No Done option on the Status field" >&2; exit 1; }
}

# Issue numbers named by closing keywords in a PR body.
closing_refs() {
    grep -oiE '\b(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+#[0-9]+' | grep -oE '[0-9]+$' || true
}

set_done() {
    local issue="$1" data node item
    data=$(gh api graphql -f owner="${REPO%%/*}" -f name="${REPO##*/}" -F number="$issue" -f query='
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) { issueOrPullRequest(number: $number) {
          __typename
          ... on Issue { id projectItems(first: 20) { nodes { id project { id } } } }
        } }
      }')
    if [[ $(jq -r '.data.repository.issueOrPullRequest.__typename' <<<"$data") != Issue ]]; then
        echo "#$issue is not an issue, skipped"; return
    fi
    node=$(jq -r '.data.repository.issueOrPullRequest.id' <<<"$data")
    item=$(jq -r --arg p "$PROJECT_ID" '.data.repository.issueOrPullRequest.projectItems.nodes[] | select(.project.id == $p) | .id' <<<"$data")
    if [[ -z "$item" ]]; then
        echo "#$issue: adding to the board"
        if [[ "$DRY_RUN" == 1 ]]; then item=DRY_RUN; else
            item=$(gh api graphql -f project="$PROJECT_ID" -f content="$node" -f query='
              mutation($project: ID!, $content: ID!) {
                addProjectV2ItemById(input: {projectId: $project, contentId: $content}) { item { id } }
              }' --jq '.data.addProjectV2ItemById.item.id')
        fi
    fi
    echo "#$issue → Done"
    run gh api graphql --silent -f project="$PROJECT_ID" -f item="$item" -f field="$STATUS_FIELD" -f option="$DONE_OPTION" -f query='
      mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
        updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
          value: {singleSelectOptionId: $option}}) { projectV2Item { id } }
      }'
}

cmd_done() {
    local before="$1" after="$2" shas prs
    if [[ "$before" =~ ^0+$ ]]; then shas="$after"
    else shas=$(gh api "repos/$REPO/compare/$before...$after" --jq '.commits[].sha'); fi
    prs=$(for sha in $shas; do
        gh api "repos/$REPO/commits/$sha/pulls" --jq '.[] | select(.merged_at != null) | .number'
    done | sort -un)
    [[ -n "$prs" ]] || { echo "No merged PR in this push"; return; }
    load_project
    local issues
    issues=$(for pr in $prs; do
        echo "PR #$pr" >&2
        gh api "repos/$REPO/pulls/$pr" --jq '.body // ""' | closing_refs
    done | sort -un)
    [[ -n "$issues" ]] || { echo "No closing keywords in these PRs"; return; }
    for issue in $issues; do set_done "$issue"; done
}

cmd_close() {
    local after="${1:-}" version="" pr="" note
    version=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' boot.sh 2>/dev/null | head -1 || true)
    [[ -n "$after" ]] && pr=$(gh api "repos/$REPO/commits/$after/pulls" --jq '[.[] | select(.merged_at != null)][0].number // empty' || true)
    note="Released${version:+ in $version}${pr:+ (#$pr)}: this is now on \`main\`."

    load_project
    local issues
    issues=$(gh api graphql --paginate -f project="$PROJECT_ID" -f query='
      query($project: ID!, $endCursor: String) {
        node(id: $project) { ... on ProjectV2 { items(first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
            content { ... on Issue { number state repository { nameWithOwner } } }
          }
        } } }
      }' | jq -r --arg repo "$REPO" '.data.node.items.nodes[]
          | select(.status.name == "Done" and .content.state == "OPEN" and .content.repository.nameWithOwner == $repo)
          | .content.number' | sort -un)
    [[ -n "$issues" ]] || { echo "No open Done issues"; return; }
    for issue in $issues; do
        echo "#$issue → closed"
        run gh issue close "$issue" -R "$REPO" --reason completed --comment "$note"
    done
}

case "${1:-}" in
    done)  cmd_done "${2:?before sha}" "${3:?after sha}" ;;
    close) cmd_close "${2:-}" ;;
    *) echo "usage: roadmap.sh done <before> <after> | close [<after>]" >&2; exit 2 ;;
esac
