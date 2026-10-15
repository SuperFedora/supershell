import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".."

// SuperDesk 16-Bit Quick Actions: [1] SYS (Fastfetch & btop) + [4] AUDIO (Privacy & PipeWire) + [5] DISPLAY (Brightness, Kbd & Idle).
ColumnLayout {
    id: audioDeck
    property string activeTab: "audio"
    signal executeCommand(string cmd, bool closeAfter)
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

    readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
    function asciiBar(pct) { const f = Math.max(0, Math.min(12, Math.round((pct / 100.0) * 12))); return "[" + "█".repeat(f) + "░".repeat(12 - f) + "]"; }

    // ---------------- [1] SYS: Fastfetch Hardware Specs & btop Live Process Monitor ----------------
    ColumnLayout {
        visible: audioDeck.activeTab === "sys"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 68; spacing: 8
            Repeater {
                model: [
                    { t: "CPU LOAD", v: Status.cpu + "%", b: audioDeck.asciiBar(Status.cpu), c: Status.cpu > 80 ? Theme.red : Theme.cyan },
                    { t: "MEMORY", v: Status.mem + "%", b: audioDeck.asciiBar(Status.mem), c: Status.mem > 85 ? Theme.yellow : Theme.blue },
                    { t: "THERMAL / GPU", v: Status.tempC + "°C · " + Status.gpu + "%", b: audioDeck.asciiBar(Status.tempC), c: Status.tempC > 80 ? Theme.red : Theme.green },
                    { t: "NETWORK I/O", v: "↓" + Math.round(Status.netRxKbps) + " ↑" + Math.round(Status.netTxKbps) + " KB/s", b: "[" + Status.netType.toUpperCase() + "]", c: Theme.yellow }
                ]
                Rectangle {
                    id: sysCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.c
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 1; Text { Layout.alignment: Qt.AlignHCenter; text: sysCard.modelData.t; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: sysCard.modelData.v; color: sysCard.modelData.c; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: sysCard.modelData.b; color: sysCard.modelData.c; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue; clip: true
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    anchors { fill: parent; margins: 10 } spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "▸ FASTFETCH // WORKSTATION"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                        Rectangle { implicitWidth: 146; implicitHeight: 24; radius: Theme.radiusSm; color: ffM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ 󰣛 OPEN FASTFETCH ]"; color: ffM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: ffM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: audioDeck.executeCommand("kitty --class floating-term -e bash -c 'fastfetch; echo; read -n1 -rsp \"Press any key to close...\"'", false) } }
                    }
                    Repeater {
                        model: Status.fastfetchList.slice(0, 10)
                        RowLayout {
                            id: ffRow; required property var modelData; Layout.fillWidth: true; spacing: 6
                            Text { text: ffRow.modelData.k + ":"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.preferredWidth: 112; elide: Text.ElideRight }
                            Text { text: ffRow.modelData.v; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue; clip: true
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    anchors { fill: parent; margins: 10 } spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "▸ BTOP // TOP PROCESSES"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                        Rectangle { implicitWidth: 124; implicitHeight: 24; radius: Theme.radiusSm; color: btM2.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ 󰍛 OPEN MONITOR ]"; color: btM2.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: btM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: audioDeck.executeCommand("xdg-terminal-exec --monitor", false) } }
                    }
                    Repeater {
                        model: Status.topProcs.slice(0, 6)
                        Rectangle {
                            id: prRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6
                                Text { text: prRow.modelData.pid; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.preferredWidth: 56 }
                                Text { text: prRow.modelData.cmd; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: prRow.modelData.cpu + "% CPU"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.preferredWidth: 66; horizontalAlignment: Text.AlignRight }
                                Text { text: prRow.modelData.mem + "% MEM"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.preferredWidth: 66; horizontalAlignment: Text.AlignRight }
                                Rectangle { implicitWidth: 56; implicitHeight: 20; radius: Theme.radiusSm; color: klM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[KILL]"; color: klM.containsMouse ? Theme.bg : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { id: klM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: audioDeck.executeCommand("kill -15 " + prRow.modelData.pid + " 2>/dev/null; sleep 0.3 && qs ipc call status refresh", false) } }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ---------------- [4] AUDIO: Hardware Privacy Gates & PipeWire Routing ----------------
    ColumnLayout {
        visible: audioDeck.activeTab === "audio"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 58; spacing: 8
            Repeater {
                model: [
                    { id: "cam", label: Status.webcamEnabled ? "[ 󰄀 CAMERA: ON ]" : "[ 󰗟 CAMERA: OFF ]", col: Status.webcamEnabled ? Theme.green : Theme.red },
                    { id: "mic", label: !audioDeck.micMuted ? "[ 󰍬 MIC: LIVE ]" : "[ 󰍭 MIC: MUTED ]", col: !audioDeck.micMuted ? Theme.green : Theme.red },
                    { id: "spk", label: !audioDeck.muted ? "[ 󰕾 SPEAKERS: LIVE ]" : "[ 󰝟 SPEAKERS: MUTED ]", col: !audioDeck.muted ? Theme.cyan : Theme.red }
                ]
                Rectangle {
                    id: gateCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius
                    color: gMouse.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    Text { anchors.centerIn: parent; text: (gMouse.containsMouse ? "▸ " : "") + gateCard.modelData.label; color: gateCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: gMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const k = gateCard.modelData.id; if (k === "cam") Status.toggleWebcam(); else if (k === "mic") { const m = !audioDeck.micMuted; if (audioDeck.micReady) audioDeck.source.audio.muted = m; Status.toggleMicMute(m); } else { const m = !audioDeck.muted; if (audioDeck.audioReady) audioDeck.sink.audio.muted = m; Status.toggleSpeakerMute(m); } } }
                }
            }
        }
        Repeater {
            model: [
                { id: "spk", title: "󰕾  SPEAKERS VOLUME", val: audioDeck.vol, muted: audioDeck.muted, col: Theme.blue, hiCol: Theme.cyan },
                { id: "mic", title: "󰍬  MICROPHONE GAIN", val: audioDeck.micVol, muted: audioDeck.micMuted, col: Theme.green, hiCol: Theme.cyan }
            ]
            Rectangle {
                id: tankCard; required property var modelData; Layout.fillWidth: true; implicitHeight: 74; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.muted ? Theme.red : Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    anchors { fill: parent; margins: 10 } spacing: 6
                    RowLayout { Layout.fillWidth: true; spacing: 10; Text { text: "▸ " + tankCard.modelData.title; color: tankCard.modelData.muted ? Theme.red : tankCard.modelData.hiCol; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: (tankCard.modelData.muted ? "[MUTED] " : "") + Math.round(tankCard.modelData.val * 100) + "%"; color: tankCard.modelData.muted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } }
                    Item {
                        Layout.fillWidth: true; height: 22
                        RowLayout { anchors.fill: parent; spacing: 4; Repeater { model: 16; Rectangle { required property int index; readonly property bool lit: (index + 1) / 16.0 <= tankCard.modelData.val + 0.02; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; border.width: 1; border.color: lit ? Theme.cyan : Theme.border; color: !lit ? Theme.bg : (tankCard.modelData.muted ? Theme.muted : (index >= 12 ? tankCard.modelData.hiCol : tankCard.modelData.col)) } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; function apply(mx) { const v = Math.max(0, Math.min(1, Math.round((mx / width) * 16) / 16.0)); if (tankCard.modelData.id === "spk") { if (audioDeck.audioReady) audioDeck.sink.audio.volume = v; Status.setSpeakerVolume(v); } else { if (audioDeck.micReady) audioDeck.source.audio.volume = v; Status.setMicVolume(v); } } onPressed: e => apply(e.x); onPositionChanged: e => { if (pressed) apply(e.x); } }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 6
                Text { text: "▸ PIPEWIRE AUDIO ROUTING"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    Text { text: "OUTPUT DEVICE:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.preferredWidth: 124 }
                    Repeater { model: Status.audioSinks; Rectangle { id: snkBtn; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: snkM.containsMouse ? Theme.bgHover : (modelData.active ? Theme.blue : Theme.bg); border.width: modelData.active ? 2 : 1; border.color: modelData.active ? Theme.cyan : Theme.border; Text { anchors.centerIn: parent; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: (snkBtn.modelData.active ? "▸ " : "") + snkBtn.modelData.name; color: snkBtn.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: snkM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(snkBtn.modelData.id) } } }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    Text { text: "INPUT DEVICE:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.preferredWidth: 124 }
                    Repeater { model: Status.audioSources; Rectangle { id: srcBtn; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: srcM.containsMouse ? Theme.bgHover : (modelData.active ? Theme.blue : Theme.bg); border.width: modelData.active ? 2 : 1; border.color: modelData.active ? Theme.cyan : Theme.border; Text { anchors.centerIn: parent; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: (srcBtn.modelData.active ? "▸ " : "") + srcBtn.modelData.name; color: srcBtn.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: srcM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(srcBtn.modelData.id) } } }
                }
            }
        }
    }

    // ---------------- [5] DISPLAY: Display Brightness, Keyboard Backlight & Idle Controls ----------------
    ColumnLayout {
        visible: audioDeck.activeTab === "display"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 88; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 8
                RowLayout { Layout.fillWidth: true; Text { text: "▸ 󰃠  DISPLAY BACKLIGHT BRIGHTNESS"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: Math.round(Status.brightness * 100) + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } }
                Item {
                    Layout.fillWidth: true; height: 24
                    RowLayout { anchors.fill: parent; spacing: 4; Repeater { model: 16; Rectangle { required property int index; readonly property bool lit: (index + 1) / 16.0 <= Status.brightness + 0.02; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; border.width: 1; border.color: lit ? Theme.yellow : Theme.border; color: lit ? Theme.yellow : Theme.bg } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; function apply(mx) { Status.setBrightness(Math.max(0.06, Math.min(1, Math.round((mx / width) * 16) / 16.0))); } onPressed: e => apply(e.x); onPositionChanged: e => { if (pressed) apply(e.x); } }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 96; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 8
                RowLayout { Layout.fillWidth: true; Text { text: "▸ 󰌌  KEYBOARD BACKLIGHT"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: "AUTO-OFF WITH SCREEN: ENABLED"; color: Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Repeater { model: [ { lvl: 0, label: "[ OFF (0%) ]" }, { lvl: 1, label: "[ LOW (50%) ]" }, { lvl: 2, label: "[ HIGH (100%) ]" } ]; Rectangle { id: kbBtn; required property var modelData; readonly property bool isCur: Status.kbdBacklight === modelData.lvl; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: kbBM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bg); border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border; Text { anchors.centerIn: parent; text: (kbBtn.isCur ? "▸ " : "") + kbBtn.modelData.label; color: kbBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } MouseArea { id: kbBM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setKbdBacklight(kbBtn.modelData.lvl) } } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Repeater {
                model: [
                    { label: Status.idleMode === "lock" ? "[ 󰅶 󰌾 COFFEE: LOCK ONLY ]" : (Status.idleMode === "screensaver" ? "[ 󰅶 COFFEE: SCREENSAVER ]" : "[ 󰒲 AUTO-IDLE: POWER OFF ]"), sub: Status.idleMode === "lock" ? "2m Screensaver → 5m Lock (No Screen Off)" : (Status.idleMode === "screensaver" ? "2m Screensaver · Never Locks or Off" : "2m Screensaver → 5m Lock → 10m Off"), cmd: "idle", close: false, col: Status.idleMode === "lock" ? Theme.cyan : (Status.idleMode === "screensaver" ? Theme.yellow : Theme.blue) },
                    { label: "[ 󰍹 START IDLESCREEN ]", sub: "Super + Shift + I", cmd: "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" idlescreen start", close: true, col: Theme.green },
                    { label: "[ 󰍸 TOGGLE TOUCHPAD ]", sub: "ELAN Touchpad", cmd: "~/.config/hypr/scripts/toggle-touchpad.sh touchpad", close: false, col: Theme.blue }
                ]
                Rectangle {
                    id: dpCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: dpM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: dpCard.modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 4; Text { Layout.alignment: Qt.AlignHCenter; text: (dpM.containsMouse ? "▸ " : "") + dpCard.modelData.label; color: dpCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: dpCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                    MouseArea { id: dpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (dpCard.modelData.cmd === "idle") Status.toggleIdle(); else audioDeck.executeCommand(dpCard.modelData.cmd, dpCard.modelData.close); } }
                }
            }
        }
    }
}
