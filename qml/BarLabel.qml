import QtQuick

// Icon/text label used by every bar module. Click handlers are optional.
Item {
    id: root

    property string text: ""
    property color color: Theme.fg
    property bool bold: false
    property int pixelSize: Theme.iconSize
    property string tooltip: ""
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    implicitWidth: label.implicitWidth + Theme.pad
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: Theme.radiusSm
        color: mouse.containsMouse ? Theme.bgHover : "transparent"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.color
        font.family: Theme.font
        font.pixelSize: root.pixelSize
        font.bold: root.bold
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: e => root.scrolled(e.angleDelta.y)
    }
}
