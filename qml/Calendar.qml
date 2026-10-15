import QtQuick
import QtQuick.Layouts
import Quickshell
import "panels"

// Center popover: mode === "date" (Month Calendar), mode === "notifs" (Notification Center),
// or mode === "time" (Clock & World Clocks).
PanelWindow {
    id: cal

    property string mode: ""    // "" | "date" | "notifs" | "time"
    property var targetScreen: Quickshell.screens[0]
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    visible: cal.mode !== ""
    screen: cal.targetScreen
    color: "transparent"
    anchors.top: true
    margins.top: Theme.barHeight + 6
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: cal.mode === "notifs" ? 364 : (cal.mode === "time" ? 300 : 284)
    implicitHeight: box.implicitHeight

    function resetToToday() {
        const now = new Date();
        cal.viewYear = now.getFullYear();
        cal.viewMonth = now.getMonth();
    }

    function stepMonth(delta) {
        let m = cal.viewMonth + delta, y = cal.viewYear;
        if (m < 0) { m = 11; y -= 1; } else if (m > 11) { m = 0; y += 1; }
        cal.viewMonth = m; cal.viewYear = y;
    }

    function runShell(cmd, closeAfter) {
        if (closeAfter) cal.mode = "";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    readonly property var cells: {
        const out = [];
        const firstDow = new Date(cal.viewYear, cal.viewMonth, 1).getDay();
        const daysInMonth = new Date(cal.viewYear, cal.viewMonth + 1, 0).getDate();
        const daysInPrev = new Date(cal.viewYear, cal.viewMonth, 0).getDate();
        const now = new Date();
        const todayY = now.getFullYear(), todayM = now.getMonth(), todayD = now.getDate();

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

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: (cal.mode === "notifs" ? notifBox.implicitHeight : (cal.mode === "date" ? dateCol.implicitHeight : timeCol.implicitHeight)) + 24
        color: Theme.bg; radius: Theme.radius; border.width: 2; border.color: Theme.blue

        // ---------------- Notifs Mode: 16-Bit Workstation Notification Center ----------------
        ColumnLayout {
            id: notifBox
            visible: cal.mode === "notifs"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8
            NotificationList { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
        }

        // ---------------- Date Mode: Month Calendar ----------------
        ColumnLayout {
            id: dateCol
            visible: cal.mode === "date"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    BarLabel { text: "<"; bold: true; pixelSize: Theme.fontSize; onClicked: cal.stepMonth(-1) }
                    Item {
                        Layout.fillWidth: true; implicitHeight: Theme.barHeight
                        Text {
                            anchors.centerIn: parent
                            text: Qt.formatDate(new Date(cal.viewYear, cal.viewMonth, 1), "MMMM yyyy")
                            color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.resetToToday() }
                    }
                    BarLabel { text: ">"; bold: true; pixelSize: Theme.fontSize; onClicked: cal.stepMonth(1) }
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
            id: timeCol
            visible: cal.mode === "time"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
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

            Repeater {
                model: [
                    { label: "+ Add World Clock...", accent: false,
                      cmd: "tz=$(timedatectl list-timezones | fuzzel --dmenu --prompt 'Add World Clock > ' --width 42) && [ -n \"$tz\" ] && (grep -Fxq \"$tz\" ~/.config/superfedora/world-clocks.txt || echo \"$tz\" >> ~/.config/superfedora/world-clocks.txt)", close: true },
                    { label: "More Settings (timedatectl TUI)...", accent: true,
                      cmd: "kitty --class floating-term -e bash -c 'timedatectl status; echo; cal -3 2>/dev/null || cal; echo; read -r -p \"Set timezone (Enter to skip): \" z; [ -n \"$z\" ] && timedatectl set-timezone \"$z\"'", close: true }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm
                    color: actM.containsMouse ? Theme.bgHover : (modelData.accent ? Theme.bgAlt : "transparent")
                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 6 }
                        text: parent.modelData.label; color: parent.modelData.accent ? Theme.blue : Theme.fg
                        font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: parent.modelData.accent
                    }
                    MouseArea {
                        id: actM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { cal.runShell(parent.modelData.cmd, parent.modelData.close); Status.refresh(); }
                    }
                }
            }
        }
    }
}
