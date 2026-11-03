pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// Paths — single source of truth for every directory the shell uses.
//
//   configDir    $SYNAPSE_CONFIG_DIR if set, else ~/.config/Synapse
//   userDataDir  configDir/src/user_data   (runtime JSON state)
//   wallpaperDir userDataDir/wallpapers    (curr_wall symlinks)
//   shellDir     Quickshell.shellDir       (scripts/assets in the repo)
//   repoDir      content of configDir/repo-path, else ~/.local/src/Synapse
//   cacheDir     ~/.cache/Synapse
//
// SYNAPSE_CONFIG_DIR lets a dev checkout run against throwaway data:
//   SYNAPSE_CONFIG_DIR=/tmp/synapse-test qs -p <checkout>/config/quickshell
// matugen.toml and the installer can't read this and keep their own paths.
// ============================================================

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    readonly property string configDir: {
        const dir = Quickshell.env("SYNAPSE_CONFIG_DIR")
        return dir ? String(dir).replace(/\/+$/, "") : home + "/.config/Synapse"
    }
    readonly property string userDataDir:  configDir + "/src/user_data"
    readonly property string wallpaperDir: userDataDir + "/wallpapers"
    readonly property string shellDir:     Quickshell.shellDir
    readonly property string cacheDir:     home + "/.cache/Synapse"

    // Written by boot.sh / install/link.sh. The repo location can't be derived
    // from shellDir: ~/.config/quickshell is a symlink and quickshell reports
    // the link path, not the checkout behind it.
    readonly property string repoPathFile: configDir + "/repo-path"
    readonly property string repoDir: {
        const dir = _repoPath.text().trim()
        return dir !== "" ? dir : home + "/.local/src/Synapse"
    }

    // Path of a file in userDataDir, e.g. Paths.userData("tasks.json").
    function userData(name: string): string {
        return userDataDir + "/" + name
    }

    property FileView _repoPath: FileView {
        path: root.repoPathFile
        blockAllReads: true
        printErrors: false
    }
}
