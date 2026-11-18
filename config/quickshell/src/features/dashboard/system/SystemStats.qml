import QtQuick
import qs.src.core
import qs.src.services.system
import qs.src.theme
// The fastfetch system summary (SystemInfoService) as styled key/value rows.

Item {
    id: root

    // Parsed rows: [{key, value}], read again each time the view is shown.
    readonly property var rows: SystemInfoService.rows

    Lease { service: SystemInfoService; active: root.visible }

    // --- Rows ---
    Column {
        anchors {
            left:   parent.left
            right:  parent.right
            top:    parent.top
        }
        spacing: 0

        Repeater {
            model: root.rows

            delegate: Item {
                width:  parent.width
                height: 36

                // Subtle alternating background
                Rectangle {
                    anchors.fill: parent
                    radius:       Theme.cornerRadius
                    color:        index % 2 === 0
                                      ? Qt.rgba(1, 1, 1, 0.04)
                                      : "transparent"
                }

                // Key
                Text {
                    id: keyText
                    anchors {
                        left:           parent.left
                        leftMargin:     10
                        verticalCenter: parent.verticalCenter
                    }
                    text:            modelData.key
                    color:           Theme.active
                    font.pixelSize:  12
                    font.bold:       true
                    width:           90
                    elide:           Text.ElideRight
                }

                // Separator dot
                Text {
                    id: dot
                    anchors {
                        left:           keyText.right
                        verticalCenter: parent.verticalCenter
                    }
                    text:  "·"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 12
                }

                // Value
                Text {
                    anchors {
                        left:           dot.right
                        leftMargin:     6
                        right:          parent.right
                        rightMargin:    10
                        verticalCenter: parent.verticalCenter
                    }
                    text:            modelData.value
                    color:           Theme.text
                    font.pixelSize:  12
                    elide:           Text.ElideRight
                }
            }
        }
    }
}
