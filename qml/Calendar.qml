import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Clock & Calendar Popover: mode === "date" (Month Calendar) or mode === "time" (Clock & World Clocks).
// Smoothly expands out of the bar beneath the clicked clock widget (`anchorX`) and retracts back on close.
PanelWindow {
    id: cal
    property string mode: ""; property string renderMode: "date"; property string barEdge: "top"
    property real openProgress: cal.mode !== "" ? 1.0 : 0.0
    Behavior on openProgress { NumberAnimation { duration: Theme.dur(cal.mode !== "" ? 300 : 200); easing.type: Easing.BezierSpline; easing.bezierCurve: cal.mode !== "" ? Theme.curveDecel : Theme.curveStandard } }
    readonly property string m: cal.mode !== "" ? cal.mode : cal.renderMode
    property real anchorX: -1; property real anchorY: -1
    Behavior on anchorX { enabled: cal.openProgress > 0.02 && cal.openProgress < 0.99 || cal.mode !== ""; NumberAnimation { duration: Theme.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
    property var targetScreen: Quickshell.screens[0]
    property int viewYear: new Date().getFullYear(); property int viewMonth: new Date().getMonth()
    readonly property bool isVert: cal.barEdge === "left" || cal.barEdge === "right"

    function close() { cal.mode = ""; }
    function resetToToday() { const now = new Date(); cal.viewYear = now.getFullYear(); cal.viewMonth = now.getMonth(); }
    function stepMonth(delta) { let m = cal.viewMonth + delta, y = cal.viewYear; if (m < 0) { m = 11; y -= 1; } else if (m > 11) { m = 0; y += 1; } cal.viewMonth = m; cal.viewYear = y; }
    function runShell(cmd, closeAfter) { if (closeAfter) cal.close(); Quickshell.execDetached(["sh", "-c", cmd]); }

    readonly property int bTop: cal.barEdge === "top" ? Theme.barHeight : 0
    readonly property int bBot: cal.barEdge === "bottom" ? Theme.barHeight : 0
    readonly property int bLeft: cal.barEdge === "left" ? Theme.barHeight : 0
    readonly property int bRight: cal.barEdge === "right" ? Theme.barHeight : 0
    property var barClick: null
    visible: cal.mode !== "" || cal.openProgress > 0.005; screen: cal.targetScreen; color: "transparent"; exclusionMode: ExclusionMode.Ignore
    implicitWidth: cal.targetScreen ? cal.targetScreen.width : 1920
    implicitHeight: cal.targetScreen ? cal.targetScreen.height : 1080
    WlrLayershell.namespace: "superfedora-calendar-popup"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: cal.mode !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    onModeChanged: if (cal.mode !== "") { cal.renderMode = cal.mode; keyCatcher.forceActiveFocus(); }

    readonly property var cells: {
        const out = [], firstDow = new Date(cal.viewYear, cal.viewMonth, 1).getDay();
        const daysInMonth = new Date(cal.viewYear, cal.viewMonth + 1, 0).getDate(), daysInPrev = new Date(cal.viewYear, cal.viewMonth, 0).getDate();
        const now = new Date(), todayY = now.getFullYear(), todayM = now.getMonth(), todayD = now.getDate();
        for (let i = 0; i < 42; i++) {
            const offset = i - firstDow + 1;
            let d = offset, inMonth = true, isToday = false;
            if (offset < 1) { d = daysInPrev + offset; inMonth = false; }
            else if (offset > daysInMonth) { d = offset - daysInMonth; inMonth = false; }
            else { isToday = (cal.viewYear === todayY && cal.viewMonth === todayM && d === todayD); }
            out.push({ day: d, inMonth: inMonth, isToday: isToday });
        }
        return out;
    }

    readonly property var timeRows: [
        { header: "TIME FORMAT" },
        { label: Status.clock24h ? "[*] 24-Hour Time (14:30)" : "[ ] 24-Hour Time (14:30)", act: "set24" },
        { label: !Status.clock24h ? "[*] 12-Hour Time (2:30 PM)" : "[ ] 12-Hour Time (2:30 PM)", act: "set12" },
        { label: (Status.clockSeconds ? "[*] " : "[ ] ") + "Show Seconds", act: "toggleSec" },
        { header: "TIME ZONE" },
        { info: "Active: " + Status.localTz },
        { label: (Status.autoTz ? "[*] " : "[ ] ") + "Auto Time Zone (NTP)",
          cmd: "gsettings set org.gnome.desktop.datetime automatic-timezone " + (!Status.autoTz) + "; timedatectl set-ntp " + (!Status.autoTz ? "true" : "false") },
        { label: "Change System Time Zone...",
          cmd: "tz=$(timedatectl list-timezones | fuzzel --dmenu --prompt 'System TimeZone > ' --width 42) && [ -n \"$tz\" ] && timedatectl set-timezone \"$tz\"", close: true },
        { header: "WORLD CLOCKS (CLICK TO REMOVE)" }
    ]

    // Click-away backdrop: clicking anywhere outside the popup card retracts it back into the bar.
    MouseArea { anchors.fill: parent; enabled: cal.mode !== ""; onPressed: e => { if (cal.barClick && ((cal.barEdge === "top" && e.y < Theme.barHeight) || (cal.barEdge === "bottom" && e.y >= parent.height - Theme.barHeight) || (cal.barEdge === "left" && e.x < Theme.barHeight) || (cal.barEdge === "right" && e.x >= parent.width - Theme.barHeight))) { cal.barClick(e.x, e.y, e.button); } else { cal.close(); Status.playSfx("click"); } } }

    readonly property int fSz: Theme.radius
    readonly property real popMid: cal.isVert ? (clipWrap.y + clipWrap.height / 2) : (clipWrap.x + clipWrap.width / 2)
    readonly property real popHalf: ((cal.isVert ? clipWrap.height : clipWrap.width) / 2 + cal.fSz) * Math.min(1, cal.openProgress * 1.15)
    readonly property real popStart: cal.popMid - cal.popHalf; readonly property real popEnd: cal.popMid + cal.popHalf
    ConcaveFillet { visible: !cal.isVert && cal.fSz > 0; opacity: Math.min(1, cal.openProgress * 1.6); x: clipWrap.x - size + 2; y: cal.barEdge === "top" ? cal.bTop : (parent.height - cal.bBot - size); size: cal.fSz; concave: true; corner: cal.barEdge === "top" ? "TopRight" : "BottomRight"; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98); strokeWidth: 2; strokeColor: Theme.blue; z: 5 }
    ConcaveFillet { visible: !cal.isVert && cal.fSz > 0; opacity: Math.min(1, cal.openProgress * 1.6); x: clipWrap.x + clipWrap.width - 2; y: cal.barEdge === "top" ? cal.bTop : (parent.height - cal.bBot - size); size: cal.fSz; concave: true; corner: cal.barEdge === "top" ? "TopLeft" : "BottomLeft"; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98); strokeWidth: 2; strokeColor: Theme.blue; z: 5 }
    Item {
        id: clipWrap
        readonly property int fullW: 360; readonly property int fullH: 320
        width: cal.isVert ? (fullW * Math.max(0, Math.min(1, cal.openProgress))) : fullW; height: cal.isVert ? fullH : (fullH * Math.max(0, Math.min(1, cal.openProgress)))
        x: cal.barEdge === "left" ? cal.bLeft : (cal.barEdge === "right" ? (parent.width - cal.bRight - width) : (cal.anchorX >= 0 ? Math.max(12, Math.min(parent.width - fullW - 12, cal.anchorX - fullW / 2)) : ((parent.width - fullW) / 2)))
        y: cal.barEdge === "top" ? cal.bTop : (cal.barEdge === "bottom" ? (parent.height - cal.bBot - height) : (cal.anchorY >= 0 ? Math.max(12, Math.min(parent.height - fullH - 12, cal.anchorY - fullH / 2)) : ((parent.height - fullH) / 2)))
        clip: true
        Rectangle {
            id: box
            width: clipWrap.fullW + (cal.isVert ? Theme.radius + 4 : 0); height: clipWrap.fullH + (cal.isVert ? 0 : Theme.radius + 4)
            x: cal.barEdge === "left" ? (clipWrap.width - width) : 0; y: cal.barEdge === "top" ? (clipWrap.height - height) : 0
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98); radius: Theme.radius; border.width: 2; border.color: Theme.blue
            MouseArea { anchors.fill: parent }
            Rectangle { visible: !cal.isVert && cal.fSz > 0; x: 0; y: cal.barEdge === "top" ? (box.height - clipWrap.height) : (clipWrap.height - cal.fSz); width: box.width; height: cal.fSz; color: box.color; z: 2 }

            // ---------------- Date Mode: Month Calendar ----------------
            ColumnLayout {
                id: dateCol; opacity: Math.min(1, cal.openProgress * 1.25)
                visible: cal.m === "date"
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: cal.barEdge === "top" ? (Theme.radius + 16) : 12 }
                spacing: 8

            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: Theme.radiusSm
                    color: prevM.containsMouse ? Theme.bgHover : "transparent"
                    Text { anchors.centerIn: parent; text: "◂"; color: prevM.containsMouse ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: prevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.stepMonth(-1) }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm
                    color: todayM.containsMouse ? Theme.bgHover : "transparent"
                    Text { anchors.centerIn: parent; text: Qt.formatDate(new Date(cal.viewYear, cal.viewMonth, 1), "MMMM yyyy"); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: todayM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.resetToToday() }
                }
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: Theme.radiusSm
                    color: nextM.containsMouse ? Theme.bgHover : "transparent"
                    Text { anchors.centerIn: parent; text: "▸"; color: nextM.containsMouse ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: nextM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.stepMonth(1) }
                }
            }

            GridLayout {
                Layout.fillWidth: true; columns: 7; columnSpacing: 2; rowSpacing: 2

                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Item {
                        required property string modelData
                        Layout.fillWidth: true; implicitHeight: 24
                        Text {
                            anchors.centerIn: parent; text: parent.modelData; color: Theme.blue
                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true
                        }
                    }
                }

                Repeater {
                    model: cal.cells
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm
                        color: modelData.isToday ? Theme.blue : "transparent"
                        Text {
                            anchors.centerIn: parent; text: String(parent.modelData.day)
                            color: parent.modelData.isToday ? Theme.bg : (parent.modelData.inMonth ? Theme.fg : Theme.muted)
                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: parent.modelData.isToday
                        }
                    }
                }
            }
        }

        // ---------------- Time Mode: Clock Settings & World Clocks ----------------
        ColumnLayout {
            id: timeCol; opacity: Math.min(1, cal.openProgress * 1.25); visible: cal.m === "time"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: cal.barEdge === "top" ? (Theme.radius + 16) : 12 }
            spacing: 4

            Repeater {
                model: cal.timeRows
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 2

                    Text {
                        visible: parent.modelData.header !== undefined; text: parent.modelData.header || ""
                        color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                    }
                    Text {
                        visible: parent.modelData.info !== undefined; text: parent.modelData.info || ""
                        color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1
                    }
                    Rectangle {
                        visible: parent.modelData.label !== undefined
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                        color: tmMouse.containsMouse ? Theme.bgHover : "transparent"
                        Text {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 6 }
                            text: parent.parent.modelData.label || ""; color: Theme.fg
                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: tmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = parent.parent.modelData;
                                if (d.act === "set24") Status.saveClockPrefs(true, Status.clockSeconds);
                                else if (d.act === "set12") Status.saveClockPrefs(false, Status.clockSeconds);
                                else if (d.act === "toggleSec") Status.saveClockPrefs(Status.clock24h, !Status.clockSeconds);
                                else if (d.cmd) { cal.runShell(d.cmd, d.close === true); Status.refresh(); }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Status.worldClocks
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                    color: wcMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        Text {
                            Layout.fillWidth: true; text: parent.parent.modelData.tz
                            color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideMiddle
                        }
                        Text {
                            text: wcMouse.containsMouse ? "Remove [x]" : parent.parent.modelData.time
                            color: wcMouse.containsMouse ? Theme.red : Theme.blue
                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                        }
                    }
                    MouseArea {
                        id: wcMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const z = parent.modelData.tz;
                            cal.runShell("grep -Fxv '" + z + "' ~/.config/superfedora/world-clocks.txt > ~/.config/superfedora/world-clocks.tmp && mv ~/.config/superfedora/world-clocks.tmp ~/.config/superfedora/world-clocks.txt", false);
                            Status.refresh();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                color: addWcM.containsMouse ? Theme.bgHover : "transparent"
                Text { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 6 } text: "+ Add World Clock..."; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                MouseArea { id: addWcM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { cal.runShell("tz=$(timedatectl list-timezones | fuzzel --dmenu --prompt 'Add World Clock > ' --width 42) && [ -n \"$tz\" ] && (grep -Fxq \"$tz\" ~/.config/superfedora/world-clocks.txt || echo \"$tz\" >> ~/.config/superfedora/world-clocks.txt)", true); Status.refresh(); } }
            }
        }

        // ---------------- Bottom "More settings ›" Footer -> SuperSettings ----------------
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            implicitHeight: 32; radius: Theme.radiusSm; color: calMoreM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: calMoreM.containsMouse ? Theme.blue : Theme.border
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 8
                Text { text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                Text { text: "More date & time settings"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Text { text: "›"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
            }
            MouseArea { id: calMoreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { cal.close(); Status.openSettings("time"); } }
        }
        }
    }
    Item { id: keyCatcher; anchors.fill: parent; focus: true; Keys.onEscapePressed: event => { cal.close(); Status.playSfx("click"); event.accepted = true; } }
}
