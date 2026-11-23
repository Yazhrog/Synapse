import QtQuick
import qs.src.core.specs
import qs.src.services.media
import qs.src.services.time
import qs.src.state
import qs.src.theme
// NotchItems — the items of the center notch's carousel, by priority
// (ARCHITECTURE.md §5.7). CenterContent shows the active ones in this order
// and scrolls to one as its spec asks.
QtObject {
    readonly property list<NotchItemSpec> items: [
        // The focused app: always there.
        NotchItemSpec {
            key: "title"; priority: 0
            component: Component { NotchTitleItem {} }
        },
        // An MPRIS player exists (scrolled to from the title, also when it changes).
        NotchItemSpec {
            id: music
            key: "music"; priority: 10; inset: true; autoScroll: "fromTitle"
            active: MediaService.firstPlayer !== null
            component: Component { NotchMusicItem { artUrl: MediaService.firstPlayer?.trackArtUrl ?? "" } }
            property Connections _c: Connections {
                target: MediaService
                function onFirstPlayerChanged() { if (music.active) music.requestScroll(false) }
            }
        },
        // A timer is set; forced into view when it starts and at 30 s and
        // 10 s left, and blinks red under 30 s.
        NotchItemSpec {
            id: timer
            key: "timer"; priority: 20; autoScroll: "always"
            active: ClockService.timerStarted
            component: Component {
                NotchCountItem {
                    glyph:   "󰔟"
                    display: ClockService.timerDisplay
                    running: ClockService.timerRunning
                    urgent:  ClockService.timerRunning && ClockService.timerLeft <= 30 && ClockService.timerLeft > 0
                    onToggled: ClockService.toggleTimer()
                    onReset:   ClockService.resetTimer()
                }
            }
            property Connections _c: Connections {
                target: ClockService
                function onTimerRunningChanged() { if (ClockService.timerRunning) timer.requestScroll(false) }
                function onTimerLeftChanged() {
                    if (ClockService.timerRunning && (ClockService.timerLeft === 30 || ClockService.timerLeft === 10))
                        timer.requestScroll(true)
                }
            }
        },
        NotchItemSpec {
            key: "stopwatch"; priority: 30; autoScroll: "always"
            active: ClockService.swStarted
            component: Component {
                NotchCountItem {
                    glyph:   ""
                    display: ClockService.swDisplay
                    running: ClockService.swRunning
                    onToggled: ClockService.toggleStopwatch()
                    onReset:   ClockService.resetStopwatch()
                }
            }
        },
        // Screen recording always takes the carousel.
        NotchItemSpec {
            key: "record_setup"; priority: 40; inset: true; autoScroll: "always"
            active: ShellModes.screenRecord && !ScreenRecService.recording
            component: Component { NotchRecordSetupItem {} }
        },
        NotchItemSpec {
            key: "record_active"; priority: 50; inset: true; autoScroll: "always"
            active: ScreenRecService.recording
            component: Component { NotchRecordActiveItem {} }
        }
    ]
}
