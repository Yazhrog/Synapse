import QtQuick
import QtQuick.Controls
import qs.src.components.settings
import qs.src.features.dashboard.config.controls
import qs.src.state
// GeneralPage — Config → General: everyday shell preferences.
//
// Every row edits a Prefs key and applies live. Defaults match the
// shell's behaviour before these settings existed.
Item {
    id: root

    // Back to the top (the dashboard closed).
    function reset() { flick.cancelFlick(); flick.contentY = 0 }

    // The default-tab options come from the popups' page registries (through
    // their PopupSpec: this page is itself a dashboard page).
    function _pageOptions(popup) {
        const pages = SurfaceState.specOf(popup)?.pages ?? []
        return [{ value: "last", label: "Last used" }]
            .concat(Array.from(pages, p => ({ value: p.key, label: p.label })))
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
                title: "Clock & startup"

                PrefToggle {
                    key: "use24HourClock"
                }

                SettingsDivider {}

                PrefToggle {
                    key: "bootFocusMode"
                }
            }

            SettingsGroup {
                title: "Bar"

                PrefToggle {
                    key: "alwaysShowBatteryPercentage"
                }

                SettingsDivider {}

                PrefToggle {
                    key: "alwaysShowVolumePercentage"
                }

                SettingsDivider {}

                PrefToggle {
                    key: "enableVisualiser"
                }
            }

            SettingsGroup {
                title: "Popups"

                PrefDropdown {
                    key: "defaultDashboardPage"
                    options: root._pageOptions("dashboard")
                }

                SettingsDivider {}

                PrefDropdown {
                    key: "defaultAudioPage"
                    options: root._pageOptions("audio")
                }
            }

            SettingsGroup {
                title: "Files"

                PrefTextField {
                    key: "avatarPath"
                    placeholderText: "~/Pictures/avatar.png"
                }

                SettingsDivider {}

                PrefTextField {
                    key: "screenRecordingDir"
                    placeholderText: "~/Videos/screen_recordings"
                }
            }
        }
    }
}
