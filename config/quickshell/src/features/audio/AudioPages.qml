import QtQuick
import qs.src.core.specs
// AudioPages — the audio popup's pages, in tab order. The tab column, the
// page area, the popup's width, the toggle actions and Config → General's
// "Default audio tab" read it.
QtObject {
    readonly property list<PageSpec> pages: [
        PageSpec {
            key: "output"; label: "Output"; icon: "󰕾"; width: 200
            action: "audioOut-toggle"; actionLabel: "Audio: Output"
            component: Component { OutputPage {} }
        },
        PageSpec {
            key: "input"; label: "Input"; icon: "󰍬"; width: 200
            action: "audioIn-toggle"; actionLabel: "Audio: Input"
            component: Component { InputPage {} }
        },
        PageSpec {
            key: "mixer"; label: "Mixer"; icon: "󰾝"; width: 300
            action: "audioMix-toggle"; actionLabel: "Audio: Mixer"
            component: Component { MixerPage {} }
        }
    ]

    function widthOf(key: string): int {
        for (let i = 0; i < pages.length; i++) if (pages[i].key === key && pages[i].width > 0) return pages[i].width
        return 300
    }
}
