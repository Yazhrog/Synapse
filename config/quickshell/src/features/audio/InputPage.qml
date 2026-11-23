import QtQuick
import qs.src.components.base
import qs.src.services.media
// InputPage — the audio popup's Input page: the default source's volume and mute.
PopupPage {
    id: root

    readonly property var source:      AudioService.source
    function deviceName(node) { return AudioService.deviceName(node) }

    ChannelColumn {
        width:  parent.width
        label:  (root.source && root.source.ready) ? root.deviceName(root.source) : "Input"
        icon:   (root.source && root.source.audio && root.source.audio.muted) ? "󰍭" : "󰍬"
        value:  (root.source && root.source.ready) ? root.source.audio.volume : 0
        muted:  (root.source && root.source.audio) ? root.source.audio.muted : false
        active: (root.source && root.source.ready) || false
        onVolumeChanged: function(v) { AudioService.setSourceVolume(v) }
        onMuteToggled: AudioService.toggleSourceMute()
    }
}
