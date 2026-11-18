pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services.data
// UpdateService — startup update checker (30s delay).
// The autoUpdate preference lives in Prefs. Every git command gets the
// repo path as an argument ($1 in the scripts), never pasted into a string.
Singleton {
    id: root

    // ── Persistent preference ──────────────────────────────────────────────
    readonly property bool autoUpdate: Prefs.data.autoUpdate

    // ── Live state (drives UpdatePopup) ───────────────────────────────────
    property bool   checking:        false
    property bool   updating:        false
    property bool   updateAvailable: false
    property bool   hasConflict:     false
    property bool   updateSuccess:   false

    property int    commitsBehind:   0
    property var    commitMessages:  []
    property string lastError:       ""

    // Set when the pull brought in changes that a relink alone can't apply —
    // new packages or a changed manifest need boot.sh to be re-run.
    property bool   needsFullInstall: false
    // Populated only when install/steps/02-packages.sh itself changed — the
    // exact package names added/removed, for a specific popup message instead
    // of the generic "packages or manifest changed" one.
    property var    newPackages:     []
    property var    removedPackages: []
    property int _pingAttempts:    0
    property int _pingMaxAttempts: 12
    
    property var _pingRetryTimer: Timer {
        interval: 5000
        repeat:   false
        onTriggered: root._pingCheck()
    }
    
    property Exec _pingProc: Exec {
        command: ["ping", "-c", "1", "-W", "3", "1.1.1.1"]
        onSucceeded: {
            root._pingAttempts = 0
            root.check()
        }
        onFailed: {
            root._pingAttempts++
            console.log("Ping attempt " + root._pingAttempts + " failed, retrying...")
            if (root._pingAttempts < root._pingMaxAttempts) {
                root._pingRetryTimer.restart()
            } else {
                root._pingAttempts = 0  // silent cancel
                console.log("Max ping attempts reached. Update check aborted.")
            }
        }
    }
    
    function _startConnectivityCheck() {
        root._pingAttempts = 0
        root._pingCheck()
        console.log("Started connectivity check for updates.")
    }
    
    function _pingCheck() { root._pingProc.run() }

    // Popup is only shown when autoUpdate is enabled
    readonly property bool showPopup:
        autoUpdate && (
            updateAvailable ||
            updating ||
            hasConflict ||
            updateSuccess ||
            (lastError !== "" && !checking)
        )

    // ── Paths ──────────────────────────────────────────────────────────────
    // The repo location comes from Paths.repoDir (see Paths.qml for why it
    // can't be derived from Quickshell.shellDir).
    property string _dir: ""

    // ── Startup: 30s delay ─────────────────────────────────────────────────
    property var _startTimer: Timer {
        interval: 30000
        repeat:   false
        running:  false
        onTriggered: root._startConnectivityCheck()
    }

    // ── Init: wait for prefs → arm timer ───────────────────────────────────
    function _init() {
        root._dir = Paths.repoDir
        console.log("UpdateService: repo=" + root._dir + " autoUpdate=" + root.autoUpdate)
        if (root.autoUpdate) {
            console.log("UpdateService: Auto-update enabled. Starting 30s delay timer.")
            root._startTimer.start()
        } else {
            console.log("UpdateService: Auto-update disabled.")
        }
    }

    property var _prefsConn: Connections {
        target: Prefs
        function onLoaded() { root._init() }
    }

    // ── Preflight ──────────────────────────────────────────────────────────
    // With "install from the checkout you ran it from", _dir may be someone's
    // working repo. Only offer updates for a clean-cut case: a real git repo,
    // with an origin, sitting on main. Anything else stays silent rather than
    // nagging a developer on a feature branch.
    property Exec _preflightProc: Exec {
        command: ["bash", "-c",
            "d=\"$1\";" +
            "git -C \"$d\" rev-parse --git-dir >/dev/null 2>&1 || { echo notrepo; exit 0; };" +
            "git -C \"$d\" remote get-url origin >/dev/null 2>&1 || { echo noremote; exit 0; };" +
            "b=$(git -C \"$d\" rev-parse --abbrev-ref HEAD 2>/dev/null);" +
            "[ \"$b\" = main ] || { echo \"branch $b\"; exit 0; };" +
            "echo ok",
            "--", root._dir]
        onFinished: {
            var r = lastOutput.trim()
            if (r === "ok") {
                _fetchProc.run()
                return
            }
            // Not an error the user needs a popup about.
            root.checking = false
            if (r === "notrepo")       console.log("UpdateService: " + root._dir + " is not a git repo — skipping.")
            else if (r === "noremote") console.log("UpdateService: no origin remote — skipping.")
            else                       console.log("UpdateService: not on main (" + r + ") — skipping.")
        }
    }

    // ── Step 1: fetch origin/main ──────────────────────────────────────────
    property Exec _fetchProc: Exec {
        command: ["git", "-C", root._dir, "fetch", "origin", "main", "--quiet"]
        onFailed: code => {
            console.log("UpdateService: git fetch failed with code " + code)
            root.checking  = false
            root.lastError = "Could not reach remote. Check your connection."
        }
        onSucceeded: {
            console.log("UpdateService: git fetch successful.")
            _countProc.run()
        }
    }

    // ── Step 2: count commits behind ──────────────────────────────────────
    property Exec _countProc: Exec {
        command: ["git", "-C", root._dir, "rev-list", "--count", "HEAD..origin/main"]
        // A failed read counts as "up to date", as the old 2>/dev/null did.
        onFinished: {
            var n = parseInt(lastOutput.trim())
            root.commitsBehind = isNaN(n) ? 0 : n
            console.log("UpdateService: Commits behind origin/main: " + root.commitsBehind)
            if (root.commitsBehind > 0) {
                _logProc.run()
            } else {
                root.checking = false
                console.log("UpdateService: Up to date.")
            }
        }
    }

    // ── Step 3: read commit log ────────────────────────────────────────────
    property Exec _logProc: Exec {
        command: ["git", "-C", root._dir, "log", "HEAD..origin/main", "--oneline", "--no-decorate"]
        onFinished: {
            root.commitMessages  = lastOutput.trim().split("\n").filter(l => l.trim() !== "")
            root.checking        = false
            root.updateAvailable = true
        }
    }

    // ── Apply: pull → relink → report ─────────────────────────────────────
    // One shell script so the relink can't be skipped: a pull that adds a new
    // config file needs a symlink created for it before the change is live.
    //
    // Emits marker lines the handler below reads:
    //   PULL_FAILED (+ git's own output)  ·  LINK_FAILED  ·  NEEDS_INSTALL  ·
    //   NEW_PKGS:a,b  ·  REMOVED_PKGS:c  ·  OK
    function _applyScript(withStash) {
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

    function _parseCsvMarker(text, prefix) {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf(prefix) === 0) {
                var rest = lines[i].substring(prefix.length).trim()
                return rest === "" ? [] : rest.split(",")
            }
        }
        return []
    }

    function _handleApplyResult(text) {
        root.updating = false

        if (text.indexOf("PULL_FAILED") >= 0) {
            var g = text.toLowerCase()
            // Distinguish the causes instead of blaming local changes for
            // everything — a network drop is not something Stash can fix.
            if (g.indexOf("would be overwritten") >= 0 ||
                g.indexOf("local changes") >= 0 ||
                g.indexOf("please commit") >= 0 ||
                g.indexOf("unstaged changes") >= 0) {
                root.hasConflict = true
                root.lastError   = ""
            } else if (g.indexOf("not possible to fast-forward") >= 0 ||
                       g.indexOf("diverged") >= 0 ||
                       g.indexOf("non-fast-forward") >= 0) {
                root.hasConflict = false
                root.lastError   = "Your checkout has commits that aren't on origin/main. " +
                                   "Push or rebase them, then update again."
            } else if (g.indexOf("could not resolve host") >= 0 ||
                       g.indexOf("unable to access") >= 0 ||
                       g.indexOf("connection") >= 0 ||
                       g.indexOf("timed out") >= 0) {
                root.hasConflict = false
                root.lastError   = "Could not reach the remote. Check your connection."
            } else {
                root.hasConflict = false
                root.lastError   = "Update failed:\n" +
                                   text.replace("PULL_FAILED", "").trim().split("\n").slice(0, 4).join("\n")
            }
            console.log("UpdateService: pull failed —\n" + text)
            return
        }

        root.updateAvailable  = false
        root.hasConflict      = false
        root.lastError        = ""
        root.needsFullInstall = text.indexOf("NEEDS_INSTALL") >= 0
        root.newPackages      = root._parseCsvMarker(text, "NEW_PKGS:")
        root.removedPackages  = root._parseCsvMarker(text, "REMOVED_PKGS:")
        root.updateSuccess    = true

        if (text.indexOf("LINK_FAILED") >= 0)
            console.log("UpdateService: pull succeeded but install/link.sh failed.")
        console.log("UpdateService: update applied. needsFullInstall=" + root.needsFullInstall)
    }

    property Exec _applyProc: Exec {
        onFinished: root._handleApplyResult(lastOutput)
    }

    // ── Reload ─────────────────────────────────────────────────────────────
    // Reloads Hyprland, then replaces quickshell. The restart runs in its own
    // session (setsid) so it outlives the shell process it is about to kill.
    property Exec _reloadProc: Exec {
        command: ["bash", "-c",
            "hyprctl reload >/dev/null 2>&1;" +
            "setsid bash -c 'sleep 0.3; pkill -x quickshell; sleep 0.5; exec quickshell' " +
            ">/dev/null 2>&1 < /dev/null &"]
    }

    // ── Public API ─────────────────────────────────────────────────────────

    function check() {
        console.log("UpdateService: check() triggered")
        if (root.checking || root.updating) return
        if (root._dir === "") {
            console.log("UpdateService: repo path not resolved yet — skipping.")
            return
        }
        root.checking          = true
        root.lastError         = ""
        root.updateAvailable   = false
        root.updateSuccess     = false
        root.hasConflict       = false
        _preflightProc.run()
    }

    function _apply(withStash) {
        if (root.updating) return
        root.updating         = true
        root.hasConflict      = false
        root.lastError        = ""
        root.updateSuccess    = false
        root.newPackages      = []
        root.removedPackages  = []
        _applyProc.run(["bash", "-c", root._applyScript(withStash), "--", root._dir])
    }

    function applyUpdate() {
        console.log("UpdateService: applyUpdate() triggered")
        _apply(false)
    }

    // stash pop is intentionally omitted — the user gets their work back with
    // `git stash pop` once they've seen what the update changed.
    function stashAndUpdate() {
        console.log("UpdateService: stashAndUpdate() triggered")
        _apply(true)
    }

    function reloadShell() {
        console.log("UpdateService: reloadShell() triggered")
        _reloadProc.run()
    }

    function dismiss() {
        console.log("UpdateService: dismiss() triggered")
        root.updateAvailable  = false
        root.hasConflict      = false
        root.lastError        = ""
        root.updateSuccess    = false
        root.needsFullInstall = false
        root.newPackages      = []
        root.removedPackages  = []
    }

    // Two-way, unlike the old disableAutoUpdate(): the Config → Misc toggle
    // binds to this so a user can turn checks back on without editing JSON.
    function setAutoUpdate(enabled) {
        console.log("UpdateService: setAutoUpdate(" + enabled + ")")
        Prefs.set("autoUpdate", enabled)
        if (!enabled) {
            root.updateAvailable = false
            root.hasConflict     = false
            root.lastError       = ""
            root.updateSuccess   = false
            root._startTimer.stop()
        }
    }

    function disableAutoUpdate() {
        setAutoUpdate(false)
    }

    Component.onCompleted: if (Prefs.ready) _init()
}