import QtQuick
import qs.src.components.settings
import qs.src.features.dashboard.config.controls
import qs.src.services.data
import qs.src.theme
// AppearancePage — Config → Appearance: how the frame looks.
//
// Every control edits a Prefs key that Metrics/Theme read, so the
// frame, the bar and every popup follow live. Theme presets and colour
// overrides will land in this tab later.
Item {
    id: root

    Column {
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   14
            leftMargin:  16
            rightMargin: 16
        }
        spacing: 14

        SettingsGroup {
            title: "Background"

            PrefSlider {
                key: "backgroundOpacity"
                stepSize:    1
                unit:        "%"
            }

            SettingsDivider {}

            PrefToggle {
                key: "backgroundBlur"
                description: Prefs.data.backgroundOpacity < 100
                    ? "Blurs what is behind the frame."
                    : "Blurs what is behind the frame. Shows below 100 % opacity."
            }
        }

        SettingsGroup {
            title: "Shape"

            PrefDropdown {
                key: "barStyle"
                description: Theme.barStyle === "pills"
                    ? "Floating capsules; popups grow out of them."
                    : Theme.barStyle === "bar"
                        ? "One full-width bar along the top, no borders."
                        : "Notches joined by the borders around the screen."
            }

            SettingsDivider {}

            PrefSlider {
                key: "borderWidth"
                description: Theme.barStyle === "frame"
                    ? "Of the side and bottom borders. 0 hides them."
                    : "Only in the Frame style."
                enabled:     Theme.barStyle === "frame"
                opacity:     enabled ? 1 : 0.45
                stepSize:    1
                unit:        " px"
            }

            SettingsDivider {}

            PrefSlider {
                key: "cornerRadius"
                stepSize:    1
                unit:        " px"
            }
        }
    }
}
