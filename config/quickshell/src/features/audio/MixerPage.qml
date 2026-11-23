import QtQuick
import qs.src.components.base
import qs.src.services.media
// MixerPage — the audio popup's Mixer page: pick the default output and input device.
PopupPage {
    id: root

    readonly property var sink:        AudioService.sink
    readonly property var source:      AudioService.source
    readonly property var sinkNodes:   AudioService.sinkNodes
    readonly property var sourceNodes: AudioService.sourceNodes
    function deviceName(node) { return AudioService.deviceName(node) }

    SectionLabel { text: "Output Devices" }

    Repeater {
        model: root.sinkNodes
        delegate: DeviceRow {
            width:     parent.width
            label:     root.deviceName(modelData)
            isDefault: (root.sink && root.sink.ready && modelData.name === root.sink.name) || false
            onClicked: AudioService.setDefaultSink(modelData)
        }
    }

    Text {
        visible:        root.sinkNodes.length === 0
        text:           "No output devices"
        color:          Qt.rgba(1,1,1,0.2)
        font.pixelSize: 11
        leftPadding:    10
    }

    Rectangle {
        width: parent.width; height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    SectionLabel { text: "Input Devices" }

    Repeater {
        model: root.sourceNodes
        delegate: DeviceRow {
            width:     parent.width
            label:     root.deviceName(modelData)
            isDefault: (root.source && root.source.ready && modelData.name === root.source.name) || false
            onClicked: AudioService.setDefaultSource(modelData)
        }
    }

    Text {
        visible:        root.sourceNodes.length === 0
        text:           "No input devices"
        color:          Qt.rgba(1,1,1,0.2)
        font.pixelSize: 11
        leftPadding:    10
    }
}
