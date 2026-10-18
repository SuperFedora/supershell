import QtQuick

// Icon/text label used by every bar module. Click handlers are optional.
Item {
    id: root

    property string text: ""
    property color color: Theme.fg
    property bool bold: false
    // Every bar icon renders at one size: 16px at the default 14px font, and it scales with ui-scale.
    property int pixelSize: Theme.iconSize - 2
    property string tooltip: ""
    property var bar: null
    property bool vertical: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    implicitWidth: root.vertical ? Theme.barHeight : (label.implicitWidth + Theme.pad)
    implicitHeight: root.vertical ? Math.max(26, label.implicitHeight + 6) : Theme.barHeight

    Item {
        anchors.fill: parent
        scale: root.pressed ? 0.9 : (root.hovered ? 1.05 : 1)
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.dur(150); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: root.vertical ? 0 : 4
            anchors.bottomMargin: root.vertical ? 0 : 4
            anchors.leftMargin: root.vertical ? 4 : 0
            anchors.rightMargin: root.vertical ? 4 : 0
            radius: Theme.radiusSm
            color: mouse.containsMouse ? Theme.bgHover : "transparent"
        }

        Text {
            id: label
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            color: root.color
            font.family: Theme.font
            font.pixelSize: root.pixelSize
            font.bold: root.bold
        }
    }

    onTooltipChanged: if (root.hovered && root.bar && root.tooltip !== "") root.bar.setBarTip(root, root.tooltip, true)

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (root.bar && root.tooltip !== "") root.bar.setBarTip(root, root.tooltip, containsMouse)
        onClicked: e => { if (root.bar) root.bar.setBarTip(null, "", false); if (e.button === Qt.RightButton) root.rightClicked(); else root.clicked(); }
        onWheel: e => root.scrolled(e.angleDelta.y)
    }
}
