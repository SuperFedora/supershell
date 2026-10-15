import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Quick AI Console Overlay (`Super + \``): Centered WinUI 3 Header + Embedded Quake AI Terminal Cutout.
PanelWindow {
    id: pop
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(pop.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (pop.targetScreen === Quickshell.screens[0]) : (pop.hyprMon !== null && pop.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property int fullW: Math.max(1060, Math.min(1340, Math.round(pop.targetScreen.width * 0.76)))
    readonly property int fullH: Math.max(660, Math.min(840, Math.round(pop.targetScreen.height * 0.78)))

    visible: Status.superDeckOpen && pop.isTargetMon
    screen: pop.targetScreen
    color: "transparent"
    WlrLayershell.namespace: "superfedora-superdeck"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        item: bgArea
        Region { intersection: Intersection.Subtract; item: aiHole }
    }

    function runCmd(cmd) {
        Status.playSfx("confirm");
        Quickshell.execDetached(["sh", "-c", cmd]);
        Status.refresh();
    }

    MouseArea {
        id: bgArea
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Status.superDeckOpen = false
    }

    Item {
        id: aiHole
        x: box.x + 12
        y: box.y + 46
        width: pop.fullW - 24
        height: pop.fullH - 60
    }

    Rectangle {
        id: box
        width: pop.fullW
        height: pop.fullH
        anchors.centerIn: parent
        color: "transparent"
        radius: 8
        border.width: 1
        border.color: Theme.border
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 42; radius: 7; color: Theme.bg }
        Rectangle { x: 1; y: 42; width: 10; height: parent.height - 44; color: Theme.bg }
        Rectangle { x: parent.width - 11; y: 42; width: 10; height: parent.height - 44; color: Theme.bg }
        Rectangle { x: 1; y: parent.height - 12; width: parent.width - 2; height: 11; radius: 7; color: Theme.bg }
        Rectangle {
            x: 10; y: 44; width: parent.width - 20; height: parent.height - 56
            color: "transparent"; radius: 6; border.width: 1; border.color: Theme.blue
        }

        RowLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 12; topMargin: 7 }
            height: 30
            spacing: 8

            Text { text: "󰚩"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 }
            Text {
                text: "Quick AI Console  ·  " + (Status.aiAgentLabel || Status.aiAgent.toUpperCase())
                color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                visible: Status.ollamaEndpoint !== ""
                text: "󰒋 " + Status.ollamaEndpoint + " (" + Status.ollamaModel + ")"
                color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
            }

            Rectangle {
                implicitWidth: 106; implicitHeight: 28; radius: 5; color: cycM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "Switch harness"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                MouseArea { id: cycM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.nextAiAgent() }
            }
            Rectangle {
                implicitWidth: 112; implicitHeight: 28; radius: 5; color: mdlM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "Server & model"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                MouseArea { id: mdlM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("~/.config/hypr/scripts/quake-ai.sh prompt-ollama") }
            }
            Rectangle {
                implicitWidth: 112; implicitHeight: 28; radius: 5; color: setM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: setM.containsMouse ? Theme.blue : Theme.border
                Text { anchors.centerIn: parent; text: "󰒓 AI Settings"; color: setM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                MouseArea { id: setM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettings("ai") }
            }
            Rectangle {
                implicitWidth: 32; implicitHeight: 28; radius: 5; color: escM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: escM.containsMouse ? Theme.red : Theme.border
                Text { anchors.centerIn: parent; text: "󰅖"; color: escM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                MouseArea { id: escM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.superDeckOpen = false }
            }
        }
    }
}
