//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "panels"

// Entry point: SuperBar + Launchpad AppGrid + SettingsWindow + ForgeWindow + Notifications + OSD + LockScreen.
ShellRoot {
    id: root
    property bool barVisible: true

    Variants { model: root.barVisible ? Quickshell.screens : []; SuperBar { edge: "top" } }
    Variants { model: root.barVisible ? Quickshell.screens : []; SuperBar { edge: "bottom" } }
    Variants { model: root.barVisible ? Quickshell.screens : []; SuperBar { edge: "left" } }
    Variants { model: root.barVisible ? Quickshell.screens : []; SuperBar { edge: "right" } }
    Variants { model: root.barVisible ? Quickshell.screens : []; ForgeRail {} }

    SettingsWindow {}
    ForgeWindow {}
    SuperBarWindow {}
    AppGrid {}
    Notifications {}
    LockScreen {}

    // Right-side notification drawer opened by the top-bar bell or `qs ipc call notifications toggle`.
    PanelWindow {
        id: drawerWin
        property var targetScreen: Quickshell.screens[0]
        readonly property int drawerW: 380
        readonly property bool open: Status.notifDrawerOpen && !Status.appGridOpen && !Status.settingsOpen && !Status.sessionLocked && !Status.forgeGuiOpen
        property real openProgress: drawerWin.open ? 1.0 : 0.0
        Behavior on openProgress { NumberAnimation { duration: Theme.dur(drawerWin.open ? 280 : 190); easing.type: Easing.BezierSpline; easing.bezierCurve: drawerWin.open ? Theme.curveDecel : Theme.curveStandard } }
        readonly property int unread: Status.notifHistory.length
        readonly property int fSz: Theme.radius
        function close() { Status.notifDrawerOpen = false; if (Status.notifAction) Status.notifAction("setCenterOpen", false); }

        screen: drawerWin.targetScreen; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        implicitWidth: drawerWin.targetScreen ? drawerWin.targetScreen.width : 1920
        implicitHeight: drawerWin.targetScreen ? drawerWin.targetScreen.height : 1080
        WlrLayershell.namespace: "superfedora-notif-drawer"; WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: drawerWin.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        visible: drawerWin.open || drawerWin.openProgress > 0.005
        onOpenChanged: if (drawerWin.open) keyCatcher.forceActiveFocus()

        MouseArea { anchors.fill: parent; enabled: drawerWin.open; onPressed: { drawerWin.close(); Status.playSfx("click"); } }
        Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: drawerBody.left; topMargin: Theme.barHeight } color: Qt.rgba(0, 0, 0, 0.18 * drawerWin.openProgress) }
        ConcaveFillet { visible: drawerWin.fSz > 0; opacity: Math.min(1, drawerWin.openProgress * 1.6); x: drawerBody.x - size + 2; y: Theme.barHeight; size: drawerWin.fSz; concave: true; corner: "TopRight"; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97); strokeWidth: 2; strokeColor: Theme.blue; z: 5 }

        Rectangle {
            id: drawerBody
            x: parent.width - drawerWin.drawerW * Math.max(0, Math.min(1, drawerWin.openProgress))
            y: Theme.barHeight; width: drawerWin.drawerW; height: parent.height - Theme.barHeight; clip: true
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97); border.width: 0
            MouseArea { anchors.fill: parent }
            Rectangle { width: 2; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: Math.max(0, drawerWin.fSz - 2); color: Theme.blue; z: 5 }
            Rectangle { visible: !Status.barFlushOn("right"); width: 2; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; color: Theme.blue; z: 5 }
            Rectangle { visible: !Status.barFlushOn("bottom"); height: 2; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; color: Theme.blue; z: 5 }

            Rectangle {
                id: drawerHead
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 2; rightMargin: Status.barFlushOn("right") ? 0 : 2; topMargin: 0 }
                implicitHeight: 44; color: Theme.bgAlt
                Rectangle { height: 1; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; color: Theme.border }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8
                    Text { Layout.fillWidth: true; text: "Notifications (" + drawerWin.unread + ")"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight }
                    Rectangle {
                        visible: drawerWin.unread > 0; implicitWidth: clrTxt.implicitWidth + 14; implicitHeight: 22; radius: Theme.radiusSm
                        color: clrM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clrM.containsMouse ? Theme.red : Theme.border
                        Text { id: clrTxt; anchors.centerIn: parent; text: "Clear all"; color: clrM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                        MouseArea { id: clrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction("clearAll"); Status.playSfx("click"); } }
                    }
                }
            }
            NotificationList {
                anchors { left: parent.left; right: parent.right; top: drawerHead.bottom; bottom: drawerFoot.top; margins: 10 }
                chrome: false; grouped: true; actions: true; source: Status.notifHistory
            }
            Rectangle {
                id: drawerFoot; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } implicitHeight: 26; color: Theme.bgAlt
                Rectangle { height: 1; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; color: Theme.border }
                Text { anchors.centerIn: parent; text: Qt.formatDateTime(new Date(), "dddd, MMMM d") + "   ·   " + (Status.localTz || "Local"); color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4 }
            }
        }
        Item { id: keyCatcher; anchors.fill: parent; focus: true; Keys.onEscapePressed: event => { drawerWin.close(); Status.playSfx("click"); event.accepted = true; } }
    }

    // 16-Bit SNES Animated On-Screen Display (OSD) for Volume, Mute & Brightness changes.
    Scope {
        id: osd
        property bool shown: false
        property string mode: "volume"
        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property bool audioReady: sink !== null && sink.audio !== null
        readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol
        readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
        readonly property real bri: Status.brightness
        readonly property real activeVal: osd.mode === "brightness" ? osd.bri : osd.vol
        property bool _armed: false
        onVolChanged: if (osd.audioReady && !Status.settingsOpen) show("volume")
        onMutedChanged: if (osd.audioReady && !Status.settingsOpen) show("volume")
        onBriChanged: if (!Status.settingsOpen) show("brightness")
        function show(kind) { if (!_armed) return; osd.mode = kind || "volume"; osd.shown = true; Status.playSfx("volume"); osdHide.restart(); }
        Timer { interval: 1500; running: true; onTriggered: osd._armed = true }
        Timer { id: osdHide; interval: 1350; onTriggered: osd.shown = false }
        IpcHandler { target: "osd"; function volume(): void { osd._armed = true; osd.show("volume"); } function brightness(): void { osd._armed = true; osd.show("brightness"); } }

        PanelWindow {
            visible: osd.shown; screen: Quickshell.screens[0]; color: "transparent"
            anchors.bottom: true; margins.bottom: 84; exclusionMode: ExclusionMode.Ignore
            implicitWidth: 296; implicitHeight: 54
            Rectangle {
                anchors.fill: parent; color: Theme.bg; radius: Theme.radius; border.width: 2
                border.color: osd.mode === "brightness" ? Theme.yellow : Theme.blue
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 10
                    Text {
                        text: osd.mode === "brightness" ? (osd.bri >= 0.66 ? "󰃠" : osd.bri >= 0.33 ? "󰃟" : "󰃞") : (osd.muted ? "󰝟" : osd.vol >= 0.66 ? "󰕾" : osd.vol >= 0.33 ? "󰖀" : "󰕿")
                        color: osd.mode === "brightness" ? Theme.yellow : (osd.muted ? Theme.muted : Theme.cyan)
                        font.family: Theme.font; font.pixelSize: 20
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: osd.mode === "brightness" ? "DISPLAY LUMEN // SYNTH" : (osd.muted ? "AUDIO MUTED // SYNTH" : "MASTER AUDIO // SYNTH"); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: Math.round(osd.activeVal * 100) + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 2
                            Repeater {
                                model: 16
                                Rectangle {
                                    required property int index
                                    Layout.fillWidth: true; height: 8; radius: Theme.radiusSm > 0 ? 2 : 0
                                    readonly property bool lit: (index + 1) / 16.0 <= osd.activeVal + 0.02
                                    color: !lit ? Theme.bgAlt : (osd.mode === "brightness" ? Theme.yellow : (osd.muted ? Theme.muted : (index >= 13 ? Theme.cyan : Theme.blue)))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function gui(): void { Status.toggleSuperBarGui(); }
        function open(tab: string): void { Status.openSuperBarGui(tab); }
        function close(): void { Status.superbarGuiOpen = false; }
    }
    IpcHandler {
        target: "superbar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function gui(): void { Status.toggleSuperBarGui(); }
        function open(tab: string): void { Status.openSuperBarGui(tab); }
        function close(): void { Status.superbarGuiOpen = false; }
    }
}
