import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

// Scrollable Windows 11-Style Touch Settings Pane: Auto-filters across all 10 categories + live sub-panels.
Item {
    id: pg
    property string activePage: "system"
    property string searchQuery: ""
    property string wifiPassSsid: ""
    signal executeCommand(string cmd, bool closeAfter)

    SettingsRegistry { id: reg }
    readonly property var categories: reg.categories
    readonly property string qNorm: pg.searchQuery.trim().toLowerCase()
    readonly property var btList: reg.btAdapter ? Bluetooth.devices.values.slice(0, 8) : []
    readonly property var aiAgents: [
        { id: "agy", l: "AGY" }, { id: "mcode", l: "MCODE" }, { id: "grok", l: "GROK" },
        { id: "vibe", l: "VIBE" }, { id: "claude", l: "CLAUDE" }, { id: "chatgpt", l: "CODEX" }, { id: "ollama", l: "OLLAMA (PI)" }
    ]

    function matchesQuery(item, q) {
        if (!q) return true;
        const hay = (item.title + " " + item.sub + " " + item.kw + " " + item.tag + " " + item.cats.join(" ")).toLowerCase();
        for (const w of q.split(/\s+/)) if (w && !hay.includes(w)) return false;
        return true;
    }
    function matchCountFor(catId, qStr) {
        const q = String(qStr || "").trim().toLowerCase();
        let n = 0;
        for (const it of reg.items) if (it.cats.indexOf(catId) >= 0 && pg.matchesQuery(it, q)) n++;
        return n;
    }
    readonly property var visibleItems: {
        const q = pg.qNorm;
        return q !== "" ? reg.items.filter(it => pg.matchesQuery(it, q)) : reg.items.filter(it => it.cats.indexOf(pg.activePage) >= 0);
    }
    function showSub(catId, kwList) {
        if (pg.qNorm === "") return pg.activePage === catId;
        for (const k of kwList) if (pg.qNorm.includes(k)) return true;
        return false;
    }
    function escSh(s) { return String(s || "").replace(/'/g, "'\\''"); }
    function triggerAction(a) {
        if (!a) return;
        if (a.act === "cmd") pg.executeCommand(a.v, false); else if (a.act === "cmdClose") pg.executeCommand(a.v, true);
        else if (a.act === "bright") Status.setBrightness(Status.brightness + Number(a.v)); else if (a.act === "brightSet") Status.setBrightness(Number(a.v));
        else if (a.act === "spkMute") Status.toggleSpeakerMute(); else if (a.act === "spkStep") Status.setSpeakerVolume(Status.spkVol + Number(a.v)); else if (a.act === "spkSet") Status.setSpeakerVolume(Number(a.v));
        else if (a.act === "micMute") Status.toggleMicMute(); else if (a.act === "micStep") Status.setMicVolume(Status.micVol + Number(a.v)); else if (a.act === "micSet") Status.setMicVolume(Number(a.v));
        else if (a.act === "kbdLight") Status.setKbdBacklight(); else if (a.act === "webcam") Status.toggleWebcam(); else if (a.act === "wifiToggle") Status.toggleWifiRadio();
        else if (a.act === "sfxToggle") Status.toggleSfx(); else if (a.act === "dock") Status.runDockCmd(a.v);
        else if (a.act === "barOpacity") { Theme.barOpacity = Theme.barOpacity < 0.99 ? 1.0 : 0.85; Status.playSfx("toggle"); }
        else if (a.act === "notif") { if (Status.notifAction) Status.notifAction(a.v, ""); } else if (a.act === "banner") { if (Status.notifAction) Status.notifAction("banner", a.v); } else if (a.act === "cast") { if (Status.notifAction) Status.notifAction("cast", a.v); }
        else if (a.act === "clock24") Status.saveClockPrefs(!Status.clock24h, Status.clockSeconds); else if (a.act === "clockSec") Status.saveClockPrefs(Status.clock24h, !Status.clockSeconds);
    }
    function wifiTrigger(w) {
        if (!w) return;
        const s = pg.escSh(w.ssid);
        if (w.active) pg.executeCommand("nmcli connection down '" + s + "'; sleep 0.5 && qs ipc call status refresh", false);
        else if (w.saved || w.open) pg.executeCommand("nmcli device wifi connect '" + s + "'; sleep 0.8 && qs ipc call status refresh", false);
        else { pg.wifiPassSsid = w.ssid; wifiPassIn.text = ""; wifiPassIn.forceActiveFocus(); Status.playSfx("click"); }
    }
    function submitWifiPass() {
        if (!pg.wifiPassSsid) return;
        const s = pg.escSh(pg.wifiPassSsid), p = pg.escSh(wifiPassIn.text);
        pg.wifiPassSsid = ""; wifiPassIn.text = "";
        pg.executeCommand("nmcli device wifi connect '" + s + "' password '" + p + "'; sleep 0.9 && qs ipc call status refresh", false);
    }

    onActivePageChanged: flick.contentY = 0
    onSearchQueryChanged: flick.contentY = 0

    Flickable {
        id: flick; anchors { fill: parent; margins: 12 }
        contentWidth: width; contentHeight: contentCol.implicitHeight + 24
        clip: true; boundsBehavior: Flickable.DragOverBounds; flickDeceleration: 3500

        ColumnLayout {
            id: contentCol; width: flick.width - 10; spacing: 8

            Rectangle {
                visible: pg.visibleItems.length === 0
                Layout.fillWidth: true; implicitHeight: 96; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "No settings matched \"" + pg.searchQuery + "\". Try another keyword (e.g. printer, scale, bluetooth, ssh, btrfs)."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
            }

            // Declarative Touch-Friendly Windows-Style Setting Cards
            Repeater {
                model: pg.visibleItems
                Rectangle {
                    id: sCard; required property var modelData
                    Layout.fillWidth: true; implicitHeight: Math.max(68, cardRow.implicitHeight + 20)
                    radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    RowLayout {
                        id: cardRow; anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 10 } spacing: 12
                        Rectangle {
                            implicitWidth: 52; implicitHeight: 36; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: sCard.modelData.tag; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: sCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: sCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: sCard.modelData.acts || []
                                Rectangle {
                                    id: actBtn; required property var modelData
                                    readonly property bool isOn: Boolean(modelData.on)
                                    readonly property bool isDanger: Boolean(modelData.danger)
                                    readonly property color accentCol: isDanger ? Theme.red : (isOn ? Theme.cyan : Theme.blue)
                                    implicitWidth: Math.max(96, actTxt.implicitWidth + 22); implicitHeight: 42; radius: Theme.radiusSm
                                    color: actM.containsMouse ? accentCol : (isOn ? Theme.blue : Theme.bg)
                                    border.width: isOn || actM.containsMouse ? 2 : 1; border.color: accentCol
                                    Text { id: actTxt; anchors.centerIn: parent; text: actBtn.modelData.l; color: (actM.containsMouse || actBtn.isOn) ? Theme.bg : (actBtn.isDanger ? Theme.red : Theme.cyan); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                                    MouseArea { id: actM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction(actBtn.modelData) }
                                }
                            }
                        }
                    }
                }
            }

            // Sub-Panel A: PipeWire Audio Output / Input Device Selector
            Rectangle {
                visible: pg.showSub("system", ["audio", "sound", "speaker", "mic", "pipewire", "sink"])
                Layout.fillWidth: true; implicitHeight: audCol.implicitHeight + 20; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    id: audCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 6
                    Text { text: "▸ PIPEWIRE OUTPUT & INPUT HARDWARE ROUTING (TAP TO SET DEFAULT)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [ { hdr: "OUTPUT SINKS", list: Status.audioSinks }, { hdr: "INPUT SOURCES", list: Status.audioSources } ]
                            ColumnLayout {
                                required property var modelData; Layout.fillWidth: true; spacing: 4
                                Text { text: parent.modelData.hdr; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                                Repeater {
                                    model: parent.modelData.list
                                    Rectangle {
                                        id: aDev; required property var modelData; Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm
                                        color: modelData.active ? Theme.blue : (aDevM.containsMouse ? Theme.bgHover : Theme.bg); border.width: modelData.active ? 2 : 1; border.color: modelData.active ? Theme.cyan : Theme.border
                                        Text { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: Text.AlignVCenter; text: (aDev.modelData.active ? "▸ [DEFAULT] " : "  ") + aDev.modelData.name; color: aDev.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight }
                                        MouseArea { id: aDevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(aDev.modelData.id) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Sub-Panel B: Bluetooth Device Pairing List
            Rectangle {
                visible: pg.showSub("devices", ["bluetooth", "bt", "pair", "headphones"])
                Layout.fillWidth: true; implicitHeight: btCol.implicitHeight + 20; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    id: btCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 6
                    Text { text: "▸ BLUETOOTH PERIPHERALS (" + pg.btList.length + " DISCOVERED / PAIRED)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    Text { visible: pg.btList.length === 0; text: "No Bluetooth devices in list. Tap [ SCAN 10s ] above to discover nearby peripherals."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                    Repeater {
                        model: pg.btList
                        Rectangle {
                            id: btItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radiusSm; color: modelData.connected ? Theme.bg : Theme.bgHover; border.width: 1; border.color: modelData.connected ? Theme.cyan : Theme.border
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                Text { text: "▸ " + (btItem.modelData.name || "Unknown") + "  [" + btItem.modelData.address + "]"; color: btItem.modelData.connected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Rectangle { implicitWidth: 132; implicitHeight: 34; radius: Theme.radiusSm; color: btItem.modelData.connected ? Theme.green : Theme.blue; Text { anchors.centerIn: parent; text: btItem.modelData.connected ? "[ DISCONNECT ]" : "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(btItem.modelData.connected ? ("bluetoothctl disconnect " + btItem.modelData.address) : ("bluetoothctl connect " + btItem.modelData.address), false) } }
                                Rectangle { visible: btItem.modelData.paired; implicitWidth: 96; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ FORGET ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("bluetoothctl remove " + btItem.modelData.address, false) } }
                            }
                        }
                    }
                }
            }

            // Sub-Panel C: Wi-Fi Access Points & Inline Password Prompt
            Rectangle {
                visible: pg.showSub("network", ["wifi", "wireless", "ssid", "wlan"])
                Layout.fillWidth: true; implicitHeight: wfCol.implicitHeight + 20; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    id: wfCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 6
                    Text { text: "▸ AVAILABLE WI-FI NETWORKS (TAP TO CONNECT OR DISCONNECT)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    RowLayout {
                        visible: pg.wifiPassSsid !== ""; Layout.fillWidth: true; spacing: 8
                        Text { text: "WPA PASSWORD FOR " + pg.wifiPassSsid + ":"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: Theme.cyan; TextInput { id: wifiPassIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; echoMode: TextInput.Password; clip: true; Keys.onReturnPressed: pg.submitWifiPass(); Keys.onEscapePressed: Status.settingsOpen = false } }
                        Rectangle { implicitWidth: 116; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.green; Text { anchors.centerIn: parent; text: "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitWifiPass() } }
                    }
                    Repeater {
                        model: Status.wifiList
                        Rectangle {
                            id: wRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radiusSm; color: modelData.active ? Theme.bg : (wRowM.containsMouse ? Theme.bgHover : "transparent"); border.width: 1; border.color: modelData.active ? Theme.cyan : Theme.border
                            MouseArea { id: wRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.wifiTrigger(wRow.modelData) }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                Text { text: (wRow.modelData.active ? "▸ [CONNECTED] " : "  ") + wRow.modelData.ssid; color: wRow.modelData.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: "[" + wRow.modelData.security + "]  " + wRow.modelData.signal + "%"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                                Rectangle { implicitWidth: 118; implicitHeight: 34; radius: Theme.radiusSm; color: wRow.modelData.active ? Theme.green : Theme.blue; Text { anchors.centerIn: parent; text: wRow.modelData.active ? "[ DISCONNECT ]" : "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                            }
                        }
                    }
                }
            }

            // Sub-Panel D: Reusable Modules (Themes, Bar Icons, Forge, Startup, AI)
            LauncherMenu {
                visible: pg.showSub("personalization", ["theme", "palette", "rgb", "openrgb"]) || pg.showSub("windowing", ["bar", "icon", "divider"]) || pg.showSub("apps", ["forge", "webapp", "compile", "claude", "chatgpt"])
                Layout.fillWidth: true; implicitHeight: 330
                activeSection: pg.showSub("windowing", ["bar", "icon", "divider"]) ? "shell" : (pg.showSub("apps", ["forge", "webapp", "compile", "claude", "chatgpt"]) ? "forge" : "theme")
                onExecuteCommand: (c, cl) => pg.executeCommand(c, cl)
                onCloseRequested: Status.settingsOpen = false
            }

            // Sub-Panel E: Startup Apps & Default AI Harness Selector
            Rectangle {
                visible: pg.showSub("apps", ["startup", "autostart", "login"]) || pg.showSub("power", ["ai", "ollama", "agent", "harness"])
                Layout.fillWidth: true; implicitHeight: stCol.implicitHeight + 20; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    id: stCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 8
                    Text { text: "▸ DEFAULT AI HARNESS & STARTUP LOGIN APPLICATIONS"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: pg.aiAgents
                            Rectangle {
                                id: agBtn; required property var modelData; readonly property bool isCur: Status.aiAgent === modelData.id
                                Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: isCur ? Theme.blue : Theme.bg; border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                                Text { anchors.centerIn: parent; text: agBtn.modelData.l; color: agBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.selectAiAgent(agBtn.modelData.id) }
                            }
                        }
                        Rectangle { implicitWidth: 164; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ OLLAMA MODEL ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("~/.config/hypr/scripts/quake-ai.sh prompt-ollama", false) } }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: startupIn.activeFocus ? Theme.cyan : Theme.border; TextInput { id: startupIn; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; Keys.onReturnPressed: { if (startupIn.text.trim()) { Status.addStartupApp(startupIn.text.trim()); startupIn.text = ""; } } Keys.onEscapePressed: Status.settingsOpen = false; Text { visible: startupIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Add startup command to ~/.config/hypr/conf/autostart.conf (e.g. discord, synology-drive)..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } }
                        Rectangle { implicitWidth: 164; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.green; Text { anchors.centerIn: parent; text: "[ + ADD STARTUP ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (startupIn.text.trim()) { Status.addStartupApp(startupIn.text.trim()); startupIn.text = ""; } } } }
                    }
                }
            }
        }
    }
}
