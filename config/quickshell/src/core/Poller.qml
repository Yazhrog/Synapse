import QtQuick

// Poller — runs `tick` now and then every `interval` ms while `running`.
//
//   Poller { interval: root.watched ? 2000 : 5000; running: true; onTick: root.poll() }
//
// A Timer that also fires when it starts, named for what services use it for.
Timer {
    signal tick()
    repeat: true
    triggeredOnStart: true
    onTriggered: tick()
}
