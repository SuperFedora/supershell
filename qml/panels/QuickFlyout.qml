import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."

// Top-Right Quick Actions Flyout for Top Bar status icons, with "More settings ›" footer linking to SuperSettings.
PanelWindow {
    id: fly
    property string mode: "" // "" | "wifi" | "bluetooth" | "speaker" | "mic" | "camera" | "battery" | "power"
    property var targetScreen: Quickshell.screens[0]
    property string wifiPassSsid: ""

    readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real spkVol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool spkMuted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
    readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property var btList: btAdapter ? Bluetooth.devices.values.slice(0, 6) : []
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 100
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    visible: fly.mode !== ""
    screen: fly.targetScreen; color: "transparent"
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 6; right: 8 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 340; implicitHeight: box.implicitHeight

    onModeChanged: { fly.wifiPassSsid = ""; }
    function run(cmd, closeAfter) { if (closeAfter) fly.mode = ""; Status.playSfx("click"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }
    function settingsPageFor(m) { return m === "wifi" ? "network" : ((m === "bluetooth" || m === "camera") ? "devices" : ((m === "battery" || m === "power") ? "power" : "system")); }
    function moreLabelFor(m) {
        if (m === "wifi") return "More Wi-Fi & network settings";
        if (m === "bluetooth") return "More Bluetooth & device settings";
        if (m === "speaker" || m === "mic") return "More sound & audio settings";
        if (m === "camera") return "More camera & privacy settings";
        return "More power & battery settings";
    }
    function wifiClick(w) {
        if (!w) return; const s = String(w.ssid || "").replace(/'/g, "'\\''");
        if (w.active) fly.run("nmcli connection down '" + s + "'; sleep 0.5 && qs ipc call status refresh", false);
        else if (w.saved || w.open) fly.run("nmcli device wifi connect '" + s + "'; sleep 0.8 && qs ipc call status refresh", false);
        else { fly.wifiPassSsid = w.ssid; passIn.text = ""; passIn.forceActiveFocus(); Status.playSfx("click"); }
    }
    function submitPass() {
        if (!fly.wifiPassSsid) return;
        const s = String(fly.wifiPassSsid).replace(/'/g, "'\\''"), p = String(passIn.text).replace(/'/g, "'\\''");
        fly.wifiPassSsid = ""; passIn.text = "";
        fly.run("nmcli device wifi connect '" + s + "' password '" + p + "'; sleep 0.9 && qs ipc call status refresh", false);
    }

    Rectangle {
        id: box; width: parent.width; implicitHeight: mainCol.implicitHeight + 24
        color: Theme.bg; radius: 8; border.width: 1; border.color: Theme.border

        ColumnLayout {
            id: mainCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 } spacing: 8

            // ==================== 1. WI-FI QUICK FLYOUT ====================
            ColumnLayout {
                visible: fly.mode === "wifi"; Layout.fillWidth: true; spacing: 6
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "󰤨  Wi-Fi"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Rectangle { implicitWidth: 68; implicitHeight: 24; radius: 4; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Rescan"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("nmcli device wifi rescan; sleep 1 && qs ipc call status refresh", false) } }
                    Rectangle {
                        implicitWidth: 40; implicitHeight: 22; radius: 11; color: Status.wifiEnabled ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Status.wifiEnabled ? Theme.blue : Theme.muted
                        Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: Status.wifiEnabled ? 21 : 4; color: Status.wifiEnabled ? Theme.bg : Theme.fgDim }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWifiRadio() }
                    }
                }
                Text { text: !Status.wifiEnabled ? "Wi-Fi radio is off" : (Status.ssid ? ("Connected: " + Status.ssid + " (" + Status.signal + "%)  ·  " + Status.netIpv4) : "Not connected — select a network:"); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
                RowLayout {
                    visible: fly.wifiPassSsid !== ""; Layout.fillWidth: true; spacing: 6
                    Rectangle { Layout.fillWidth: true; implicitHeight: 28; radius: 4; color: Theme.bgAlt; border.width: 1; border.color: Theme.blue; TextInput { id: passIn; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; echoMode: TextInput.Password; clip: true; Keys.onReturnPressed: fly.submitPass() } }
                    Rectangle { implicitWidth: 68; implicitHeight: 28; radius: 4; color: Theme.blue; Text { anchors.centerIn: parent; text: "Join"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.submitPass() } }
                }
                Repeater {
                    model: Status.wifiList.slice(0, 6)
                    Rectangle {
                        id: wItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: modelData.active ? Theme.bgAlt : (wItemM.containsMouse ? Theme.bgHover : "transparent"); border.width: modelData.active ? 1 : 0; border.color: Theme.blue
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                            Text { text: (wItem.modelData.active ? "● " : "󰤨 ") + wItem.modelData.ssid; color: wItem.modelData.active ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: wItem.modelData.active ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: wItem.modelData.signal + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                        }
                        MouseArea { id: wItemM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.wifiClick(wItem.modelData) }
                    }
                }
            }

            // ==================== 2. BLUETOOTH QUICK FLYOUT ====================
            ColumnLayout {
                visible: fly.mode === "bluetooth"; Layout.fillWidth: true; spacing: 6
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "󰂯  Bluetooth"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Rectangle { implicitWidth: 64; implicitHeight: 24; radius: 4; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Scan"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false) } }
                    Rectangle {
                        implicitWidth: 40; implicitHeight: 22; radius: 11; color: fly.btOn ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: fly.btOn ? Theme.blue : Theme.muted
                        Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: fly.btOn ? 21 : 4; color: fly.btOn ? Theme.bg : Theme.fgDim }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(fly.btOn ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) }
                    }
                }
                Text { visible: fly.btList.length === 0; text: fly.btOn ? "No paired devices found. Click Scan above." : "Bluetooth is turned off."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                Repeater {
                    model: fly.btList
                    Rectangle {
                        id: bRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: modelData.connected ? Theme.bgAlt : (bRowM.containsMouse ? Theme.bgHover : "transparent"); border.width: modelData.connected ? 1 : 0; border.color: Theme.blue
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                            Text { text: "󰂯  " + (bRow.modelData.name || "Device"); color: bRow.modelData.connected ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: bRow.modelData.connected ? "Connected" : "Connect"; color: bRow.modelData.connected ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                        }
                        MouseArea { id: bRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(bRow.modelData.connected ? ("bluetoothctl disconnect " + bRow.modelData.address) : ("bluetoothctl connect " + bRow.modelData.address), false) }
                    }
                }
            }

            // ==================== 3. SPEAKER / MIC AUDIO QUICK FLYOUT ====================
            ColumnLayout {
                visible: fly.mode === "speaker" || fly.mode === "mic"; Layout.fillWidth: true; spacing: 8
                readonly property bool isSpk: fly.mode === "speaker"
                readonly property real curVol: isSpk ? fly.spkVol : fly.micVol
                readonly property bool curMuted: isSpk ? fly.spkMuted : fly.micMuted
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: parent.isSpk ? "󰕾  Speaker output" : "󰍬  Microphone input"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 68; implicitHeight: 24; radius: 4; color: parent.curMuted ? Theme.red : Theme.bgAlt; border.width: 1; border.color: parent.curMuted ? Theme.red : Theme.border
                        Text { anchors.centerIn: parent; text: parent.parent.curMuted ? "Muted" : (Math.round(parent.parent.curVol * 100) + "%"); color: parent.parent.curMuted ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (fly.mode === "speaker") Status.toggleSpeakerMute(); else Status.toggleMicMute(); } }
                    }
                }
                Item {
                    Layout.fillWidth: true; implicitHeight: 24
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.bgAlt; border.width: 1; border.color: Theme.border }
                    Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * Math.max(0, Math.min(1, parent.parent.curVol))); height: 6; radius: 3; color: Theme.blue }
                    Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * parent.parent.curVol) - 8)); color: Theme.blue; border.width: 3; border.color: Theme.bg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: e => { if (fly.mode === "speaker") Status.setSpeakerVolume(e.x / width); else Status.setMicVolume(e.x / width); } onPositionChanged: e => { if (pressed) { if (fly.mode === "speaker") Status.setSpeakerVolume(e.x / width); else Status.setMicVolume(e.x / width); } } }
                }
                Text { text: parent.isSpk ? "Output devices" : "Input devices"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                Repeater {
                    model: fly.mode === "speaker" ? Status.audioSinks : Status.audioSources
                    Rectangle {
                        id: audItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: modelData.active ? Theme.bgAlt : (audM.containsMouse ? Theme.bgHover : "transparent"); border.width: modelData.active ? 1 : 0; border.color: Theme.blue
                        Text { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: Text.AlignVCenter; text: (audItem.modelData.active ? "●  " : "○  ") + audItem.modelData.name; color: audItem.modelData.active ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight }
                        MouseArea { id: audM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(audItem.modelData.id) }
                    }
                }
            }

            // ==================== 4. CAMERA & PRIVACY QUICK FLYOUT ====================
            ColumnLayout {
                visible: fly.mode === "camera"; Layout.fillWidth: true; spacing: 8
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "󰄀  Camera & hardware privacy"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 40; implicitHeight: 22; radius: 11; color: Status.webcamEnabled ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Status.webcamEnabled ? Theme.blue : Theme.muted
                        Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: Status.webcamEnabled ? 21 : 4; color: Status.webcamEnabled ? Theme.bg : Theme.fgDim }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWebcam() }
                    }
                }
                Text { text: Status.webcamEnabled ? "Webcam driver (uvcvideo) is enabled" : "Webcam kernel driver is unloaded (hardware lock)"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Rectangle { Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰌌  Kbd Light: " + (Status.kbdBacklight === 0 ? "Off" : (Status.kbdBacklight === 1 ? "Low" : "High")); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setKbdBacklight() } }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: Status.micMuted ? "󰍭  Unmute Mic" : "󰍬  Mute Mic"; color: Status.micMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleMicMute() } }
                }
            }

            // ==================== 5. BATTERY & POWER QUICK FLYOUT ====================
            ColumnLayout {
                visible: fly.mode === "battery" || fly.mode === "power"; Layout.fillWidth: true; spacing: 8
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: fly.mode === "battery" ? ("󰁹  Battery (" + fly.batPct + "%)") : "󰐥  Power & session"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Text { text: "Mode: " + Status.workstationMode; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "󰃠"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    Item {
                        Layout.fillWidth: true; implicitHeight: 22
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.bgAlt; border.width: 1; border.color: Theme.border }
                        Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * Status.brightness); height: 6; radius: 3; color: Theme.blue }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: e => Status.setBrightness(e.x / width); onPositionChanged: e => { if (pressed) Status.setBrightness(e.x / width); } }
                    }
                    Text { text: Math.round(Status.brightness * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [ { id: "stealth", l: "Stealth" }, { id: "balanced", l: "Balanced" }, { id: "forge", l: "Forge" }, { id: "arcade", l: "Arcade" } ]
                        Rectangle {
                            required property var modelData; readonly property bool on: Status.workstationMode === modelData.id
                            Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: on ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: on ? Theme.blue : Theme.border
                            Text { anchors.centerIn: parent; text: parent.modelData.l; color: parent.on ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: parent.on ? Font.DemiBold : Font.Normal }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fly.run("~/.local/bin/supersettings apply mode " + parent.modelData.id, false) }
                        }
                    }
                }
                GridLayout {
                    visible: fly.mode === "power"; Layout.fillWidth: true; columns: 2; columnSpacing: 6; rowSpacing: 6
                    Repeater {
                        model: [
                            { l: "󰌾  Lock screen", cmd: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", danger: false },
                            { l: "󰒲  Suspend",     cmd: "systemctl suspend", danger: false },
                            { l: "󰜉  Restart",     cmd: "systemctl reboot", danger: true },
                            { l: "󰐥  Shut down",   cmd: "systemctl poweroff", danger: true }
                        ]
                        Rectangle {
                            required property var modelData; Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: pwrM.containsMouse ? (modelData.danger ? Theme.red : Theme.bgHover) : Theme.bgAlt; border.width: 1; border.color: modelData.danger ? Theme.red : Theme.border
                            Text { anchors.centerIn: parent; text: parent.modelData.l; color: pwrM.containsMouse && parent.modelData.danger ? Theme.bg : (parent.modelData.danger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                            MouseArea { id: pwrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fly.run(parent.modelData.cmd, true) }
                        }
                    }
                }
            }

            // ==================== FOOTER: "More settings ›" -> SuperSettings ====================
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 32; radius: 5
                color: moreM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: moreM.containsMouse ? Theme.blue : Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 8
                    Text { text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    Text { text: fly.moreLabelFor(fly.mode); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Text { text: "›"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                }
                MouseArea {
                    id: moreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { const p = fly.settingsPageFor(fly.mode); fly.mode = ""; Status.openSettings(p); }
                }
            }
        }
    }
}
