import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../shapes/"
import "../"

// DynamicSurface — one fullscreen, transparent layer surface per screen that
// draws the whole frame (top notches + borders) as a single morphing shape
// and hosts the bar content (#37, prototype phase #38).
//
// Space for tiled windows is reserved by StrutWindow, not here: this window
// ignores exclusive zones. Clicks outside the visible frame pass through to
// the windows below thanks to the input mask.
//
// Keyboard-focus spike: `qs ipc call surfaceSpike toggle` opens a test text
// field on the focused monitor. SYNAPSE_SURFACE_FOCUS picks how the surface
// asks for the keyboard (see ShellHost).
PanelWindow {
    id: root

    property bool   spikeOpen: false
    property string focusMode: "exclusive"   // exclusive | ondemand | grab
    signal spikeCloseRequested()

    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }
    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:     WlrLayer.Top
    WlrLayershell.namespace: "synapse-frame"
    WlrLayershell.keyboardFocus: {
        if (root.focusMode === "ondemand" || root.focusMode === "grab")
            return WlrKeyboardFocus.OnDemand
        return root.spikeOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    }

    // ── Frame geometry (same values TopBar uses today) ───────────────────────
    property real notchBottom: ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight
    Behavior on notchBottom {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    readonly property int lWidth: Math.max(
        Theme.lNotchMinWidth,
        Math.min(Theme.lNotchMaxWidth, leftContent.implicitWidth + Theme.notchPadding * 2))

    property int cWidth: Math.max(
        Theme.cNotchMinWidth,
        Math.min(Theme.cNotchMaxWidth, centerContent.implicitWidth + Theme.notchPadding * 2))
    Behavior on cWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    property int rWidth: Math.max(
        Theme.rNotchMinWidth,
        Math.min(Theme.rNotchMaxWidth, rightContent.implicitWidth + Theme.notchPadding * 2))
    Behavior on rWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    Binding { target: ShellState; property: "topBarLWidth"; value: root.lWidth }
    Binding { target: ShellState; property: "topBarCWidth"; value: root.cWidth }
    Binding { target: ShellState; property: "topBarRWidth"; value: root.rWidth }

    // ── Shape ────────────────────────────────────────────────────────────────
    SurfaceShape {
        anchors.fill: parent
        notchBottom:  root.notchBottom
        leftWidth:    root.lWidth
        centerWidth:  root.cWidth
        rightWidth:   root.rWidth
    }

    // ── Bar content (fades out in focus mode) ────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }

        Item {
            id: leftNotch
            x: 0; y: 0
            width:  root.lWidth
            height: Theme.notchHeight

            LeftContent {
                id: leftContent
                anchors.centerIn: parent
            }
        }

        Item {
            id: centerNotch
            x: (root.width - root.cWidth) / 2; y: 0
            width:  root.cWidth
            height: Theme.notchHeight

            CenterContent {
                id: centerContent
                anchors.centerIn: parent
            }
        }

        Item {
            id: rightNotch
            x: root.width - root.rWidth; y: 0
            width:  root.rWidth
            height: Theme.notchHeight
            clip:   true

            RightContent {
                id: rightContent
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin:    Theme.notchPadding
            }
        }
    }

    // ── Input mask: only the visible frame takes clicks ──────────────────────
    readonly property int _edge: Math.max(1, Theme.borderWidth)

    Item { id: maskTop;    x: 0; y: 0; width: root.width; height: root._edge }
    Item { id: maskLeft;   x: 0; y: 0; width: root._edge; height: root.height }
    Item { id: maskRight;  x: root.width - root._edge; y: 0; width: root._edge; height: root.height }
    Item { id: maskBottom; x: 0; y: root.height - root._edge; width: root.width; height: root._edge }
    Item { id: maskLeftNotch;   x: leftNotch.x;   y: 0; width: leftNotch.width;   height: root.notchBottom }
    Item { id: maskCenterNotch; x: centerNotch.x; y: 0; width: centerNotch.width; height: root.notchBottom }
    Item { id: maskRightNotch;  x: rightNotch.x;  y: 0; width: rightNotch.width;  height: root.notchBottom }
    Item { id: maskSpike; x: spike.x; y: spike.y
           width: root.spikeOpen ? spike.width : 0; height: root.spikeOpen ? spike.height : 0 }

    mask: Region {
        Region { item: maskTop;         intersection: Intersection.Combine }
        Region { item: maskLeft;        intersection: Intersection.Combine }
        Region { item: maskRight;       intersection: Intersection.Combine }
        Region { item: maskBottom;      intersection: Intersection.Combine }
        Region { item: maskLeftNotch;   intersection: Intersection.Combine }
        Region { item: maskCenterNotch; intersection: Intersection.Combine }
        Region { item: maskRightNotch;  intersection: Intersection.Combine }
        Region { item: maskSpike;       intersection: Intersection.Combine }
    }

    // ── Keyboard-focus spike (#38 §7) ────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active:  root.focusMode === "grab" && root.spikeOpen
        onCleared: if (root.spikeOpen) root.spikeCloseRequested()
    }

    Rectangle {
        id: spike
        visible: root.spikeOpen
        anchors.horizontalCenter: parent.horizontalCenter
        y:      Theme.notchHeight + 16
        width:  380
        height: 112
        radius: Theme.cornerRadius
        color:  Theme.background
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
        border.width: 1

        onVisibleChanged: if (visible) focusTimer.restart()

        // Give the compositor a moment to hand over the keyboard first.
        Timer {
            id: focusTimer
            interval: 50
            onTriggered: field.forceActiveFocus()
        }

        Column {
            anchors.fill:    parent
            anchors.margins: 14
            spacing: 8

            Text {
                text: "Focus spike · mode: " + root.focusMode + " · " + (root.screen ? root.screen.name : "")
                font.pixelSize: 11
                color: Theme.active
            }

            Rectangle {
                width:  parent.width
                height: 30
                radius: 8
                color:  Qt.rgba(1, 1, 1, 0.06)
                border.color: field.activeFocus
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.6)
                    : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: field
                    anchors.fill:    parent
                    anchors.margins: 8
                    color:           Theme.text
                    font.pixelSize:  12
                    clip:            true
                    onActiveFocusChanged: console.log("FocusSpike[" + root.focusMode + "]: field activeFocus=" + activeFocus)
                    onTextChanged:        console.log("FocusSpike[" + root.focusMode + "]: typed \"" + text + "\"")
                    Keys.onEscapePressed: root.spikeCloseRequested()
                }
            }

            Text {
                text: field.activeFocus ? "Field has focus: type, Esc closes" : "Field has NO focus"
                font.pixelSize: 10
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
            }
        }
    }
}
