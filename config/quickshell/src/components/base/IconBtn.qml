import QtQuick
import qs.src.theme
Rectangle {
    id: root
    width: 24
    height: 24
    radius: 4
    
    // 1. Correct: referencing the ID 'hover' directly works here
    color: hover.hovered ? Theme.color.accent : "transparent"
    
    property string text: "" 
    property color textColor: Theme.color.text
    signal clicked()

    Text {
        anchors.centerIn: parent
        text: root.text
        
        // 2. FIX: Changed 'root.hoverHandler.hovered' to 'hover.hovered'
        color: hover.hovered ? Theme.color.background : root.textColor
        
        font.pixelSize: 14
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
