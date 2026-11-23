import QtQuick
import qs.src.components.base
import qs.src.services.media
// OutputPage — the audio popup's Output page: the default sink's volume and mute.
PopupPage {
    id: root

    readonly property var sink:        AudioService.sink
    function deviceName(node) { return AudioService.deviceName(node) }

    ChannelColumn {
        width:  parent.width
        label:  (root.sink && root.sink.ready) ? root.deviceName(root.sink) : "Output"
        icon: {
            if (!root.sink || !root.sink.ready)           return "󰕾"
            if (root.sink.audio.muted)        return "󰖁"
            if (root.sink.audio.volume > 0.6) return "󰕾"
            if (root.sink.audio.volume > 0.2) return "󰖀"
            return "󰕿"
        }
        value:  (root.sink && root.sink.ready) ? root.sink.audio.volume : 0
        muted:  (root.sink && root.sink.audio) ? root.sink.audio.muted : false
        active: (root.sink && root.sink.ready) || false
        onVolumeChanged: function(v) { AudioService.setVolume(v) }
        onMuteToggled: AudioService.toggleMute()
    }
}
