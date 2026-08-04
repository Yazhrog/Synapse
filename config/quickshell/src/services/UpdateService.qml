pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// UpdateService — startup update checker (30s delay).
// Persistent autoUpdate preference stored in src/user_data/update_prefs.json.
QtObject {
    id: root

    // ── Persistent preference ──────────────────────────────────────────────
    property bool autoUpdate: true

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
    property int _pingAttempts:    0
    property int _pingMaxAttempts: 12
    
    property var _pingRetryTimer: Timer {
        interval: 5000
        repeat:   false
        onTriggered: root._pingCheck()
    }
    
    property var _pingProc: Process {
        command: ["ping", "-c", "1", "-W", "3", "1.1.1.1"]
        running: false
        onExited: function(code) {
            if (code === 0) {
                root._pingAttempts = 0
                root.check()
            } else {
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
    }
    
    function _startConnectivityCheck() {
        root._pingAttempts = 0
        root._pingCheck()
        console.log("Started connectivity check for updates.")
    }
    
    function _pingCheck() {
        root._pingProc.running = false
        root._pingProc.running = true
    }

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
    // The repo location is written by boot.sh / install/link.sh. It can't be
    // derived from Quickshell.shellDir: ~/.config/quickshell is a symlink and
    // quickshell reports the link path, not the checkout behind it.
    property string _dir: ""
    readonly property string _repoPathFile: Quickshell.env("HOME") + "/.config/Synapse/repo-path"
    readonly property string _cfgPath:      Quickshell.env("HOME") + "/.config/Synapse/src/user_data/update_prefs.json"

    // ── Startup: 30s delay ─────────────────────────────────────────────────
    property var _startTimer: Timer {
        interval: 30000
        repeat:   false
        running:  false
        onTriggered: root._startConnectivityCheck()
    }

    // ── Config: init → read repo path + prefs → arm timer ─────────────────
    // Emits the repo path on the first line, then the prefs JSON.
    property var _initProc: Process {
        command: ["bash", "-c",
            "[ -f '" + root._cfgPath + "' ] || " +
            "(mkdir -p \"$(dirname '" + root._cfgPath + "')\" && " +
            "printf '%s' '{\"autoUpdate\":true}' > '" + root._cfgPath + "');\n" +
            "cat '" + root._repoPathFile + "' 2>/dev/null || " +
            "echo \"$HOME/.local/src/Synapse\";\n" +
            "cat '" + root._cfgPath + "'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                root._dir = (lines.shift() || "").trim()

                try {
                    var o = JSON.parse(lines.join("\n").trim())
                    if (typeof o.autoUpdate === "boolean")
                        root.autoUpdate = o.autoUpdate
                } catch(e) {
                    console.log("UpdateService: Failed to parse config JSON:", e)
                }
                console.log("UpdateService: repo=" + root._dir + " autoUpdate=" + root.autoUpdate)

                if (root.autoUpdate) {
                    console.log("UpdateService: Auto-update enabled. Starting 30s delay timer.")
                    root._startTimer.start()
                } else {
                    console.log("UpdateService: Auto-update disabled.")
                }
            }
        }
    }

    // ── Preflight ──────────────────────────────────────────────────────────
    // With "install from the checkout you ran it from", _dir may be someone's
    // working repo. Only offer updates for a clean-cut case: a real git repo,
    // with an origin, sitting on main. Anything else stays silent rather than
    // nagging a developer on a feature branch.
    property var _preflightProc: Process {
        command: ["bash", "-c",
            "d='" + root._dir + "';" +
            "git -C \"$d\" rev-parse --git-dir >/dev/null 2>&1 || { echo notrepo; exit 0; };" +
            "git -C \"$d\" remote get-url origin >/dev/null 2>&1 || { echo noremote; exit 0; };" +
            "b=$(git -C \"$d\" rev-parse --abbrev-ref HEAD 2>/dev/null);" +
            "[ \"$b\" = main ] || { echo \"branch $b\"; exit 0; };" +
            "echo ok"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var r = text.trim()
                if (r === "ok") {
                    _fetchProc.running = false
                    _fetchProc.running = true
                    return
                }
                // Not an error the user needs a popup about.
                root.checking = false
                if (r === "notrepo")       console.log("UpdateService: " + root._dir + " is not a git repo — skipping.")
                else if (r === "noremote") console.log("UpdateService: no origin remote — skipping.")
                else                       console.log("UpdateService: not on main (" + r + ") — skipping.")
            }
        }
    }

    // ── Config: save ──────────────────────────────────────────────────────
    property var _saveProc: Process { command: []; running: false }

    function _saveConfig() {
        console.log("UpdateService: Saving config. autoUpdate=" + root.autoUpdate)
        var json = JSON.stringify({ autoUpdate: root.autoUpdate })
        _saveProc.command = ["bash", "-c",
            "printf '%s' '" + json.replace(/'/g, "'\\''") +
            "' > '" + root._cfgPath + "'"]
        _saveProc.running = false
        _saveProc.running = true
    }

    // ── Step 1: fetch origin/main ──────────────────────────────────────────
    property var _fetchProc: Process {
        command: ["git", "-C", root._dir, "fetch", "origin", "main", "--quiet"]
        running: false
        onExited: function(code) {
            if (code !== 0) {
                console.log("UpdateService: git fetch failed with code " + code)
                root.checking  = false
                root.lastError = "Could not reach remote. Check your connection."
                return
            }
            console.log("UpdateService: git fetch successful.")
            _countProc.running = false
            _countProc.running = true
        }
    }

    // ── Step 2: count commits behind ──────────────────────────────────────
    property var _countProc: Process {
        command: ["bash", "-c",
            "git -C '" + root._dir + "' rev-list --count HEAD..origin/main 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(text.trim())
                root.commitsBehind = isNaN(n) ? 0 : n
                console.log("UpdateService: Commits behind origin/main: " + root.commitsBehind)
                if (root.commitsBehind > 0) {
                    _logProc.running = false
                    _logProc.running = true
                } else {
                    root.checking = false
                    console.log("UpdateService: Up to date.")
                }
            }
        }
    }

    // ── Step 3: read commit log ────────────────────────────────────────────
    property var _logProc: Process {
        command: ["bash", "-c",
            "git -C '" + root._dir +
            "' log HEAD..origin/main --oneline --no-decorate 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim()
                    .split("\n")
                    .filter(function(l) { return l.trim() !== "" })
                root.commitMessages  = lines
                root.checking        = false
                root.updateAvailable = true
            }
        }
    }

    // ── Apply: pull → relink → report ─────────────────────────────────────
    // One shell script so the relink can't be skipped: a pull that adds a new
    // config file needs a symlink created for it before the change is live.
    //
    // Emits marker lines the handler below reads:
    //   PULL_FAILED (+ git's own output)  ·  LINK_FAILED  ·  NEEDS_INSTALL  ·  OK
    function _applyScript(withStash) {
        var d = "'" + root._dir + "'"
        return (withStash
                // || true so an already-clean worktree doesn't abort the chain
                ? "git -C " + d + " stash push -m 'synapse-pre-update' >/dev/null 2>&1 || true;\n"
                : "") +
            "before=$(git -C " + d + " rev-parse HEAD 2>/dev/null);\n" +
            // --ff-only: refuse to invent a merge commit in the user's repo
            "out=$(git -C " + d + " pull --ff-only origin main 2>&1) || " +
            "{ printf 'PULL_FAILED\\n%s\\n' \"$out\"; exit 0; };\n" +
            "after=$(git -C " + d + " rev-parse HEAD 2>/dev/null);\n" +
            "changed=$(git -C " + d + " diff --name-only \"$before\" \"$after\" 2>/dev/null);\n" +
            "bash " + d + "/install/link.sh >/dev/null 2>&1 || printf 'LINK_FAILED\\n';\n" +
            // Packages and the manifest itself need the full installer
            "printf '%s\\n' \"$changed\" | grep -qE '^install/(steps/|lib/manifest\\.sh)' && " +
            "printf 'NEEDS_INSTALL\\n';\n" +
            "printf 'OK\\n'"
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
        root.updateSuccess    = true

        if (text.indexOf("LINK_FAILED") >= 0)
            console.log("UpdateService: pull succeeded but install/link.sh failed.")
        console.log("UpdateService: update applied. needsFullInstall=" + root.needsFullInstall)
    }

    property var _applyProc: Process {
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._handleApplyResult(text)
        }
    }

    // ── Reload ─────────────────────────────────────────────────────────────
    // Reloads Hyprland, then replaces quickshell. The restart runs in its own
    // session (setsid) so it outlives the shell process it is about to kill.
    property var _reloadProc: Process {
        command: ["bash", "-c",
            "hyprctl reload >/dev/null 2>&1;" +
            "setsid bash -c 'sleep 0.3; pkill -x quickshell; sleep 0.5; exec quickshell' " +
            ">/dev/null 2>&1 < /dev/null &"]
        running: false
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
        _preflightProc.running = false
        _preflightProc.running = true
    }

    function _apply(withStash) {
        if (root.updating) return
        root.updating       = true
        root.hasConflict    = false
        root.lastError      = ""
        root.updateSuccess  = false
        _applyProc.command  = ["bash", "-c", root._applyScript(withStash)]
        _applyProc.running  = false
        _applyProc.running  = true
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
        _reloadProc.running = false
        _reloadProc.running = true
    }

    function dismiss() {
        console.log("UpdateService: dismiss() triggered")
        root.updateAvailable  = false
        root.hasConflict      = false
        root.lastError        = ""
        root.updateSuccess    = false
        root.needsFullInstall = false
    }

    // Two-way, unlike the old disableAutoUpdate(): the Config → Misc toggle
    // binds to this so a user can turn checks back on without editing JSON.
    function setAutoUpdate(enabled) {
        console.log("UpdateService: setAutoUpdate(" + enabled + ")")
        root.autoUpdate = enabled
        if (!enabled) {
            root.updateAvailable = false
            root.hasConflict     = false
            root.lastError       = ""
            root.updateSuccess   = false
            root._startTimer.stop()
        }
        _saveConfig()
    }

    function disableAutoUpdate() {
        setAutoUpdate(false)
    }

    Component.onCompleted: _initProc.running = true
}