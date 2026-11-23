// update.js — the pure parts of UpdateService: the pull-and-relink script and
// the reading of its output, and the version an update brings. Pure JS, tested by tests/unit/update.test.mjs.

// The apply script: pull → relink → report. One shell script so the relink
// can't be skipped: a pull that adds a new config file needs a symlink created
// for it before the change is live. It takes the repo path as $1.
//
// Emits marker lines that parseApplyResult() reads:
//   PULL_FAILED (+ git's own output)  ·  LINK_FAILED  ·  NEEDS_INSTALL  ·
//   NEW_PKGS:a,b  ·  REMOVED_PKGS:c  ·  OK
function applyScript(withStash) {
    // The repo path is $1 (passed by _apply()), never pasted in; copied to
    // $repo first because _pkgs() below has its own $1.
    var d = "\"$repo\""
    return "repo=\"$1\";\n" + (withStash
            // || true so an already-clean worktree doesn't abort the chain
            ? "git -C " + d + " stash push -m 'synapse-pre-update' >/dev/null 2>&1 || true;\n"
            : "") +
        "before=$(git -C " + d + " rev-parse HEAD 2>/dev/null);\n" +
        // --ff-only: refuse to invent a merge commit in the user's repo
        "out=$(git -C " + d + " pull --ff-only origin main 2>&1) || " +
        "{ printf 'PULL_FAILED\\n%s\\n' \"$out\"; exit 0; };\n" +
        "after=$(git -C " + d + " rev-parse HEAD 2>/dev/null);\n" +
        "changed=$(git -C " + d + " diff --name-only \"$before\" \"$after\" 2>/dev/null);\n" +
        // Reads PACMAN_DEPS/AUR_DEPS out of 02-packages.sh at a given
        // revision as plain text — never sourced, that script installs
        // packages at the top level. A line-based diff isn't enough since
        // several package names can share one array line; this extracts
        // the full token set at each revision so added/removed names are
        // exact regardless of how the lines were reflowed.
        "_pkgs() { git -C " + d + " show \"$1:install/steps/02-packages.sh\" 2>/dev/null | " +
        "awk -v n=\"$2\" 'index($0,n\"=(\")==1{f=1;next} f&&$0==\")\"{f=0} f' | " +
        "sed 's/#.*$//' | tr -s ' \\t' '\\n' | sed '/^[[:space:]]*$/d'; };\n" +
        "if [ \"$before\" != \"$after\" ] && printf '%s\\n' \"$changed\" | " +
        "grep -qx 'install/steps/02-packages.sh'; then\n" +
        "  old_all=$( { _pkgs \"$before\" PACMAN_DEPS; _pkgs \"$before\" AUR_DEPS; } | sort -u );\n" +
        "  new_all=$( { _pkgs \"$after\" PACMAN_DEPS; _pkgs \"$after\" AUR_DEPS; } | sort -u );\n" +
        "  added=$(comm -13 <(printf '%s\\n' \"$old_all\") <(printf '%s\\n' \"$new_all\") | grep -v '^$');\n" +
        "  removed=$(comm -23 <(printf '%s\\n' \"$old_all\") <(printf '%s\\n' \"$new_all\") | grep -v '^$');\n" +
        "  [ -n \"$added\" ] && printf 'NEW_PKGS:%s\\n' \"$(printf '%s\\n' \"$added\" | paste -sd, -)\";\n" +
        "  [ -n \"$removed\" ] && printf 'REMOVED_PKGS:%s\\n' \"$(printf '%s\\n' \"$removed\" | paste -sd, -)\";\n" +
        "fi;\n" +
        "bash " + d + "/install/link.sh >/dev/null 2>&1 || printf 'LINK_FAILED\\n';\n" +
        // Packages and the manifest itself need the full installer
        "printf '%s\\n' \"$changed\" | grep -qE '^install/(steps/|lib/manifest\\.sh)' && " +
        "printf 'NEEDS_INSTALL\\n';\n" +
        "printf 'OK\\n'"
}

// The comma-separated list after a "PREFIX:" marker line ([] if absent).
function csvMarker(text, prefix) {
    for (const line of text.split("\n")) {
        if (line.indexOf(prefix) === 0) {
            const rest = line.substring(prefix.length).trim()
            return rest === "" ? [] : rest.split(",")
        }
    }
    return []
}

// The apply script's output →
//   { ok: false, conflict: bool, error: string }   the pull failed
//   { ok: true, needsFullInstall, newPackages, removedPackages, linkFailed }
// A failed pull is told apart by cause instead of blaming local changes for
// everything: a network drop is not something Stash can fix.
function parseApplyResult(text) {
    if (text.indexOf("PULL_FAILED") >= 0) {
        const g = text.toLowerCase()
        const has = words => words.some(w => g.indexOf(w) >= 0)
        if (has(["would be overwritten", "local changes", "please commit", "unstaged changes"]))
            return { ok: false, conflict: true, error: "" }
        if (has(["not possible to fast-forward", "diverged", "non-fast-forward"]))
            return { ok: false, conflict: false,
                     error: "Your checkout has commits that aren't on origin/main. " +
                            "Push or rebase them, then update again." }
        if (has(["could not resolve host", "unable to access", "connection", "timed out"]))
            return { ok: false, conflict: false, error: "Could not reach the remote. Check your connection." }
        return { ok: false, conflict: false,
                 error: "Update failed:\n" + text.replace("PULL_FAILED", "").trim().split("\n").slice(0, 4).join("\n") }
    }
    return { ok: true,
             needsFullInstall: text.indexOf("NEEDS_INSTALL") >= 0,
             newPackages:      csvMarker(text, "NEW_PKGS:"),
             removedPackages:  csvMarker(text, "REMOVED_PKGS:"),
             linkFailed:       text.indexOf("LINK_FAILED") >= 0 }
}

// Prints the installed VERSION (HEAD's) and origin/main's on two lines, an
// empty line for a side without the file (installs from before it existed).
// Run after the fetch; takes the repo path as $1.
const versionScript =
    "printf '%s\\n%s\\n' " +
    "\"$(git -C \"$1\" show HEAD:VERSION 2>/dev/null)\" " +
    "\"$(git -C \"$1\" show origin/main:VERSION 2>/dev/null)\""

// One VERSION file's text → "X.Y.Z", or "" if it isn't a plain version.
function readVersion(text) {
    const v = (text || "").trim()
    return /^\d+\.\d+\.\d+$/.test(v) ? v : ""
}

// versionScript's output → { installed, incoming } ("" when missing or invalid)
function parseVersions(text) {
    const lines = (text || "").split("\n")
    return { installed: readVersion(lines[0]), incoming: readVersion(lines[1]) }
}

// What the update popup says about a pending update: the version change
// ("v0.6.3 → v0.7.0") when both sides have a version and they differ, the
// commit count otherwise.
function availableSummary(commits, installed, incoming) {
    if (installed !== "" && incoming !== "" && installed !== incoming)
        return "v" + installed + " → v" + incoming
    return commits + " new commit" + (commits === 1 ? "" : "s") + " on main"
}

if (typeof module !== "undefined")
    module.exports = { applyScript, csvMarker, parseApplyResult,
                       versionScript, readVersion, parseVersions, availableSummary }
