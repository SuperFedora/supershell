import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Omarchy Quattro + GNOME Top Bar: [SF] + Workspaces | Clock | Collapsible System Tray (◂/▸) + Clean Status Pill.
PanelWindow {
    id: bar
    required property var modelData; screen: modelData
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property int activeWsId: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    visible: true; anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto; implicitWidth: modelData.width; implicitHeight: Theme.barHeight
    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    function openDeck(sec) { calendarPopup.mode = ""; Status.toggleSuperDeck(sec || ""); }
    function toggleCenter(targetMode) {
        Status.superDeckOpen = false; Status.appGridOpen = false; Status.recorderOpen = false; Status.settingsOpen = false;
        if (calendarPopup.mode === targetMode) calendarPopup.mode = "";
        else { if (targetMode === "date") calendarPopup.resetToToday(); else Status.refresh(); calendarPopup.mode = targetMode; }
        Status.playSfx("click");
    }

    property string hoverTip: ""
    function setTip(txt, on) { if (on) bar.hoverTip = txt; else if (bar.hoverTip === txt) bar.hoverTip = ""; }

    Calendar { id: calendarPopup; targetScreen: bar.modelData }
    StatusPopup { id: statusPopup; targetScreen: bar.modelData }

    PanelWindow {
        visible: bar.hoverTip !== "" && !Status.superDeckOpen && calendarPopup.mode === ""
        screen: bar.modelData; color: "transparent"; exclusionMode: ExclusionMode.Ignore; anchors.top: true; margins.top: Theme.barHeight + 4
        implicitWidth: tipText.implicitWidth + 20; implicitHeight: 24
        Rectangle { anchors.fill: parent; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.cyan; Text { id: tipText; anchors.centerIn: parent; text: bar.hoverTip; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
    }

    MouseArea { anchors.fill: parent; z: -1; onClicked: { Status.superDeckOpen = false; Status.settingsOpen = false; calendarPopup.mode = ""; } onDoubleClicked: { Theme.barOpacity = Theme.barOpacity < 0.99 ? 1.0 : 0.82; Status.playSfx("toggle"); } }

    // ---------------- Left ----------------
    RowLayout {
        id: leftRow; anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 } spacing: 0
        BarLabel { text: "󰣛"; color: Status.settingsOpen ? Theme.cyan : Theme.blue; pixelSize: Theme.iconSize + 2; onHoveredChanged: bar.setTip("SuperFedora Settings (Super+,)  ·  Right-click: SuperDock (Super+Alt+Space)", hovered); onClicked: { calendarPopup.mode = ""; Status.toggleSettings("home"); } onRightClicked: bar.openDeck("") }
        Workspaces { monitor: bar.hyprMonitor; thickness: bar.implicitHeight }
        BarLabel { id: modeLabel; property string mode: ""; visible: mode !== ""; text: "󰌌 " + mode.toUpperCase() + "  ·  Esc to exit"; color: Theme.yellow; pixelSize: Theme.fontSize; bold: true; onClicked: Hyprland.dispatch("submap reset"); Connections { target: Hyprland; function onRawEvent(event) { if (event.name === "submap") modeLabel.mode = event.data; } } }
    }

    // ---------------- Center: Collapsible Left Tool Expander (◂/▸) + Centered Date/Time + Right Notification Bell ----------------
    Connections { target: Status; function onCenterToggleSeqChanged() { if (bar.modelData === Quickshell.screens[0]) bar.toggleCenter("notifs"); } function onSuperDeckOpenChanged() { if (Status.superDeckOpen) calendarPopup.mode = ""; } function onAppGridOpenChanged() { if (Status.appGridOpen) calendarPopup.mode = ""; } function onRecorderOpenChanged() { if (Status.recorderOpen) calendarPopup.mode = ""; } function onSettingsOpenChanged() { if (Status.settingsOpen) calendarPopup.mode = ""; } }

    BarLabel {
        id: centerClock; anchors.centerIn: parent; property date now: new Date()
        Timer { interval: Status.clockSeconds ? 1000 : 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: centerClock.now = new Date() }
        pixelSize: Theme.fontSize; bold: true; color: (calendarPopup.mode === "date" || calendarPopup.mode === "time") ? Theme.cyan : Theme.fg
        text: Qt.formatDateTime(centerClock.now, "ddd, MMM d   " + (Status.clock24h ? (Status.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Status.clockSeconds ? "h:mm:ss AP" : "h:mm AP")))
        onHoveredChanged: bar.setTip("Calendar  ·  Right-click: Clock & World Time", hovered); onClicked: bar.toggleCenter("date"); onRightClicked: bar.toggleCenter("time")
    }

    BarLabel {
        id: notifBell; anchors { left: centerClock.right; verticalCenter: parent.verticalCenter; leftMargin: 2 }
        pixelSize: Theme.fontSize; bold: Status.dnd || Status.notifUnread > 0 || calendarPopup.mode === "notifs"
        color: calendarPopup.mode === "notifs" ? Theme.cyan : (Status.dnd ? Theme.yellow : (Status.notifUnread > 0 ? Theme.cyan : Theme.fgDim))
        text: Status.dnd ? "󰂛" : (Status.notifUnread > 0 ? ("󰂞 " + Status.notifUnread) : "󰂚")
        onHoveredChanged: bar.setTip("Notifications (" + Status.notifUnread + " unread)  ·  Right-click: Do Not Disturb (" + (Status.dnd ? "ON" : "OFF") + ")", hovered); onClicked: bar.toggleCenter("notifs"); onRightClicked: { if (Status.notifAction) Status.notifAction("toggleDnd"); Status.playSfx("toggle"); }
    }

    RowLayout {
        id: centerLeftTools; anchors { right: centerClock.left; verticalCenter: parent.verticalCenter; rightMargin: 2 } spacing: 3
        readonly property var tools: [
            { id: "color",  active: false, col: Theme.magenta, txt: "󰈊", tip: "Color Picker  ·  Copy screen pixel hex to clipboard" },
            { id: "shot",   active: false, col: Theme.cyan,    txt: "󰹑", tip: "Screenshot  ·  Left-click: Region  ·  Right-click: Full Screen" },
            { id: "record", active: Status.recorderOpen || Status.screenRecording, col: Theme.red, txt: "󰻂", tip: "Screen Recorder  ·  Toggle Start / Pause recording controls" },
            { id: "idle",   active: Status.idleMode !== "poweroff", col: Status.idleMode === "lock" ? Theme.cyan : Theme.yellow, txt: Status.idleMode === "lock" ? "󰅶 󰌾" : (Status.idleMode === "screensaver" ? "󰅶" : "󰒲"), tip: Status.idleMode === "lock" ? "Coffee / Idle Mode: Lock After Timer (2m Screensaver → 5m Lock · No Screen Power Off) · Click to cycle" : (Status.idleMode === "screensaver" ? "Coffee / Idle Mode: Only Screensaver (2m Screensaver · Never Locks or Powers Off) · Click to cycle" : "Coffee / Idle Mode: Screen Power Off (2m Screensaver → 5m Lock → 10m Screen Off) · Click to cycle") }
        ]
        function triggerTool(id, rightBtn) {
            if (id === "idle") { if (rightBtn) bar.openDeck("power"); else Status.toggleIdle(); }
            else if (id === "record") { calendarPopup.mode = ""; if (rightBtn) Status.startScreenRecord(true); else { Status.recorderOpen = !Status.recorderOpen; Status.playSfx("click"); } }
            else if (id === "shot") bar.run("~/.config/hypr/scripts/screenshot.sh " + (rightBtn ? "screen" : "region"));
            else if (id === "color") bar.run("~/.config/hypr/scripts/screenshot.sh color");
        }
        Repeater {
            model: centerLeftTools.tools
            Rectangle {
                id: ctChip; required property var modelData; readonly property bool shown: Status.centerToolsOpen || (modelData.active && (modelData.id === "idle" || modelData.id === "record"))
                visible: shown; implicitWidth: shown ? ctTxt.implicitWidth + 12 : 0; implicitHeight: Theme.barHeight - 8; radius: Theme.radiusSm
                color: ctChipM.pressed ? Theme.bgAlt : (ctChipM.containsMouse ? Theme.bgHover : "transparent"); border.width: modelData.active ? 1 : 0; border.color: modelData.col
                Text { id: ctTxt; anchors.centerIn: parent; text: ctChip.modelData.txt; color: ctChip.modelData.active ? ctChip.modelData.col : (ctChipM.containsMouse ? Theme.cyan : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: ctChip.modelData.active }
                MouseArea { id: ctChipM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onContainsMouseChanged: bar.setTip(ctChip.modelData.tip, containsMouse); onClicked: e => centerLeftTools.triggerTool(ctChip.modelData.id, e.button === Qt.RightButton) }
            }
        }
        Rectangle {
            implicitWidth: 22; implicitHeight: Theme.barHeight - 8; radius: Theme.radiusSm; color: ctMouse.containsMouse ? Theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: Status.centerToolsOpen ? "▸" : "◂"; color: Status.centerToolsOpen || ctMouse.containsMouse ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
            MouseArea { id: ctMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: bar.setTip(Status.centerToolsOpen ? "Hide Quick Tools" : "Expand Quick Tools (Coffee / Idle Mode, Record, Screenshot, Color Picker)", containsMouse); onClicked: { Status.centerToolsOpen = !Status.centerToolsOpen; Status.playSfx("click"); } }
        }
    }

    // ---------------- Right-Side Vertical Screen Recorder Dock ----------------
    PanelWindow {
        id: recorderDock
        visible: (Status.recorderOpen || Status.screenRecording) && !Status.superDeckOpen && !Status.appGridOpen && !Status.settingsOpen && calendarPopup.mode === ""
        screen: bar.modelData; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        anchors.right: true; margins.right: 8
        implicitWidth: 144; implicitHeight: recCol.implicitHeight + 24

        Rectangle {
            anchors.fill: parent; radius: Theme.radius
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.96)
            border.width: 2; border.color: Status.screenRecording ? (Status.screenPaused ? Theme.yellow : Theme.red) : Theme.cyan

            ColumnLayout {
                id: recCol; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 } spacing: 8
                Text { Layout.alignment: Qt.AlignHCenter; text: Status.screenRecording ? (Status.screenPaused ? "󰏤 PAUSED" : "󰻂 REC") : "󰻂 RECORDER"; color: Status.screenRecording ? (Status.screenPaused ? Theme.yellow : Theme.red) : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm
                    readonly property color accent: Status.screenRecording && !Status.screenPaused ? Theme.yellow : Theme.green
                    color: recStartM.containsMouse ? accent : Theme.bgAlt; border.width: 1; border.color: accent
                    Text { anchors.centerIn: parent; text: !Status.screenRecording || Status.screenPaused ? "[ 󰐊 START ]" : "[ 󰏤 PAUSE ]"; color: recStartM.containsMouse ? Theme.bg : parent.accent; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    MouseArea { id: recStartM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (!Status.screenRecording) Status.startScreenRecord(false); else Status.pauseScreenRecord(); } }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm
                    readonly property color accent: Status.screenRecording ? Theme.red : Theme.cyan
                    color: recActM.containsMouse ? accent : Theme.bgAlt; border.width: 1; border.color: accent
                    Text { anchors.centerIn: parent; text: Status.screenRecording ? "[ 󰓛 STOP ]" : "[ 󰹑 REGION ]"; color: recActM.containsMouse ? Theme.bg : parent.accent; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    MouseArea { id: recActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.screenRecording) Status.stopScreenRecord(); else Status.startScreenRecord(true); } }
                }
                Rectangle {
                    visible: !Status.screenRecording; Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm
                    color: recCloseM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: recCloseM.containsMouse ? Theme.red : Theme.border
                    Text { anchors.centerIn: parent; text: "[ × CLOSE ]"; color: recCloseM.containsMouse ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    MouseArea { id: recCloseM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.recorderOpen = false; Status.playSfx("click"); } }
                }
            }
        }
    }

    // ---------------- Right: Collapsible System Tray + Clean Status Pill ----------------
    RowLayout {
        id: rightRow
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
        spacing: 6

        Rectangle {
            id: pocketDrawer; visible: Status.pocketOpen
            implicitWidth: visible ? trayRow.implicitWidth + 4 : 0; implicitHeight: Theme.barHeight - 8; color: "transparent"; border.width: 0
            Tray { id: trayRow; anchors.centerIn: parent; bar: bar }
        }

        Rectangle {
            id: pocketToggle; implicitWidth: 26; implicitHeight: Theme.barHeight - 8; radius: Theme.radiusSm; color: ptMouse.containsMouse ? Theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: Status.pocketOpen ? "▸" : "◂"; color: Status.pocketOpen || ptMouse.containsMouse ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
            MouseArea { id: ptMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: bar.setTip(Status.pocketOpen ? "Hide System Tray" : "Expand System Tray", containsMouse); onClicked: { Status.pocketOpen = !Status.pocketOpen; Status.playSfx("click"); } }
        }

        Rectangle { implicitWidth: 1; implicitHeight: 14; color: Theme.border }

        Rectangle {
            id: quickPill
            readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null
            readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
            readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
            readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
            readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
            readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
            readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
            readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

            function iconGlyph(id) {
                if (id === "wifi") return !Status.wifiEnabled ? "󰤮" : (Status.netType === "ethernet" ? "󰀂" : (Status.netType !== "wifi" ? "󰤯" : (Status.signal >= 80 ? "󰤨" : Status.signal >= 60 ? "󰤥" : Status.signal >= 40 ? "󰤢" : Status.signal >= 20 ? "󰤟" : "󰤯")));
                if (id === "bluetooth") return !quickPill.btAdapter || !quickPill.btAdapter.enabled ? "󰂲" : (quickPill.btConnected > 0 ? "󰂱" : "󰂯");
                if (id === "speaker") return quickPill.muted ? "󰝟" : quickPill.vol >= 0.66 ? "󰕾" : quickPill.vol >= 0.33 ? "󰖀" : "󰕿";
                if (id === "mic") return quickPill.micMuted ? "󰍭" : "󰍬";
                if (id === "camera") return Status.webcamEnabled ? "󰄀" : "󰗟";
                if (id === "battery") return quickPill.batCharging ? "󰂄" : (quickPill.batPct <= 15 ? "󰁺" : quickPill.batPct <= 40 ? "󰁼" : quickPill.batPct <= 75 ? "󰂀" : "󰁹");
                return "󰐥";
            }
            function iconTip(id) {
                if (id === "wifi") return "Wi-Fi: " + (!Status.wifiEnabled ? "Off" : (Status.ssid || Status.netType)) + " (Right-click: Toggle Radio)";
                if (id === "bluetooth") return "Bluetooth (Right-click: Toggle Power)";
                if (id === "speaker") return "Speaker: " + (quickPill.muted ? "Muted" : Math.round(quickPill.vol * 100) + "%") + " (Scroll: Volume · Right-click: Mute)";
                if (id === "mic") return "Microphone: " + (quickPill.micMuted ? "Muted" : Math.round(quickPill.micVol * 100) + "%") + " (Right-click: Mute)";
                if (id === "camera") return "Webcam Driver: " + (Status.webcamEnabled ? "Enabled" : "Disabled") + " (Right-click: Toggle)";
                if (id === "battery") return "Battery: " + quickPill.batPct + "% (" + (quickPill.batCharging ? "Charging" : "Discharging") + ")";
                return "Power & Session Menu";
            }
            function iconSection(id) { return (id === "wifi" || id === "bluetooth") ? id : ((id === "battery" || id === "power") ? "power" : "audio"); }
            function iconColor(id, hovered) {
                if (Status.superDeckOpen && Status.superDeckSection === quickPill.iconSection(id)) return Theme.cyan;
                if (hovered) return id === "power" ? Theme.red : Theme.cyan;
                if (id === "wifi") return (!Status.wifiEnabled || Status.netType === "none") ? Theme.muted : Theme.fg;
                if (id === "bluetooth") return (quickPill.btAdapter && quickPill.btAdapter.enabled) ? (quickPill.btConnected > 0 ? Theme.fg : Theme.fgDim) : Theme.muted;
                if (id === "speaker") return quickPill.muted ? Theme.muted : Theme.fg;
                if (id === "mic") return quickPill.micMuted ? Theme.muted : Theme.fg;
                if (id === "camera") return Status.webcamEnabled ? Theme.fg : Theme.muted;
                if (id === "battery") return quickPill.batCharging ? Theme.cyan : (quickPill.batPct <= 15 ? Theme.red : Theme.fg);
                return Theme.fgDim;
            }
            function toggleHardware(id) {
                if (id === "wifi") Status.toggleWifiRadio();
                else if (id === "bluetooth") { bar.run(quickPill.btAdapter && quickPill.btAdapter.enabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on"); Status.playSfx("toggle"); Status.refresh(); }
                else if (id === "speaker") { const m = !quickPill.muted; if (quickPill.audioReady) quickPill.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                else if (id === "mic") { const m = !quickPill.micMuted; if (quickPill.micReady) quickPill.source.audio.muted = m; Status.toggleMicMute(m); }
                else if (id === "camera") Status.toggleWebcam();
                else bar.openDeck("power");
            }

            implicitWidth: pillRow.implicitWidth + 6; implicitHeight: Theme.barHeight - 6; color: "transparent"; border.width: 0

            RowLayout {
                id: pillRow; anchors.centerIn: parent; spacing: 2
                Repeater {
                    model: Status.barIcons
                    Item {
                        id: slotItem; required property string modelData; required property int index
                        readonly property bool isDiv: modelData === "|"
                        readonly property bool isVis: isDiv ? (index > 0 && index < Status.barIcons.length - 1) : (Status.barHiddenIcons.indexOf(modelData) < 0 && (modelData !== "battery" || quickPill.batPresent))
                        visible: isVis; implicitWidth: !isVis ? 0 : (isDiv ? 9 : 26); implicitHeight: Theme.barHeight - 8

                        Rectangle { visible: slotItem.isDiv; anchors.centerIn: parent; width: 1; height: 14; color: Theme.border }

                        Rectangle {
                            visible: !slotItem.isDiv; anchors.fill: parent; radius: Theme.radiusSm
                            color: slotMouse.pressed ? Theme.bgAlt : (slotMouse.containsMouse ? Theme.bgHover : "transparent")
                            border.width: slotMouse.pressed ? 1 : 0; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: slotItem.isDiv ? "" : quickPill.iconGlyph(slotItem.modelData); color: slotItem.isDiv ? "transparent" : quickPill.iconColor(slotItem.modelData, slotMouse.containsMouse); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
                            MouseArea {
                                id: slotMouse; property real dragStartX: 0; property bool didDrag: false
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onContainsMouseChanged: if (!slotItem.isDiv) bar.setTip(quickPill.iconTip(slotItem.modelData), containsMouse)
                                onPressed: e => { dragStartX = e.x; didDrag = false; }
                                onPositionChanged: e => { if (pressedButtons & Qt.LeftButton) { const dx = e.x - dragStartX; if (Math.abs(dx) >= 24) { didDrag = true; Status.moveBarIcon(slotItem.modelData, dx > 0 ? 1 : -1); dragStartX = e.x; } } }
                                onClicked: e => { if (!didDrag) { if (e.button === Qt.RightButton) quickPill.toggleHardware(slotItem.modelData); else bar.openDeck(quickPill.iconSection(slotItem.modelData)); } }
                                onWheel: wheel => {
                                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                    if (slotItem.modelData === "speaker") { const v = Math.max(0, Math.min(1, quickPill.vol + step)); if (quickPill.audioReady) quickPill.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                                    else if (slotItem.modelData === "mic") { const v = Math.max(0, Math.min(1, quickPill.micVol + step)); if (quickPill.micReady) quickPill.source.audio.volume = v; Status.setMicVolume(v); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
