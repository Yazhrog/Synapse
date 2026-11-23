#!/usr/bin/env bash
# Keeps the Synapse Roadmap board in step with the branches:
#   roadmap.sh done <before> <after>  — push to dev: the issues closed by the
#                                       merged PRs of the push go to Done (still open)
#   roadmap.sh close [<after>]        — push to main: every open Done issue is closed
#   roadmap.sh status <pr>            — PR opened, edited, drafted or ready: the
#                                       issues its body closes go to In progress
#                                       (draft) or In review (ready for review);
#                                       an issue already Done is left alone
# Env: GH_TOKEN (needs repo + project), GITHUB_REPOSITORY (owner/name),
#      PROJECT_NUMBER (default 1), DRY_RUN=1 to only print what would change.
set -euo pipefail

REPO="${GITHUB_REPOSITORY:?}"
OWNER="${REPO%%/*}"
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
DRY_RUN="${DRY_RUN:-0}"

run() { if [[ "$DRY_RUN" == 1 ]]; then echo "  (dry run, nothing changed)"; else "$@"; fi; }

# Project id, Status field id and its options (name → id, in STATUS_OPTIONS).
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
    STATUS_OPTIONS=$(jq -c '[.data.user.projectV2.field.options[] | {(.name): .id}] | add' <<<"$data")
}

option_id() {
    local id
    id=$(jq -r --arg n "$1" '.[$n] // empty' <<<"$STATUS_OPTIONS")
    [[ -n "$id" ]] || { echo "No $1 option on the Status field" >&2; exit 1; }
    echo "$id"
}

# Issue numbers named by closing keywords in a PR body.
closing_refs() {
    grep -oiE '\b(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+#[0-9]+' | grep -oE '[0-9]+$' || true
}

# set_status <issue> <status name> [keep-done]: puts the issue on the board if
# needed and sets its Status; with keep-done, an issue already Done stays Done.
set_status() {
    local issue="$1" status="$2" keep_done="${3:-}" option data node item current
    option=$(option_id "$status")
    data=$(gh api graphql -f owner="${REPO%%/*}" -f name="${REPO##*/}" -F number="$issue" -f query='
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) { issueOrPullRequest(number: $number) {
          __typename
          ... on Issue { id projectItems(first: 20) { nodes { id project { id }
            status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } } } } }
        } }
      }')
    if [[ $(jq -r '.data.repository.issueOrPullRequest.__typename' <<<"$data") != Issue ]]; then
        echo "#$issue is not an issue, skipped"; return
    fi
    node=$(jq -r '.data.repository.issueOrPullRequest.id' <<<"$data")
    item=$(jq -r --arg p "$PROJECT_ID" '.data.repository.issueOrPullRequest.projectItems.nodes[] | select(.project.id == $p) | .id' <<<"$data")
    current=$(jq -r --arg p "$PROJECT_ID" '.data.repository.issueOrPullRequest.projectItems.nodes[] | select(.project.id == $p) | .status.name // ""' <<<"$data")
    if [[ "$current" == "$status" ]]; then echo "#$issue is already $status"; return; fi
    if [[ -n "$keep_done" && "$current" == Done ]]; then echo "#$issue is Done, left alone"; return; fi
    if [[ -z "$item" ]]; then
        echo "#$issue: adding to the board"
        if [[ "$DRY_RUN" == 1 ]]; then item=DRY_RUN; else
            item=$(gh api graphql -f project="$PROJECT_ID" -f content="$node" -f query='
              mutation($project: ID!, $content: ID!) {
                addProjectV2ItemById(input: {projectId: $project, contentId: $content}) { item { id } }
              }' --jq '.data.addProjectV2ItemById.item.id')
        fi
    fi
    echo "#$issue: ${current:-no status} → $status"
    run gh api graphql --silent -f project="$PROJECT_ID" -f item="$item" -f field="$STATUS_FIELD" -f option="$option" -f query='
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
    for issue in $issues; do set_status "$issue" Done; done
}

cmd_status() {
    local pr="$1" info status issues
    info=$(gh api "repos/$REPO/pulls/$pr" --jq '{state, draft, body: (.body // "")}')
    if [[ $(jq -r .state <<<"$info") != open ]]; then echo "PR #$pr is not open"; return; fi
    if [[ $(jq -r .draft <<<"$info") == true ]]; then status="In progress"; else status="In review"; fi
    issues=$(jq -r .body <<<"$info" | closing_refs | sort -un)
    [[ -n "$issues" ]] || { echo "PR #$pr closes no issue"; return; }
    load_project
    echo "PR #$pr ($status)"
    for issue in $issues; do set_status "$issue" "$status" keep-done; done
}

cmd_close() {
    local after="${1:-}" version="" pr="" note
    [[ -f VERSION ]] && version="v$(<VERSION)"
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
    done)   cmd_done "${2:?before sha}" "${3:?after sha}" ;;
    close)  cmd_close "${2:-}" ;;
    status) cmd_status "${2:?pr number}" ;;
    *) echo "usage: roadmap.sh done <before> <after> | close [<after>] | status <pr>" >&2; exit 2 ;;
esac
