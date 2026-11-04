import QtQuick
import QtQuick.Controls
import "../../"
import "../../components"

// GeneralPage — Config → General: everyday shell preferences.
//
// Every row edits a PrefsService key and applies live. Defaults match the
// shell's behaviour before these settings existed.
Item {
    id: root

    Flickable {
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
                title: "Clock & startup"

                SettingsToggle {
                    label:       "Use 24-hour time"
                    description: "Off shows the bar and dashboard clocks as 3:45 PM."
                    prefKey:     "use24HourClock"
                }

                SettingsDivider {}

                SettingsToggle {
                    label:       "Boot into Focus Mode"
                    description: "Hides the bar and tightens the gaps when the shell starts."
                    prefKey:     "bootFocusMode"
                }
            }

            SettingsGroup {
                title: "Bar"

                SettingsToggle {
                    label:       "Always show battery percentage"
                    description: "Otherwise it shows when you hover the icon."
                    prefKey:     "alwaysShowBatteryPercentage"
                }

                SettingsDivider {}

                SettingsToggle {
                    label:       "Always show volume percentage"
                    description: "Otherwise it shows when you hover the icon."
                    prefKey:     "alwaysShowVolumePercentage"
                }

                SettingsDivider {}

                SettingsToggle {
                    label:       "Audio visualizer"
                    description: "Bars in the notch and the player card. Off stops cava."
                    prefKey:     "enableVisualiser"
                }
            }

            SettingsGroup {
                title: "Popups"

                SettingsDropdown {
                    label:       "Default dashboard tab"
                    description: "Shown when the dashboard opens from the bar."
                    prefKey:     "defaultDashboardPage"
                    options: [
                        { value: "last",     label: "Last used" },
                        { value: "home",     label: "Home"      },
                        { value: "stats",    label: "System"    },
                        { value: "kanban",   label: "Tasks"     },
                        { value: "launcher", label: "Apps"      },
                        { value: "config",   label: "Config"    }
                    ]
                }

                SettingsDivider {}

                SettingsDropdown {
                    label:       "Default audio tab"
                    description: "Shown when the audio popup opens from the bar."
                    prefKey:     "defaultAudioPage"
                    options: [
                        { value: "last",   label: "Last used" },
                        { value: "output", label: "Output"    },
                        { value: "input",  label: "Input"     },
                        { value: "mixer",  label: "Mixer"     }
                    ]
                }
            }

            SettingsGroup {
                title: "Files"

                SettingsTextField {
                    label:           "Custom avatar"
                    description:     "Image for the dashboard's profile card. Empty uses the wallpaper."
                    prefKey:         "avatarPath"
                    placeholderText: "~/Pictures/avatar.png"
                }

                SettingsDivider {}

                SettingsTextField {
                    label:           "Screen recording folder"
                    description:     "Where new recordings are saved."
                    prefKey:         "screenRecordingDir"
                    placeholderText: "~/Videos/screen_recordings"
                }
            }
        }
    }
}
