import QtQuick
import qs.src.actions
import qs.src.core.specs
import qs.src.services.desktop
import qs.src.services.media
import qs.src.state
// ActionManifest — every action of the shell (ARCHITECTURE.md §5.6, §10.7).
//
// The popups' toggle actions are generated from the popup manifest (a
// popup's `action`, and each page's PageSpec.action); the rest are listed
// below. App hands `actions` to the Actions registry. A new action with a
// default keybind also needs its line in config/keybind-defaults.json
// (tests/contracts.qml checks both key sets agree).
QtObject {
    id: root

    // app/PopupManifest.qml's popups
    property var popups: []

    readonly property list<Action> own: [
        Action {
            key: "focus-toggle"; label: "Focus Mode"; group: "Quick Settings"
            run: () => FocusModeService.toggle()
        },
        Action {
            key: "screenrec-on"; label: "Screen Record"; group: "Quick Settings"
            // Stops a recording, cancels the setup, or opens the setup.
            run: () => {
                if (ScreenRecService.recording)  ScreenRecService.stopRecording()
                else if (ShellModes.screenRecord) ScreenRecService.cancelSetup()
                else {
                    Popups.closeAll()
                    ScreenRecService.openSetup()
                }
            }
        }
    ]

    readonly property var generated: {
        const out = []
        for (let i = 0; i < popups.length; i++) {
            const spec = popups[i], popup = spec.key
            if (spec.action !== "")
                out.push({ key: spec.action, label: spec.actionLabel, group: spec.actionGroup,
                           run: () => Popups.toggle(popup) })
            const pages = spec.pages ?? []
            for (let j = 0; j < pages.length; j++) {
                const page = pages[j], pageKey = page.key
                if (page.action !== "")
                    out.push({ key: page.action, label: page.actionLabel, group: spec.actionGroup,
                               run: () => Popups.togglePage(popup, pageKey) })
            }
        }
        return out
    }

    readonly property var actions: generated.concat(Array.from(own))
}
