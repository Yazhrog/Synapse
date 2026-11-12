import QtQuick
import QtQuick.Controls
import "../"
import "../../"
import "../../components"

// DataPage — Config → Data & Storage: reset, export and cleanup actions.
//
// The actions live in DataService; each button shows ✓ when its action has
// finished. Destructive buttons need a second click; factory reset goes
// through the ConfirmDialog and restarts the shell.
Item {
    id: root

    // Back to the top (the dashboard closed).
    function reset() { flick.cancelFlick(); flick.contentY = 0 }

    onVisibleChanged: if (visible) DataService.refreshCacheSize()
    Component.onCompleted: DataService.refreshCacheSize()

    readonly property var _buttons: ({
        prefs:     prefsBtn,
        wallpaper: wallBtn,
        avatar:    avatarBtn,
        export:    exportBtn,
        tasks:     tasksBtn,
        clipboard: clipBtn,
        cache:     cacheBtn
    })

    Connections {
        target: DataService
        function onFinished(action, ok) {
            const b = root._buttons[action]
            if (b) b.flashDone(ok)
        }
    }

    Flickable {
        id: flick
        anchors {
            fill:         parent
            topMargin:    14
            bottomMargin: 8
        }
        contentWidth:   width
        contentHeight:  col.implicitHeight + 8
        clip:           true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 3; implicitHeight: 40; radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.22)
            }
            background: Item {}
        }

        Column {
            id: col
            anchors {
                left:        parent.left
                right:       parent.right
                leftMargin:  16
                rightMargin: 16
            }
            spacing: 14

            SettingsGroup {
                title: "Preferences"

                SettingsButton {
                    id: prefsBtn
                    label:       "Reset shell preferences"
                    description: "Every setting in General, Appearance and Misc back to its default."
                    buttonText:  "Reset"
                    destructive: true
                    onActivated: DataService.resetPrefs()
                }

                SettingsDivider {}

                SettingsButton {
                    id: wallBtn
                    label:       "Reset wallpaper preferences"
                    description: "Default wallpaper, wallpaper folder and colour scheme."
                    buttonText:  "Reset"
                    destructive: true
                    busy:        WallpaperService.applying
                    onActivated: DataService.resetWallpaper()
                }

                SettingsDivider {}

                SettingsButton {
                    id: avatarBtn
                    label:       "Reset avatar"
                    description: PrefsService.avatarPath === ""
                        ? "Already using the wallpaper." : "Back to the wallpaper image."
                    buttonText:  "Reset"
                    enabled:     PrefsService.avatarPath !== ""
                    onActivated: DataService.resetAvatar()
                }
            }

            SettingsGroup {
                title: "Tasks & clipboard"

                SettingsButton {
                    id: exportBtn
                    label:       "Export tasks"
                    description: "Copies the task board to Documents as synapse_tasks_<date>.json."
                    buttonText:  "Export"
                    busy:        DataService.busy
                    onActivated: DataService.exportTasks()
                }

                SettingsDivider {}

                SettingsButton {
                    id: tasksBtn
                    label:       "Clear task board"
                    description: "Removes every task from every column."
                    buttonText:  "Clear"
                    destructive: true
                    busy:        DataService.busy
                    onActivated: DataService.clearTasks()
                }

                SettingsDivider {}

                SettingsButton {
                    id: clipBtn
                    label:       "Wipe clipboard history"
                    description: "Deletes the whole history, pinned items included."
                    buttonText:  "Wipe"
                    destructive: true
                    onActivated: DataService.wipeClipboard()
                }
            }

            SettingsGroup {
                title: "Cache & reset"

                SettingsButton {
                    id: cacheBtn
                    label:           "Clear shell cache"
                    description:     DataService.cacheSize !== ""
                        ? Paths.cacheDir + " — " + DataService.cacheSize
                        : Paths.cacheDir + " — empty"
                    monoDescription: true
                    buttonText:      "Clear"
                    busy:            DataService.busy
                    onActivated:     DataService.clearCache()
                }

                SettingsDivider {}

                SettingsButton {
                    label:       "Factory reset"
                    description: "Deletes all Synapse data (tasks, pins, keybinds, settings, wallpaper) and restarts the shell."
                    buttonText:  "Factory Reset"
                    destructive: true
                    onActivated: Popups.showConfirm(
                        "Factory reset",
                        "Deletes everything in " + Paths.userDataDir + " and the shell cache, then restarts the shell. " +
                        "Your repo path, monitors.lua and local.zsh are kept. This can't be undone.",
                        "Reset", "factory-reset")
                }
            }
        }
    }
}
