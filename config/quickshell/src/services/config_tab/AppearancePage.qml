import QtQuick
import "../../"
import "../../components"

// AppearancePage — Config → Appearance: how the frame looks.
//
// Every control edits a PrefsService key that Metrics/Theme read, so the
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

            SettingsSlider {
                label:       "Background opacity"
                description: "Of the bar, the borders and the popups."
                prefKey:     "backgroundOpacity"
                from:        50
                to:          100
                stepSize:    1
                unit:        "%"
            }

            SettingsDivider {}

            SettingsToggle {
                label:       "Background blur"
                description: PrefsService.backgroundOpacity < 100
                    ? "Blurs what is behind the frame."
                    : "Blurs what is behind the frame. Shows below 100 % opacity."
                prefKey:     "backgroundBlur"
            }
        }

        SettingsGroup {
            title: "Shape"

            SettingsDropdown {
                label:       "Bar style"
                description: PrefsService.barStyle === "pills"
                    ? "Floating capsules; popups grow out of them."
                    : PrefsService.barStyle === "bar"
                        ? "One full-width bar along the top, no borders."
                        : "Notches joined by the borders around the screen."
                prefKey:     "barStyle"
                options: [
                    { value: "frame", label: "Frame" },
                    { value: "bar",   label: "Bar"   },
                    { value: "pills", label: "Pills" }
                ]
            }

            SettingsDivider {}

            SettingsSlider {
                label:       "Border width"
                description: PrefsService.barStyle === "frame"
                    ? "Of the side and bottom borders. 0 hides them."
                    : "Only in the Frame style."
                prefKey:     "borderWidth"
                enabled:     PrefsService.barStyle === "frame"
                opacity:     enabled ? 1 : 0.45
                from:        0
                to:          16
                stepSize:    1
                unit:        " px"
            }

            SettingsDivider {}

            SettingsSlider {
                label:       "Corner roundness"
                description: "Frame corners, notches, popups and cards."
                prefKey:     "cornerRadius"
                from:        0
                to:          30
                stepSize:    1
                unit:        " px"
            }
        }
    }
}
