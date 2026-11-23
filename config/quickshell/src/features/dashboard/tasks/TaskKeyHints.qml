import QtQuick
// TaskKeyHints — the key legend under the task board (← → column, ↑ ↓ task…).
Row {
    spacing: 14

    Repeater {
        model: [
            { keys: ["←", "→"],      label: "column" },
            { keys: ["↑", "↓"],      label: "task"   },
            { keys: ["⇧", "←", "→"], label: "move"   },
            { keys: ["+"],           label: "add"    },
            { keys: ["Del"],         label: "delete" },
            { keys: ["⇧", "Del"],    label: "clear"  }
        ]
        delegate: Row {
            required property var modelData
            spacing: 3

            Repeater {
                model: modelData.keys
                delegate: Rectangle {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(16, keyT.implicitWidth + 8); height: 16; radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                    Text {
                        id: keyT; anchors.centerIn: parent
                        text: modelData; font.pixelSize: 9
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 2
                text: modelData.label; font.pixelSize: 9
                color: Qt.rgba(1, 1, 1, 0.30)
            }
        }
    }
}
