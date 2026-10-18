import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."

// QuickFlyout — Uniform 360×320 expanding bar popover for status icons (`wifi`, `bluetooth`, `speaker`, `mic`, `camera`,
// `battery`, `power`) and interactive bar tools (`calc`, `clip`, `record`, `qr`, `nightlight`).
// Smoothly expands out of the bar edge (`openProgress`: 0 → 1) and retracts back into the bar on close.
PanelWindow {
    id: fly
    property string mode: ""; property string renderMode: ""; property string barEdge: "top"
    property real openProgress: fly.mode !== "" ? 1.0 : 0.0
    Behavior on openProgress { NumberAnimation { duration: Theme.dur(fly.mode !== "" ? 300 : 200); easing.type: Easing.BezierSpline; easing.bezierCurve: fly.mode !== "" ? Theme.curveDecel : Theme.curveStandard } }
    property real anchorX: -1; property real anchorY: -1; property var targetScreen: Quickshell.screens[0]; property string wifiPassSsid: ""
    Behavior on anchorX { enabled: fly.openProgress > 0.02 && fly.openProgress < 0.99 || fly.mode !== ""; NumberAnimation { duration: Theme.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
    Behavior on anchorY { enabled: fly.openProgress > 0.02 && fly.openProgress < 0.99 || fly.mode !== ""; NumberAnimation { duration: Theme.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
    property string calcOut: "0"; property var clipItems: []; property string qrImg: ""
    readonly property string m: fly.mode !== "" ? fly.mode : fly.renderMode
    readonly property bool isVert: fly.barEdge === "left" || fly.barEdge === "right"
    readonly property bool isTool: ["calc", "clip", "record", "qr", "nightlight"].indexOf(fly.m) >= 0
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null && !isNaN(sink.audio.volume)
    readonly property real spkVol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool spkMuted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null && !isNaN(source.audio.volume)
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
    readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property var btList: btAdapter ? Bluetooth.devices.values.slice(0, 5) : []
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 100
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    Process { id: clipProc; command: ["sh", "-c", "~/.local/bin/cliphist list 2>/dev/null | head -n 7"]; stdout: StdioCollector { onStreamFinished: { fly.clipItems = text.trim() ? text.trim().split("\n").map(l => { const t = l.indexOf("\t"); return { raw: l, label: (t >= 0 ? l.slice(t + 1) : l).trim() }; }) : []; } } }
    Process { id: calcProc; property string expr: ""; command: ["sh", "-c", "~/.local/bin/fend '" + calcProc.expr.replace(/'/g, "'\\''") + "' 2>&1 | head -n 1"]; stdout: StdioCollector { onStreamFinished: { const r = text.trim(); fly.calcOut = r !== "" ? r : "0"; } } }
    Process { id: qrProc; property string txt: ""; command: ["sh", "-c", "t='" + qrProc.txt.replace(/'/g, "'\\''") + "'; [ -z \"$t\" ] && t=$(wl-paste -n 2>/dev/null | head -c 500); [ -n \"$t\" ] && ~/.local/bin/qr \"$t\" > /tmp/sf-qr.png 2>/dev/null && echo /tmp/sf-qr.png"]; stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) fly.qrImg = "file://" + p + "?" + Date.now(); } } }

    function close() { fly.mode = ""; fly.wifiPassSsid = ""; Status.recorderOpen = false; }
    function run(cmd, closeAfter) { if (closeAfter) fly.close(); Status.playSfx("click"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }
    function evalCalc(q) { const s = String(q || "").trim(); if (!s) { fly.calcOut = "0"; return; } calcProc.expr = s; calcProc.running = false; calcProc.running = true; }
    function pressKey(k) { Status.playSfx("click"); if (k === "C") { calcIn.text = ""; fly.calcOut = "0"; } else if (k === "⌫") calcIn.text = calcIn.text.slice(0, -1); else if (k === "=") { if (fly.calcOut && fly.calcOut !== "0") { calcIn.text = fly.calcOut; Status.copyText(fly.calcOut); } } else calcIn.text += (k === "÷" ? " / " : (k === "×" ? " * " : (k === "−" ? " - " : (k === "+" ? " + " : k)))); calcIn.forceActiveFocus(); }
    function genQr(q) { qrProc.txt = String(q || "").trim(); qrProc.running = false; qrProc.running = true; }
    function settingsPageFor(k) { return k === "wifi" ? "network" : ((k === "bluetooth" || k === "camera") ? "devices" : ((k === "battery" || k === "power") ? "power" : "system")); }
    function moreLabelFor(k) { return k === "wifi" ? "SuperSettings · Wi-Fi" : (k === "bluetooth" ? "SuperSettings · Bluetooth" : (k === "speaker" ? "SuperSettings · Sound" : (k === "mic" ? "SuperSettings · Mic" : (k === "camera" ? "SuperSettings · Camera" : "SuperSettings · Power")))); }
    function tuiLabelFor(k) { return k === "wifi" ? "󰆍  TUI (wlctl)" : (k === "bluetooth" ? "󰆍  TUI (bluetui)" : ((k === "speaker" || k === "mic") ? "󰆍  TUI (wiremix)" : "󰆍  SuperBar TUI")); }
    function tuiCmdFor(k) { return k === "wifi" ? "~/.local/bin/xdg-terminal-exec --class floating-tui -e sh -c 'PATH=\"$HOME/.cargo/bin:$HOME/.local/bin:$PATH\"; wlctl || nmtui'" : (k === "bluetooth" ? "~/.local/bin/xdg-terminal-exec --class floating-tui -e bluetui || ~/.local/bin/xdg-terminal-exec --class floating-tui -e bluetoothctl" : ((k === "speaker" || k === "mic") ? "~/.local/bin/xdg-terminal-exec --class floating-tui -e wiremix" : "~/.local/bin/xdg-terminal-exec --class floating-tui -e ~/.local/bin/superbar tui")); }
    function wifiGlyph(sig) { return sig >= 75 ? "󰤨" : (sig >= 55 ? "󰤥" : (sig >= 35 ? "󰤢" : "󰤟")); }
    function wifiClick(w) { if (!w) return; const s = String(w.ssid || "").replace(/'/g, "'\\''"); if (w.active) fly.run("nmcli connection down '" + s + "'; sleep 0.5 && qs ipc call status refresh", false); else if (w.saved || w.open) fly.run("nmcli device wifi connect '" + s + "'; sleep 0.8 && qs ipc call status refresh", false); else { fly.wifiPassSsid = w.ssid; passIn.text = ""; passIn.forceActiveFocus(); Status.playSfx("click"); } }
    function submitPass() { if (!fly.wifiPassSsid) return; const s = String(fly.wifiPassSsid).replace(/'/g, "'\\''"), p = String(passIn.text).replace(/'/g, "'\\''"); fly.wifiPassSsid = ""; passIn.text = ""; keyCatcher.forceActiveFocus(); fly.run("nmcli device wifi connect '" + s + "' password '" + p + "'; sleep 0.9 && qs ipc call status refresh", false); }

    readonly property int bTop: fly.barEdge === "top" ? Theme.barHeight : 0; readonly property int bBot: fly.barEdge === "bottom" ? Theme.barHeight : 0
    readonly property int bLeft: fly.barEdge === "left" ? Theme.barHeight : 0; readonly property int bRight: fly.barEdge === "right" ? Theme.barHeight : 0
    visible: fly.mode !== "" || fly.openProgress > 0.005; screen: fly.targetScreen; color: "transparent"; exclusionMode: ExclusionMode.Ignore
    implicitWidth: fly.targetScreen ? fly.targetScreen.width : 1920; implicitHeight: fly.targetScreen ? fly.targetScreen.height : 1080
    WlrLayershell.namespace: "superfedora-quick-flyout"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: fly.mode !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    onModeChanged: { fly.wifiPassSsid = ""; if (fly.mode !== "") { fly.renderMode = fly.mode; if (fly.mode === "clip") clipProc.running = true; if (fly.mode === "qr") fly.genQr(qrIn.text); if (fly.mode === "calc") calcIn.forceActiveFocus(); else if (fly.mode === "qr") qrIn.forceActiveFocus(); else keyCatcher.forceActiveFocus(); } }
    MouseArea { anchors.fill: parent; enabled: fly.mode !== ""; onPressed: e => { if (fly.barClick && ((fly.barEdge === "top" && e.y < Theme.barHeight) || (fly.barEdge === "bottom" && e.y >= parent.height - Theme.barHeight) || (fly.barEdge === "left" && e.x < Theme.barHeight) || (fly.barEdge === "right" && e.x >= parent.width - Theme.barHeight))) { fly.barClick(e.x, e.y, e.button); } else { fly.close(); Status.playSfx("click"); } } }
    property var barClick: null
    readonly property int fSz: Theme.radius
    readonly property real popMid: fly.isVert ? (clipWrap.y + clipWrap.height / 2) : (clipWrap.x + clipWrap.width / 2)
    readonly property real popHalf: ((fly.isVert ? clipWrap.height : clipWrap.width) / 2 + fly.fSz) * Math.min(1, fly.openProgress * 1.15)
    readonly property real popStart: fly.popMid - fly.popHalf; readonly property real popEnd: fly.popMid + fly.popHalf
    ConcaveFillet { visible: !fly.isVert && fly.fSz > 0; opacity: Math.min(1, fly.openProgress * 1.6); x: clipWrap.x - size + 2; y: fly.barEdge === "top" ? fly.bTop : (parent.height - fly.bBot - size); size: fly.fSz; concave: true; corner: fly.barEdge === "top" ? "TopRight" : "BottomRight"; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98); strokeWidth: 2; strokeColor: Theme.blue; z: 5 }
    ConcaveFillet { visible: !fly.isVert && fly.fSz > 0; opacity: Math.min(1, fly.openProgress * 1.6); x: clipWrap.x + clipWrap.width - 2; y: fly.barEdge === "top" ? fly.bTop : (parent.height - fly.bBot - size); size: fly.fSz; concave: true; corner: fly.barEdge === "top" ? "TopLeft" : "BottomLeft"; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98); strokeWidth: 2; strokeColor: Theme.blue; z: 5 }
    Item {
        id: clipWrap
        readonly property int fullW: 360; readonly property int fullH: 320
        width: fly.isVert ? (fullW * Math.max(0, Math.min(1, fly.openProgress))) : fullW; height: fly.isVert ? fullH : (fullH * Math.max(0, Math.min(1, fly.openProgress)))
        x: fly.barEdge === "left" ? fly.bLeft : (fly.barEdge === "right" ? (parent.width - fly.bRight - width) : (fly.anchorX >= 0 ? Math.max(12, Math.min(parent.width - fullW - 12, fly.anchorX - fullW / 2)) : (parent.width - fullW - 12)))
        y: fly.barEdge === "top" ? fly.bTop : (fly.barEdge === "bottom" ? (parent.height - fly.bBot - height) : (fly.anchorY >= 0 ? Math.max(12, Math.min(parent.height - fullH - 12, fly.anchorY - fullH / 2)) : ((parent.height - fullH) / 2)))
        clip: true
        Rectangle {
            id: box; width: clipWrap.fullW + (fly.isVert ? Theme.radius + 4 : 0); height: clipWrap.fullH + (fly.isVert ? 0 : Theme.radius + 4)
            x: fly.barEdge === "left" ? (clipWrap.width - width) : 0; y: fly.barEdge === "top" ? (clipWrap.height - height) : 0
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98); radius: Theme.radius; border.width: 2; border.color: Theme.blue
            MouseArea { anchors.fill: parent }
            Rectangle { visible: !fly.isVert && fly.fSz > 0; x: 0; y: fly.barEdge === "top" ? (box.height - clipWrap.height) : (clipWrap.height - fly.fSz); width: box.width; height: fly.fSz; color: box.color; z: 2 }

            ColumnLayout {
                id: mainCol; opacity: Math.min(1, fly.openProgress * 1.25); anchors { fill: parent; topMargin: fly.barEdge === "top" ? (Theme.radius + 14) : 10; bottomMargin: fly.barEdge === "bottom" ? (Theme.radius + 14) : 10; leftMargin: fly.barEdge === "left" ? (Theme.radius + 14) : 12; rightMargin: fly.barEdge === "right" ? (Theme.radius + 14) : 12 } spacing: 6

                // ==================== 1. WI-FI & NETWORK QUICK FLYOUT ====================
                ColumnLayout {
                    visible: fly.m === "wifi"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Text { text: Status.netType === "ethernet" ? "󰀂  Network & Wi-Fi" : "󰤨  Wi-Fi Networks"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Rectangle { implicitWidth: 62; implicitHeight: 24; radius: Theme.radiusSm; color: rescanM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: rescanM.containsMouse ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: "󰑐 Scan"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: rescanM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("nmcli device wifi rescan; sleep 1 && qs ipc call status refresh", false) } }
                        Rectangle { implicitWidth: 58; implicitHeight: 24; radius: Theme.radiusSm; color: Status.wifiEnabled ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Status.wifiEnabled ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: Status.wifiEnabled ? "On" : "Off"; color: Status.wifiEnabled ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWifiRadio() } }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 42; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: (Status.wifiEnabled && (Status.ssid !== "" || Status.netType === "ethernet")) ? Theme.blue : Theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                            Text { text: !Status.wifiEnabled ? "󰤮" : (Status.netType === "ethernet" ? "󰀂" : (Status.ssid ? fly.wifiGlyph(Status.signal || 70) : "󰤯")); color: (Status.wifiEnabled && (Status.ssid !== "" || Status.netType === "ethernet")) ? Theme.blue : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: !Status.wifiEnabled ? "Wi-Fi Radio Off" : (Status.ssid ? Status.ssid : (Status.netType === "ethernet" ? ("Ethernet · " + Status.netIface) : "Not Connected")); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: !Status.wifiEnabled ? "Turn Wi-Fi on to see nearby networks" : (Status.ssid ? ("Connected · " + (Status.signal || 70) + "% signal · " + Status.netIpv4.split("/")[0]) : "Select a network below to connect"); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; elide: Text.ElideRight; Layout.fillWidth: true } }
                            Rectangle { visible: Status.wifiEnabled && Status.ssid !== ""; implicitWidth: 74; implicitHeight: 24; radius: Theme.radiusSm; color: discM.containsMouse ? Theme.red : Theme.bg; border.width: 1; border.color: discM.containsMouse ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: "Disconnect"; color: discM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.weight: Font.DemiBold } MouseArea { id: discM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.wifiClick({ ssid: Status.ssid, active: true }) } }
                        }
                    }
                    RowLayout {
                        visible: fly.wifiPassSsid !== ""; Layout.fillWidth: true; spacing: 6
                        Rectangle { Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.blue; TextInput { id: passIn; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; echoMode: TextInput.Password; clip: true; Keys.onReturnPressed: fly.submitPass(); Keys.onEscapePressed: event => { fly.wifiPassSsid = ""; event.accepted = true; } Text { visible: passIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Password for " + fly.wifiPassSsid + "..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                        Rectangle { implicitWidth: 58; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "Join"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.submitPass() } }
                    }
                    Text { visible: Status.wifiEnabled; text: "Available Networks"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.weight: Font.DemiBold }
                    Repeater { model: Status.wifiList.filter(w => !w.active && w.ssid !== Status.ssid).slice(0, fly.wifiPassSsid !== "" ? 3 : 4); Rectangle { id: wItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: wItemM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: wItemM.containsMouse ? Theme.blue : Theme.border
                        RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 8 } spacing: 8; Text { text: fly.wifiGlyph(wItem.modelData.signal); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 } Text { text: wItem.modelData.ssid + (wItem.modelData.open ? "" : " 󰌾"); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: (wItem.modelData.saved ? "Saved · " : "") + wItem.modelData.signal + "%"; color: wItem.modelData.saved ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4 } Text { text: "Connect ›"; color: wItemM.containsMouse ? Theme.blue : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.weight: Font.DemiBold } }
                        MouseArea { id: wItemM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.wifiClick(wItem.modelData) } } }
                    Item { Layout.fillHeight: true }
                }

                // ==================== 2. BLUETOOTH QUICK FLYOUT ====================
                ColumnLayout {
                    visible: fly.m === "bluetooth"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "󰂯  Bluetooth"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Rectangle { implicitWidth: 64; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Scan"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false) } }
                        Rectangle { implicitWidth: 64; implicitHeight: 24; radius: Theme.radiusSm; color: fly.btOn ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: fly.btOn ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: fly.btOn ? "On" : "Off"; color: fly.btOn ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(fly.btOn ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) } }
                    }
                    Text { visible: fly.btList.length === 0; text: fly.btOn ? "No paired devices found. Click Scan above." : "Bluetooth is turned off."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                    Repeater { model: fly.btList; Rectangle { id: bRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; color: modelData.connected ? Theme.bgAlt : (bRowM.containsMouse ? Theme.bgHover : "transparent"); border.width: modelData.connected ? 1 : 0; border.color: Theme.blue
                        RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8; Text { text: "󰂯  " + (bRow.modelData.name || "Device"); color: bRow.modelData.connected ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: bRow.modelData.connected ? "Connected" : "Connect"; color: bRow.modelData.connected ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                        MouseArea { id: bRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(bRow.modelData.connected ? ("bluetoothctl disconnect " + bRow.modelData.address) : ("bluetoothctl connect " + bRow.modelData.address), false) } } }
                    Item { Layout.fillHeight: true }
                }

                // ==================== 3. SPEAKER OR MICROPHONE QUICK FLYOUT ====================
                ColumnLayout {
                    id: audCol; visible: fly.m === "speaker" || fly.m === "mic"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    readonly property bool isSpk: fly.m === "speaker"; readonly property real curVol: isSpk ? fly.spkVol : fly.micVol; readonly property bool curMuted: isSpk ? fly.spkMuted : fly.micMuted
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: audCol.isSpk ? "󰕾  Speaker" : "󰍬  Microphone"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Rectangle { implicitWidth: 96; implicitHeight: 24; radius: Theme.radiusSm; color: audCol.curMuted ? Theme.red : Theme.bgAlt; border.width: 1; border.color: audCol.curMuted ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: (audCol.curMuted ? "Muted · " : "Mute · ") + Math.round((audCol.curVol || 0) * 100) + "%"; color: audCol.curMuted ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (fly.m === "speaker") Status.toggleSpeakerMute(); else Status.toggleMicMute(); } } }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 8; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Rectangle { width: Math.round(parent.width * Math.max(0, Math.min(1, audCol.curVol || 0))); height: parent.height; radius: Theme.radiusSm; color: Theme.blue } MouseArea { anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8; cursorShape: Qt.PointingHandCursor; onPressed: e => { if (fly.m === "speaker") Status.setSpeakerVolume(e.x / width); else Status.setMicVolume(e.x / width); } onPositionChanged: e => { if (pressed) { if (fly.m === "speaker") Status.setSpeakerVolume(e.x / width); else Status.setMicVolume(e.x / width); } } } }
                    Text { text: audCol.isSpk ? "Output devices" : "Input devices"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                    Repeater { model: (fly.m === "speaker" ? Status.audioSinks : Status.audioSources).slice(0, 4); Rectangle { id: audItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: modelData.active ? Theme.bgAlt : (audM.containsMouse ? Theme.bgHover : "transparent"); border.width: modelData.active ? 1 : 0; border.color: Theme.blue; Text { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: Text.AlignVCenter; text: (audItem.modelData.active ? "●  " : "○  ") + audItem.modelData.name; color: audItem.modelData.active ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight } MouseArea { id: audM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(audItem.modelData.id) } } }
                    Item { Layout.fillHeight: true }
                }

                // ==================== 4. CAMERA QUICK FLYOUT ====================
                ColumnLayout {
                    visible: fly.m === "camera"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "󰄀  Camera"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Text { text: Status.webcamEnabled ? "Active" : "Locked"; color: Status.webcamEnabled ? Theme.blue : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } }
                    Text { text: Status.webcamEnabled ? "Webcam driver (uvcvideo) is enabled and ready for video calls and capture." : "Webcam kernel driver is unloaded (hardware privacy lock engaged)."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 42; radius: Theme.radiusSm; color: camBtnM.containsMouse ? (Status.webcamEnabled ? Theme.cyan : Theme.bgHover) : (Status.webcamEnabled ? Theme.blue : Theme.bgAlt); border.width: 1; border.color: Status.webcamEnabled ? Theme.blue : (camBtnM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: Status.webcamEnabled ? "󰄀  Camera On — Click to Lock" : "󰗟  Camera Locked — Click to Enable"; color: Status.webcamEnabled ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } MouseArea { id: camBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWebcam() } }
                    Item { Layout.fillHeight: true }
                }

                // ==================== 5. BATTERY QUICK FLYOUT ====================
                ColumnLayout {
                    visible: fly.m === "battery"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: (fly.batCharging ? "󰂄  Battery (" : "󰁹  Battery (") + fly.batPct + "%)"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Text { text: "Mode: " + Status.workstationMode; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } }
                    Text { text: (fly.batCharging ? "Charging / AC Connected" : "Discharging on Battery") + (Status.bat0Present ? ("  ·  " + Status.bat0Threshold) : ""); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "󰃠"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        Item { Layout.fillWidth: true; implicitHeight: 24; Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border } Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * Status.brightness); height: 8; radius: Theme.radiusSm; color: Theme.blue } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: e => Status.setBrightness(e.x / width); onPositionChanged: e => { if (pressed) Status.setBrightness(e.x / width); } } }
                        Text { text: Math.round(Status.brightness * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                    RowLayout { Layout.fillWidth: true; spacing: 6; Repeater { model: [ { id: "stealth", l: "Stealth" }, { id: "balanced", l: "Balanced" }, { id: "forge", l: "Forge" }, { id: "arcade", l: "Arcade" } ]
                        Rectangle { required property var modelData; readonly property bool on: Status.workstationMode === modelData.id; Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: on ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: on ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: parent.modelData.l; color: parent.on ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: parent.on ? Font.DemiBold : Font.Normal } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("~/.local/bin/supersettings apply mode " + parent.modelData.id, false) } } } }
                    Item { Layout.fillHeight: true }
                }

                // ==================== 6. POWER & SESSION QUICK FLYOUT ====================
                ColumnLayout {
                    visible: fly.m === "power"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Text { text: "󰐥  Power & session"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 8; rowSpacing: 8; Repeater { model: [ { l: "󰌾  Lock screen", cmd: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", danger: false }, { l: "󰒲  Suspend", cmd: "systemctl suspend", danger: false }, { l: "󰍃  Log out", cmd: "hyprctl dispatch exit", danger: false }, { l: "󰜉  Restart", cmd: "systemctl reboot", danger: true }, { l: "󰐥  Shut down", cmd: "systemctl poweroff", danger: true } ]
                        Rectangle { required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; Layout.columnSpan: modelData.l.includes("Shut down") ? 2 : 1; implicitHeight: 42; radius: Theme.radiusSm; color: pwrM.containsMouse ? (modelData.danger ? Theme.red : Theme.bgHover) : Theme.bgAlt; border.width: 1; border.color: modelData.danger ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: parent.modelData.l; color: pwrM.containsMouse && parent.modelData.danger ? Theme.bg : (parent.modelData.danger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } MouseArea { id: pwrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(parent.modelData.cmd, true) } } } }
                }

                // ==================== 7. CALCULATOR (FEND + KEYPAD) BAR EXPANSION ====================
                ColumnLayout {
                    visible: fly.m === "calc"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "󰪚  Calculator"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Text { text: "= " + fly.calcOut; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 160 } Rectangle { implicitWidth: 54; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Copy"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.copyText(fly.calcOut) } } }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.blue; TextInput { id: calcIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; onTextChanged: fly.evalCalc(text); Keys.onReturnPressed: fly.pressKey("="); Keys.onEscapePressed: event => { fly.close(); event.accepted = true; } } }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 4; columnSpacing: 6; rowSpacing: 6
                        Repeater { model: ["C", "(", ")", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "0", ".", "⌫", "="]
                            Rectangle { required property string modelData; readonly property bool isEq: modelData === "="; readonly property bool isOp: ["÷", "×", "−", "+", "(", ")"].indexOf(modelData) >= 0; readonly property bool isClr: modelData === "C" || modelData === "⌫"; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: isEq ? Theme.blue : (kM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: isEq ? Theme.blue : (isOp ? Theme.cyan : Theme.border)
                                Text { anchors.centerIn: parent; text: parent.modelData; color: parent.isEq ? Theme.bg : (parent.isClr ? Theme.red : (parent.isOp ? Theme.cyan : Theme.fg)); font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold }
                                MouseArea { id: kM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.pressKey(parent.modelData) } } } }
                }

                // ==================== 8. CLIPBOARD HISTORY BAR EXPANSION ====================
                ColumnLayout {
                    visible: fly.m === "clip"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "󰅌  Clipboard"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Rectangle { implicitWidth: 64; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "Clear"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { fly.clipItems = []; fly.run("~/.local/bin/cliphist wipe", true); } } } }
                    Text { visible: fly.clipItems.length === 0; text: "Clipboard history is empty."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                    Repeater { model: fly.clipItems; Rectangle { id: cRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; color: cRowM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: cRowM.containsMouse ? Theme.blue : Theme.border; Text { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: Text.AlignVCenter; text: cRow.modelData.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight } MouseArea { id: cRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("printf '%s' '" + cRow.modelData.raw.replace(/'/g, "'\\''") + "' | ~/.local/bin/cliphist decode | wl-copy", true) } } }
                    Item { Layout.fillHeight: true }
                }

                // ==================== 9. SCREEN RECORDER BAR EXPANSION ====================
                ColumnLayout {
                    visible: fly.m === "record"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: Status.screenRecording ? (Status.screenPaused ? "󰏤  Recording Paused" : "󰻂  Recording Active") : "󰻂  Screen Recorder"; color: Status.screenRecording ? (Status.screenPaused ? Theme.yellow : Theme.red) : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Text { visible: Status.screenRecording; text: "LIVE"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } }
                    Text { text: Status.screenRecording ? "Screen capture is running. Use the controls below to pause, resume, or save your recording to ~/Videos/Recordings." : "Record your full display or select a screen region with audio."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                        Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Status.screenRecording && !Status.screenPaused ? Theme.yellow : Theme.blue; Text { anchors.centerIn: parent; text: !Status.screenRecording ? "󰐊  Start Full Screen Recording" : (Status.screenPaused ? "󰐊  Resume Recording" : "󰏤  Pause Recording"); color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!Status.screenRecording) Status.startScreenRecord(false); else Status.pauseScreenRecord(); } } }
                        Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Status.screenRecording ? Theme.red : Theme.bgAlt; border.width: 1; border.color: Status.screenRecording ? Theme.red : Theme.blue; Text { anchors.centerIn: parent; text: Status.screenRecording ? "󰓛  Stop & Save Recording" : "󰹑  Record Selected Region"; color: Status.screenRecording ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold } MouseArea { id: recM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.screenRecording) { Status.stopScreenRecord(); fly.close(); } else { fly.close(); Status.startScreenRecord(true); } } } } }
                }

                // ==================== 10. QR SCANNER & GENERATOR BAR EXPANSION ====================
                ColumnLayout {
                    visible: fly.m === "qr"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "󰐲  QR Code Tool"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Rectangle { implicitWidth: 118; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "󰹑  Scan Screen"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("~/.local/bin/superbar capture qr", true) } } }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.blue; TextInput { id: qrIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; onTextChanged: fly.genQr(text); Keys.onReturnPressed: fly.genQr(text); Keys.onEscapePressed: event => { fly.close(); event.accepted = true; } } }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true; Rectangle { visible: fly.qrImg !== ""; anchors.centerIn: parent; width: 184; height: 184; radius: Theme.radiusSm; color: "#ffffff"; Image { anchors.fill: parent; anchors.margins: 8; source: fly.qrImg; fillMode: Image.PreserveAspectFit; cache: false } } }
                }

                // ==================== 11. NIGHT LIGHT BAR EXPANSION ====================
                ColumnLayout {
                    visible: fly.m === "nightlight"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "󰖔  Night Light"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true } Rectangle { implicitWidth: 68; implicitHeight: 26; radius: Theme.radiusSm; color: Status.nightLightRunning ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Status.nightLightRunning ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: Status.nightLightRunning ? "On" : "Off"; color: Status.nightLightRunning ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const on = !Status.nightLightRunning; Status.nightLightRunning = on; fly.run("~/.local/bin/supertheme nightlight " + (on ? (Status.nightLightTemp || 4000) : "off"), false); } } } }
                    Text { text: "Warm display color temperature shader reduces blue light strain."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 8; rowSpacing: 8; Repeater { model: [4500, 4000, 3400, 2800]
                        Rectangle { required property int modelData; readonly property bool act: Status.nightLightRunning && Status.nightLightTemp === modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: act ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: act ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: parent.modelData + "K"; color: parent.act ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold } MouseArea { id: nlM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Status.nightLightTemp = parent.modelData; Status.nightLightRunning = true; fly.run("~/.local/bin/supertheme nightlight " + parent.modelData, false); } } } } }
                }

                // ==================== FOOTER: TUI Settings + SuperSettings ====================
                Rectangle { visible: !fly.isTool; Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }
                RowLayout {
                    visible: !fly.isTool; Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        Layout.preferredWidth: 132; implicitHeight: 30; radius: Theme.radiusSm; color: tuiM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: tuiM.containsMouse ? Theme.cyan : Theme.border
                        Text { anchors.centerIn: parent; text: fly.tuiLabelFor(fly.m); color: tuiM.containsMouse ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold }
                        MouseArea { id: tuiM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(fly.tuiCmdFor(fly.m), true) }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; color: moreM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: moreM.containsMouse ? Theme.blue : Theme.border
                        RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 6; Text { text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 } Text { text: fly.moreLabelFor(fly.m); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: "›"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } }
                        MouseArea { id: moreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const p = fly.settingsPageFor(fly.m); fly.close(); Status.openSettings(p); } }
                    }
                }
            }
        }
    }
    Item { id: keyCatcher; anchors.fill: parent; focus: true; Keys.onEscapePressed: event => { fly.close(); Status.playSfx("click"); event.accepted = true; } }
}
