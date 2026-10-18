import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

// ForgeRail — left-edge SuperForge progress rail, one instance per screen (shell.qml Variants).
// The left edge configured with hideMode 'activity' + widgets ['forge'] hands off to this panel:
// SuperBar.qml skips rendering that edge, ForgeRail owns the 7px strip, the hover expansion, the
// bottom→top fill over the whole queue and the batch popover (moved here from the bar chip).
// Queue math is identical to the forge chip in BarWidgets.qml: done = forgeDone.length, and
// total = done + 1 + forgeQueue.length while busy.
PanelWindow {
    id: rail
    required property var modelData; property var targetScreen: rail.modelData || Quickshell.screens[0]
    property bool flash: false

    readonly property var edgeCfg: Status.barEdgeConfig("left")
    readonly property bool railOn: (Status.forgeBusy || Status.forgeRecent) && Boolean(edgeCfg && edgeCfg.enabled !== false)
        && Array.isArray(edgeCfg.widgets) && edgeCfg.widgets.indexOf("forge") >= 0
    readonly property int railW: 30
    readonly property bool open: Status.forgeShown
    readonly property bool hover: hoverH.hovered || rail.open
    readonly property bool error: Status.forgeState === "error"
    readonly property bool good: Status.forgeState === "ok" || Status.forgeState === "done"
    readonly property int cur: Status.forgeBusy ? (Status.forgeDone.length + 1) : Math.max(1, Status.forgeDone.length)
    readonly property int total: Status.forgeBusy ? (Status.forgeDone.length + 1 + Status.forgeQueue.length) : Math.max(1, Status.forgeDone.length + Status.forgeQueue.length)
    readonly property real frac: Status.forgeBusy ? Math.max(0, Math.min(1, (Status.forgeDone.length + Math.max(0, Math.min(100, Status.forgePct)) / 100) / Math.max(1, rail.total))) : 1
    // Building and done share one Theme.blue accent; only a hard error escalates to Theme.red.
    readonly property color accent: rail.error ? Theme.red : Theme.blue

    screen: rail.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "superfedora-forge-rail"; WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true }
    implicitWidth: rail.railW
    implicitHeight: rail.targetScreen ? rail.targetScreen.height : 0
    visible: rail.railOn
    onVisibleChanged: if (!visible) Status.forgeShown = false

    // Strip: 7px collapsed, ~30px on hover. Fill grows bottom→top, one notch per queued item.
    Rectangle {
        id: body
        width: rail.hover ? rail.railW : 7
        height: parent.height
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
        clip: true
        Behavior on width { NumberAnimation { duration: Theme.dur(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }

        Rectangle {
            id: fill; width: parent.width; height: Math.round(parent.height * rail.frac); anchors.bottom: parent.bottom
            color: rail.accent; opacity: rail.flash ? 0.28 : 0.92
            Behavior on height { NumberAnimation { duration: Theme.dur(300); easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.dur(150); easing.type: Easing.OutCubic } }
        }
        // Wave crest riding the top of the rising fill — a sine crest whose phase only advances while
        // the forge is actually busy, so an idle rail never burns frames on a Canvas repaint.
        Canvas {
            id: crest
            anchors.bottom: fill.top; anchors.left: fill.left; anchors.right: fill.right
            height: 5; visible: Status.forgeBusy && Theme.animEnabled
            property real phase: 0
            onPhaseChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"), h = crest.height, w = crest.width;
                ctx.clearRect(0, 0, w, h);
                ctx.beginPath();
                ctx.moveTo(0, h);
                for (let x = 0; x <= w; x += 2) ctx.lineTo(x, h / 2 + Math.sin((x / 9) + crest.phase) * (h / 2 - 0.5));
                ctx.lineTo(w, h);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.92);
                ctx.fill();
            }
            Timer { running: Status.forgeBusy && Theme.animEnabled; repeat: true; interval: 33; onTriggered: crest.phase += 0.28 }
        }
        Repeater {
            model: rail.total > 1 ? rail.total - 1 : 0
            Rectangle {
                required property int index
                width: body.width; height: 1; color: Qt.rgba(0, 0, 0, 0.45)
                y: body.height - ((index + 1) / rail.total) * body.height
            }
        }
        Row {
            anchors.centerIn: parent; rotation: -90; spacing: 5
            Text { text: "󰙪 " + (Status.forgeTarget || "forging").toUpperCase(); color: rail.accent; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
            Text { text: Status.forgePct + "%"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
            Rectangle { implicitWidth: rBadge.implicitWidth + 8; implicitHeight: 15; radius: 3; color: Theme.blue; Text { id: rBadge; anchors.centerIn: parent; text: rail.cur + "/" + rail.total; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.bold: true } }
        }
        HoverHandler { id: hoverH }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { if (rail.error) { Status.dismissForgeBanner(); Status.forgeShown = false; } else { Status.forgeShown = !Status.forgeShown; } Status.playSfx("click"); }
        }
    }
    // One pulse when the build completes (ok/done), then the rail slides away when forgeRecent expires.
    Timer { id: pulseTimer; interval: 160; onTriggered: rail.flash = false }
    Connections { target: Status; function onForgeStateChanged() { if (rail.good) { rail.flash = true; pulseTimer.restart(); } } }

    // SuperForge batch popover (opened by the rail). Anchored beside the rail, vertically centred.
    PanelWindow {
        id: forgePopup
        visible: rail.open && rail.railOn && !Status.appGridOpen
        screen: rail.targetScreen; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "superfedora-forge-queue"; WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        margins.top: Math.max(8, Math.round(((rail.targetScreen ? rail.targetScreen.height : 0) - forgePopCol.implicitHeight - 22) / 2))
        margins.left: rail.railW + 6
        implicitWidth: 336; implicitHeight: forgePopCol.implicitHeight + 22
        Rectangle {
            anchors.fill: parent; radius: Theme.radius
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97); border.width: 2; border.color: rail.accent
            ColumnLayout {
                id: forgePopCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 11 } spacing: 6
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: "󰙪  FORGE: " + (Status.forgeTarget || "working").toUpperCase(); color: rail.accent; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: Status.forgePct + "%"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    Rectangle { width: Math.round((parent.width - 2) * Math.max(0, Math.min(100, Status.forgePct)) / 100); height: 4; x: 1; y: 1; radius: 2; color: rail.accent; Behavior on width { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } } }
                }
                Text { text: Status.forgeStep; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: Status.forgeLogLine !== ""; text: Status.forgeLogLine; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; elide: Text.ElideRight; Layout.fillWidth: true }
                Rectangle { visible: Status.forgeDone.length > 0 || Status.forgeQueue.length > 0; Layout.fillWidth: true; height: 1; color: Theme.border }
                Text { visible: Status.forgeDone.length > 0 || Status.forgeQueue.length > 0; text: "BATCH QUEUE (" + Status.forgeDone.length + " DONE · " + Status.forgeQueue.length + " UP NEXT)"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                Repeater {
                    model: Status.forgeDone.slice(-3)
                    Rectangle {
                        id: fdRow; required property string modelData; Layout.fillWidth: true; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                        RowLayout { anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6; Text { text: "󰄬"; color: Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } Text { text: fdRow.modelData; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: "FORGED"; color: Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.bold: true } }
                    }
                }
                Repeater {
                    model: Status.forgeQueue.slice(0, 5)
                    Rectangle {
                        id: fqRow; required property string modelData; required property int index; Layout.fillWidth: true; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 6 } spacing: 6
                            Text { text: "#" + (Status.forgeDone.length + fqRow.index + 2); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                            Text { text: fqRow.modelData; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: "QUEUED"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.bold: true }
                            Text { text: "[×]"; color: fqRmM.containsMouse ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true; MouseArea { id: fqRmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeForgeQueueItem(fqRow.modelData) } }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Rectangle { Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: fAddM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Theme.blue; Text { anchors.centerIn: parent; text: "+ Queue Mock"; color: fAddM.containsMouse ? Theme.bg : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: fAddM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.runMockForge("helix") } }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: fSetM.containsMouse ? Theme.cyan : Theme.bgAlt; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "Open SuperForge"; color: fSetM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: fSetM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.forgeShown = false; Status.openForgeGui(""); } } }
                    Rectangle { implicitWidth: 74; implicitHeight: 26; radius: Theme.radiusSm; color: fStpM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: Status.forgeBusy ? "Stop All" : "Dismiss"; color: fStpM.containsMouse ? Theme.bg : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: fStpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.forgeShown = false; if (Status.forgeBusy) Status.stopForge(); else Status.dismissForgeBanner(); } } }
                }
            }
        }
    }
}
