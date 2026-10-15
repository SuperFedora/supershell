import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// StatusNotifier tray. Left click activates, right click opens the app menu.
Row {
    id: root
    property var bar: null
    spacing: 4

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: trayItem
            required property SystemTrayItem modelData
            width: 26
            height: Theme.barHeight - 8
            radius: Theme.radiusSm
            color: trayMouse.pressed ? Theme.bgAlt : (trayMouse.containsMouse ? Theme.bgHover : "transparent")
            border.width: trayMouse.pressed ? 1 : 0
            border.color: Theme.cyan

            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: trayItem.modelData.icon
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => {
                    if (e.button === Qt.MiddleButton)
                        trayItem.modelData.secondaryActivate();
                    else if (e.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                        if (trayItem.modelData.hasMenu) menuAnchor.open();
                    } else
                        trayItem.modelData.activate();
                }
            }
        }
    }
}
