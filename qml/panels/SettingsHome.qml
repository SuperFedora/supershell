import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

// Windows 11 (WinUI 3 / Fluent) Settings Home Dashboard: Live Wallpaper Monitor Banner + 2x2 Interactive Cards Grid.
Item {
    id: home
    property string hostShort: "workstation"
    property bool paneFocused: false; property int kbIndex: 0; readonly property int kbCount: 27
    signal selectCategory(string catId); signal executeCommand(string cmd, bool closeAfter)

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btList: btAdapter ? Bluetooth.devices.values.slice(0, 3) : []
    readonly property var recList: (Status.recentSettings && Status.recentSettings.length > 0) ? Status.recentSettings.slice(0, 4) : []
    readonly property string wpPath: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""
    readonly property bool isWide: home.width >= 820; readonly property bool isMedium: home.width >= 640; readonly property bool isCompact: home.width < 560
    readonly property int visibleHeroPills: home.width >= 920 ? 3 : (home.width >= 820 ? 2 : 0)
    readonly property var powerModes: [ { id: "stealth", l: "Stealth" }, { id: "balanced", l: "Balanced" }, { id: "forge", l: "Forge" }, { id: "arcade", l: "Arcade" } ]
    readonly property var pNavItems: [
        { cat: "system", id: "disp-bright", subId: "", icon: "󰍹", title: "Display & monitor layout", val: String(Status.displayLayout || "").split("|")[0] || ("Brightness " + Math.round(Status.brightness * 100) + "%"), btn: "Display 󰅂" },
        { cat: "system", id: "snd-spk", subId: "snd-sinks", icon: "󰕾", title: "Sound & PipeWire audio", val: Status.spkName + " (" + Math.round(Status.spkVol * 100) + "%)", btn: "Audio 󰅂" },
        { cat: "devices", id: "dev-touchpad", subId: "", icon: "󰟸", title: "Touchpad & input devices", val: Status.touchpadEnabled ? "Touchpad Enabled" : "Touchpad Disabled", btn: "Input 󰅂" },
        { cat: "apps", id: "app-defaults", subId: "", icon: "󰀻", title: "Default apps & file types", val: Status.defTerminal + " · " + Status.defBrowser + " · " + Status.defEditor, btn: "Defaults 󰅂" }
    ]
    readonly property string kbTip: {
        const i = home.kbIndex;
        if (i <= 2) return [ "Network: " + (Status.ssid || Status.netIface || "Not connected"), "Power mode: " + String(Status.workstationMode || "balanced").toUpperCase(), "System Update: Up to date · Btrfs ready" ][i] + " — Press Enter to open";
        if (i === 3 || i === 4) return i === 3 ? "Display & monitor preview — Press Enter to open display settings" : "User Account (" + (Status.userFullName || Status.userAccount) + ") — Press Enter to manage account, avatar & shared Keyring SSO";
        if (i === 5 || i === 6) return (i === 5 ? "Speaker volume (" + Math.round(Status.spkVol * 100) + "%) — Left/Right to adjust, Space to mute" : "Display brightness (" + Math.round(Status.brightness * 100) + "%) — Left/Right to adjust, Space to step") + ", Enter for settings";
        if (i >= 7 && i <= 9) return (i === 7 ? "Microphone (" + (Status.micMuted ? "Muted" : "Live") : (i === 8 ? "Touchpad (" + (Status.touchpadEnabled ? "On" : "Off") : "Camera privacy (" + (Status.webcamEnabled ? "Enabled" : "Locked"))) + ") — Press Enter or Space to toggle";
        if (i >= 10 && i <= 13) { const r = home.recList[i - 10]; return r ? ("Recent setting: " + r.l + " — Press Enter to open") : "Recent setting"; }
        if (i >= 14 && i <= 17) { const p = home.pNavItems[i - 14]; return p ? (p.title + " (" + p.val + ") — Press Enter to configure") : ""; }
        if (i === 18) return "Bluetooth (" + (home.btEnabled ? "On" : "Off") + ") — Space to toggle radio, Enter to manage paired accessories";
        if (i === 19 || i === 20) return i === 19 ? "Scan nearby — Press Enter to power on Bluetooth and scan for accessories (10s)" : "Bluetooth & devices — Press Enter to open paired Bluetooth devices list";
        if (i >= 21 && i <= 24) { const m = home.powerModes[i - 21]; return m ? ("Power mode: " + m.l + " — Press Enter or Space to activate") : ""; }
        if (i === 25 || i === 26) return i === 25 ? "Create restore point — Press Enter to create an atomic Btrfs snapshot checkpoint now" : "Power & battery — Press Enter to open Power, battery & CPU profile settings";
        return "Home dashboard — Use Arrow keys to navigate cards, Enter/Space to select";
    }

    function diskPct(str) {
        const m = String(str || "").match(/([0-9.]+)\s*%/); if (m) return Math.max(0.06, Math.min(1.0, Number(m[1]) / 100.0));
        const p = String(str || "").split("/"); if (p.length === 2) { const u = parseFloat(p[0]), t = parseFloat(p[1]); if (t > 0 && !isNaN(u)) return Math.max(0.08, Math.min(1.0, u / t)); }
        return 0.0;
    }
    function handleKey(event) {
        const k = event.key, i = home.kbIndex;
        if (k === Qt.Key_Up && i === 0) return false;
        if (k === Qt.Key_Down || k === Qt.Key_Up || k === Qt.Key_PageDown || k === Qt.Key_PageUp || k === Qt.Key_Home || k === Qt.Key_End) {
            const d = k === Qt.Key_Down ? 1 : (k === Qt.Key_Up ? -1 : (k === Qt.Key_PageDown ? 4 : (k === Qt.Key_PageUp ? -4 : 0)));
            home.kbIndex = k === Qt.Key_Home ? 0 : (k === Qt.Key_End ? home.kbCount - 1 : Math.max(0, Math.min(home.kbCount - 1, i + d)));
            hFlick.contentY = home.kbIndex >= 14 ? Math.max(0, hFlick.contentHeight - hFlick.height) : 0; Status.playSfx("click"); return true;
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right) {
            const dir = k === Qt.Key_Right ? 1 : -1;
            if (i <= 2) { const n = i + dir; if (n >= 0 && n <= 2) { home.kbIndex = n; Status.playSfx("click"); return true; } return dir > 0; }
            if (i === 5 || i === 6) { if (i === 5) Status.setSpeakerVolume(Math.max(0, Math.min(1, Status.spkVol + dir * 0.05))); else Status.setBrightness(Math.max(0.05, Math.min(1, Status.brightness + dir * 0.05))); return true; }
            if (i >= 14 && i <= 17) { const n = i + dir; if (n >= 14 && n <= 17) { home.kbIndex = n; Status.playSfx("click"); return true; } home.kbIndex = dir > 0 ? 18 : 5; Status.playSfx("click"); return true; }
            for (const r of [[7, 9], [10, 13], [21, 24]]) if (i >= r[0] && i <= r[1]) { const n = i + dir; if (n >= r[0] && n <= r[1]) { home.kbIndex = n; Status.playSfx("click"); return true; } return dir > 0; }
            if (dir > 0 && i >= 3 && i <= 13) { home.kbIndex = 14; Status.playSfx("click"); return true; }
            return dir > 0;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            const isSp = k === Qt.Key_Space;
            if (i <= 2) Status.openSettingsItem(i === 0 ? "network" : (i === 1 ? "system" : "update"), i === 0 ? "net-wifi" : (i === 1 ? "pwr-mode" : "pwr-updates"));
            else if (i === 3 || i === 4) { if (i === 3) Status.openSettingsItem("system", "disp-bright"); else home.selectCategory("accounts"); }
            else if (i === 5 || i === 6) { if (i === 5) { if (isSp) Status.toggleSpeakerMute(); else Status.openSettingsItem("system", "snd-spk"); } else { if (isSp) { Status.setBrightness(Status.brightness > 0.75 ? 0.5 : 1.0); Status.playSfx("toggle"); } else Status.openSettingsItem("system", "disp-bright"); } }
            else if (i === 7) Status.toggleMicMute();
            else if (i === 8 || i === 9) { if (i === 8) home.executeCommand("~/.local/bin/supersettings apply touchpad toggle", false); else Status.toggleWebcam(); }
            else if (i >= 10 && i <= 13) { const r = home.recList[i - 10]; if (r) Status.openSettingsItem(r.cat, r.id); }
            else if (i >= 14 && i <= 17) { const p = home.pNavItems[i - 14]; Status.openSettingsItem(p.cat, p.id, p.subId); }
            else if (i === 18) { if (isSp) home.executeCommand(home.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false); else Status.openSettingsItem("devices", "dev-bt", "bt-devices"); }
            else if (i === 19 || i === 20) { if (i === 19) home.executeCommand("rfkill unblock bluetooth; bluetoothctl power on; bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false); else Status.openSettingsItem("devices", "dev-bt", "bt-devices"); }
            else if (i >= 21 && i <= 24) home.executeCommand("~/.local/bin/supersettings apply mode " + home.powerModes[i - 21].id + " || ~/.local/bin/superfedora mode " + home.powerModes[i - 21].id, false);
            else if (i === 25 || i === 26) { if (i === 25) home.executeCommand("(~/.local/bin/superfedora snapshot create 'Settings Home Checkpoint' || pkexec snapper -c root create -d 'Settings Home Checkpoint') && (~/.local/bin/supernotify --banner checkpoint >/dev/null 2>&1 || true)", false); else Status.openSettingsItem("system", "pwr-mode"); }
            return true;
        }
        return false;
    }

    Flickable {
        id: hFlick; anchors { fill: parent; leftMargin: home.isMedium ? 26 : 16; rightMargin: home.isMedium ? 24 : 14; topMargin: 4; bottomMargin: 14 }
        contentWidth: width; contentHeight: mainCol.implicitHeight + 20; clip: true; boundsBehavior: Flickable.DragOverBounds; flickDeceleration: 3500
        ColumnLayout {
            id: mainCol; width: hFlick.width; spacing: 14
            Rectangle {
                Layout.fillWidth: true; implicitHeight: home.isCompact ? 92 : 112; radius: 8; color: Theme.bgAlt; border.width: (home.paneFocused && home.kbIndex === 4) ? 2 : 1; border.color: (home.paneFocused && home.kbIndex === 4) ? Theme.cyan : Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 10; bottomMargin: 10 } spacing: home.isCompact ? 12 : 16
                    ColumnLayout {
                        visible: home.width >= 380; spacing: 3
                        Rectangle {
                            implicitWidth: home.isCompact ? 76 : (home.isWide ? 132 : 104); implicitHeight: home.isCompact ? 46 : (home.isWide ? 76 : 60); radius: 6; color: Theme.bg; border.width: 2; border.color: (wpMonM.containsMouse || (home.paneFocused && home.kbIndex === 3)) ? Theme.cyan : Theme.blue; clip: true
                            Image { id: wpImg; anchors { fill: parent; margins: 2 } source: home.wpPath; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false }
                            Text { visible: wpImg.status !== Image.Ready; anchors.centerIn: parent; text: "󰍹"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 10 }
                            MouseArea { id: wpMonM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open display & monitor settings", containsMouse); onClicked: { home.kbIndex = 3; Status.openSettingsItem("system", "disp-bright"); } }
                        }
                        Rectangle { Layout.alignment: Qt.AlignHCenter; width: home.isCompact ? 28 : 42; height: 4; radius: 2; color: (wpMonM.containsMouse || (home.paneFocused && home.kbIndex === 3)) ? Theme.cyan : Theme.border }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: Status.userDeviceName || home.hostShort; color: (hDevM.containsMouse || (home.paneFocused && home.kbIndex === 4)) ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { id: hDevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open User Account, avatar & shared Keyring SSO", containsMouse); onClicked: { home.kbIndex = 4; home.selectCategory("accounts"); } } }
                        Text { text: (Status.userFullName || "Fedora Linux") + "  ·  " + Status.gpuArch + "  ·  " + Theme.themeName; color: hGpuM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { id: hGpuM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Inspect GPU architecture, VA-API & DMABUF", containsMouse); onClicked: Status.openSettingsItem("system", "sys-gpu") } }
                        Text { text: "User account, profile & connected SSO 󰅂"; color: (hPrfM.containsMouse || (home.paneFocused && home.kbIndex === 4)) ? Theme.cyan : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { id: hPrfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open dedicated User Account page (profile, connected accounts & system keyring SSO)", containsMouse); onClicked: { home.kbIndex = 4; home.selectCategory("accounts"); } } }
                    }
                    Repeater {
                        model: 3
                        Rectangle {
                            id: hPill; required property int index; visible: index < home.visibleHeroPills; readonly property bool isKb: home.paneFocused && home.kbIndex === hPill.index
                            readonly property string pCat: index === 0 ? "network" : (index === 1 ? "system" : "update"); readonly property string pItem: index === 0 ? "net-wifi" : (index === 1 ? "pwr-mode" : "pwr-updates")
                            readonly property string pIcon: index === 0 ? (Status.wifiEnabled ? "󰤨" : "󰈀") : (index === 1 ? "󰓅" : "󰚰"); readonly property string pTitle: index === 0 ? (Status.ssid || Status.netIface || "Network") : (index === 1 ? "Power mode" : "System Update")
                            readonly property string pSub: index === 0 ? ((Status.netType !== "none" && Status.netIpv4 !== "Disconnected") ? ("Connected · " + Status.netIpv4.split("/")[0]) : "Not connected") : (index === 1 ? (String(Status.workstationMode || "balanced").toUpperCase() + " · CPU " + Status.cpu + "%") : "Up to date · Btrfs ready")
                            implicitWidth: Math.max(168, Theme.fontSize * 11.5); implicitHeight: 62; radius: 6; color: (hpM.containsMouse || isKb) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (hpM.containsMouse ? Theme.blue : Theme.border)
                            RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 10; Text { Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter; text: hPill.pIcon; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4 } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: hPill.pTitle; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: hPill.pSub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } } }
                            MouseArea { id: hpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(hPill.pTitle + " — " + hPill.pSub, containsMouse); onClicked: { home.kbIndex = hPill.index; Status.openSettingsItem(hPill.pCat, hPill.pItem); } }
                        }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true; columns: home.width >= 680 ? 2 : 1; columnSpacing: 12; rowSpacing: 12
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: recCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: recCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout { Layout.fillWidth: true; spacing: 10; Text { Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter; text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Quick controls & recent settings 󰅂"; color: recHdrM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { id: recHdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open System settings category", containsMouse); onClicked: home.selectCategory("system") } } Text { text: "Live sliders, hardware toggles & your last 4 visited settings"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } } }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle { implicitWidth: 30; implicitHeight: 28; radius: 5; color: (vMuteM.containsMouse || (home.paneFocused && home.kbIndex === 5)) ? Theme.bgHover : Theme.bg; border.width: (home.paneFocused && home.kbIndex === 5) ? 2 : 1; border.color: (home.paneFocused && home.kbIndex === 5) ? Theme.cyan : (vMuteM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: Status.spkMuted ? "󰝟" : "󰕾"; color: Status.spkMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: vMuteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(Status.spkMuted ? "Unmute speaker output (Space)" : "Mute speaker output (Space)", containsMouse); onClicked: { home.kbIndex = 5; Status.toggleSpeakerMute(); } } }
                            Text { id: volLbl; text: "Volume 󰅂"; color: (volLblM.containsMouse || (home.paneFocused && home.kbIndex === 5)) ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.preferredWidth: Math.max(92, volLbl.implicitWidth + 6); MouseArea { id: volLblM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Sound & PipeWire output settings (Enter)", containsMouse); onClicked: { home.kbIndex = 5; Status.openSettingsItem("system", "snd-spk"); } } }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Theme.bg; border.width: 1; border.color: (vSlM.containsMouse || (home.paneFocused && home.kbIndex === 5)) ? Theme.cyan : Theme.border
                                Rectangle { width: Math.round(parent.width * Math.max(0, Math.min(1, Status.spkVol))); height: parent.height; radius: 4; color: (vSlM.containsMouse || (home.paneFocused && home.kbIndex === 5)) ? Theme.cyan : Theme.blue }
                                MouseArea { id: vSlM; anchors.fill: parent; anchors.topMargin: -7; anchors.bottomMargin: -7; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Drag or press Left/Right to adjust volume (" + Math.round(Status.spkVol * 100) + "%)", containsMouse); onPressed: m => { home.kbIndex = 5; Status.setSpeakerVolume(m.x / width); } onPositionChanged: m => { if (pressed) Status.setSpeakerVolume(m.x / width); } }
                            }
                            Text { id: volPct; text: Math.round(Status.spkVol * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.preferredWidth: Math.max(40, volPct.implicitWidth + 4); horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle { implicitWidth: 30; implicitHeight: 28; radius: 5; color: (bStepM.containsMouse || (home.paneFocused && home.kbIndex === 6)) ? Theme.bgHover : Theme.bg; border.width: (home.paneFocused && home.kbIndex === 6) ? 2 : 1; border.color: (home.paneFocused && home.kbIndex === 6) ? Theme.cyan : (bStepM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: "󰃠"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: bStepM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Toggle brightness between 50% and 100% (Space)", containsMouse); onClicked: { home.kbIndex = 6; Status.setBrightness(Status.brightness > 0.75 ? 0.5 : 1.0); Status.playSfx("toggle"); } } }
                            Text { id: briLbl; text: "Brightness 󰅂"; color: (briLblM.containsMouse || (home.paneFocused && home.kbIndex === 6)) ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.preferredWidth: Math.max(92, briLbl.implicitWidth + 6); MouseArea { id: briLblM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Display brightness & backlight settings (Enter)", containsMouse); onClicked: { home.kbIndex = 6; Status.openSettingsItem("system", "disp-bright"); } } }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Theme.bg; border.width: 1; border.color: (bSlM.containsMouse || (home.paneFocused && home.kbIndex === 6)) ? Theme.cyan : Theme.border
                                Rectangle { width: Math.round(parent.width * Math.max(0, Math.min(1, Status.brightness))); height: parent.height; radius: 4; color: (bSlM.containsMouse || (home.paneFocused && home.kbIndex === 6)) ? Theme.cyan : Theme.blue }
                                MouseArea { id: bSlM; anchors.fill: parent; anchors.topMargin: -7; anchors.bottomMargin: -7; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Drag or press Left/Right to adjust brightness (" + Math.round(Status.brightness * 100) + "%)", containsMouse); onPressed: m => { home.kbIndex = 6; Status.setBrightness(m.x / width); } onPositionChanged: m => { if (pressed) Status.setBrightness(m.x / width); } }
                            }
                            Text { id: briPct; text: Math.round(Status.brightness * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.preferredWidth: Math.max(40, briPct.implicitWidth + 4); horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: ["mic", "tp", "cam"]
                                Rectangle {
                                    id: qtBtn; required property string modelData; required property int index
                                    readonly property bool isKb: home.paneFocused && home.kbIndex === (7 + index)
                                    readonly property bool isOn: modelData === "mic" ? !Status.micMuted : (modelData === "tp" ? Status.touchpadEnabled : Status.webcamEnabled)
                                    readonly property string lbl: modelData === "mic" ? "Microphone" : (modelData === "tp" ? "Touchpad" : "Camera")
                                    readonly property string icn: modelData === "mic" ? (Status.micMuted ? "󰍭" : "󰍬") : (modelData === "tp" ? "󰟸" : "󰄀")
                                    Layout.fillWidth: true; implicitHeight: 34; radius: 6; color: isOn ? Theme.blue : ((qtM.containsMouse || isKb) ? Theme.bgHover : Theme.bg); border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (isOn ? Theme.blue : (qtM.containsMouse ? Theme.blue : Theme.border))
                                    RowLayout { anchors.centerIn: parent; spacing: 6; Text { Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter; text: qtBtn.icn; color: qtBtn.isOn ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } Text { text: qtBtn.lbl; color: qtBtn.isOn ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: qtBtn.isOn ? Font.DemiBold : Font.Normal; elide: Text.ElideRight } }
                                    MouseArea { id: qtM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Toggle " + qtBtn.lbl + " (" + (qtBtn.isOn ? "On" : "Off") + ")", containsMouse); onClicked: { home.kbIndex = 7 + qtBtn.index; if (qtBtn.modelData === "mic") Status.toggleMicMute(); else if (qtBtn.modelData === "tp") home.executeCommand("~/.local/bin/supersettings apply touchpad toggle", false); else Status.toggleWebcam(); } }
                                }
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true; columns: home.width >= 520 ? 4 : 2; columnSpacing: 6; rowSpacing: 6
                            Repeater {
                                model: home.recList
                                Rectangle { id: navChip; required property var modelData; required property int index; readonly property bool isKb: home.paneFocused && home.kbIndex === (10 + index); Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: (ncM.containsMouse || isKb) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (ncM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; width: parent.width - 10; horizontalAlignment: Text.AlignHCenter; text: navChip.modelData.l + " 󰅂"; color: (ncM.containsMouse || isKb) ? Theme.fg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight } MouseArea { id: ncM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Recent setting: Open " + navChip.modelData.l, containsMouse); onClicked: { home.kbIndex = 10 + navChip.index; Status.openSettingsItem(navChip.modelData.cat, navChip.modelData.id); } } }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: perCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: perCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10; Text { Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter; text: "󰍹"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "System & device essentials 󰅂"; color: perHdrM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { id: perHdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open System settings category", containsMouse); onClicked: home.selectCategory("system") } } Text { text: "Display, audio, input peripherals & default app associations"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                        }
                        Repeater {
                            model: home.pNavItems
                            Rectangle {
                                id: pNavRow; required property var modelData; required property int index
                                readonly property bool isKb: home.paneFocused && home.kbIndex === (14 + index)
                                Layout.fillWidth: true; implicitHeight: 40; radius: 6; color: (pNavM.containsMouse || isKb) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (pNavM.containsMouse ? Theme.blue : Theme.border)
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 10
                                    Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: pNavRow.modelData.icon; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize } }
                                    ColumnLayout { Layout.fillWidth: true; spacing: 0; Text { text: pNavRow.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: pNavRow.modelData.val; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                                    Rectangle { implicitWidth: Math.max(88, pNavBtnT.implicitWidth + 18); implicitHeight: 26; radius: 4; color: (pNavM.containsMouse || pNavRow.isKb) ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: (pNavM.containsMouse || pNavRow.isKb) ? Theme.blue : Theme.border; Text { id: pNavBtnT; anchors.centerIn: parent; text: pNavRow.modelData.btn; color: (pNavM.containsMouse || pNavRow.isKb) ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } }
                                }
                                MouseArea { id: pNavM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open dedicated " + pNavRow.modelData.title + " section (" + pNavRow.modelData.val + ")", containsMouse); onClicked: { home.kbIndex = 14 + pNavRow.index; Status.openSettingsItem(pNavRow.modelData.cat, pNavRow.modelData.id, pNavRow.modelData.subId); } }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: btCardCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: (home.paneFocused && home.kbIndex === 18) ? 2 : 1; border.color: (home.paneFocused && home.kbIndex === 18) ? Theme.cyan : Theme.border
                    ColumnLayout {
                        id: btCardCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10; Text { Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter; text: "󰂯"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Bluetooth devices 󰅂"; color: btHdrM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { id: btHdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open paired Bluetooth devices list", containsMouse); onClicked: { home.kbIndex = 18; Status.openSettingsItem("devices", "dev-bt", "bt-devices"); } } } Text { text: home.btEnabled ? ("Bluetooth is on  ·  " + home.btList.length + " recent devices") : "Bluetooth is turned off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                            RowLayout { spacing: 8; Text { text: home.btEnabled ? "On" : "Off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } Rectangle { implicitWidth: 42; implicitHeight: 22; radius: 11; color: home.btEnabled ? Theme.blue : (btTglM.containsMouse ? Theme.bgHover : Theme.bg); border.width: 1; border.color: home.btEnabled ? Theme.blue : (btTglM.containsMouse ? Theme.blue : Theme.muted); Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: home.btEnabled ? 23 : 4; color: home.btEnabled ? Theme.bg : Theme.fgDim; Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } } } MouseArea { id: btTglM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(home.btEnabled ? "Turn off Bluetooth radio (Space)" : "Turn on Bluetooth radio (Space)", containsMouse); onClicked: { home.kbIndex = 18; home.executeCommand(home.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false); } } } }
                        }
                        Rectangle { visible: home.btList.length === 0; Layout.fillWidth: true; implicitHeight: 54; radius: 6; color: btEmpM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: btEmpM.containsMouse ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; width: parent.width - 20; horizontalAlignment: Text.AlignHCenter; text: home.btEnabled ? "No paired Bluetooth accessories found. Click to manage devices." : "Bluetooth is turned off. Turn on Bluetooth or click to manage devices."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight } MouseArea { id: btEmpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Bluetooth accessory manager", containsMouse); onClicked: Status.openSettingsItem("devices", "dev-bt", "bt-devices") } }
                        Repeater {
                            model: home.btList
                            Rectangle {
                                id: btRow; required property var modelData; readonly property string safeAddr: String(modelData.address || "").replace(/[^0-9A-Fa-f:]/g, "")
                                Layout.fillWidth: true; implicitHeight: 36; radius: 5; color: Theme.bg; border.width: 1; border.color: modelData.connected ? Theme.blue : Theme.border
                                RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 8; Text { text: "󰂯  " + (btRow.modelData.name || "Accessory") + (btRow.modelData.connected ? "  ·  Connected" : ""); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: Math.max(88, btBtnTxt.implicitWidth + 20); implicitHeight: 24; radius: 4; color: btRow.modelData.connected ? (btConM.containsMouse ? Theme.bgHover : Theme.bgAlt) : Theme.blue; border.width: 1; border.color: btConM.containsMouse ? Theme.cyan : Theme.border; Text { id: btBtnTxt; anchors.centerIn: parent; text: btRow.modelData.connected ? "Disconnect" : "Connect"; color: btRow.modelData.connected ? Theme.fg : Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: btConM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip((btRow.modelData.connected ? "Disconnect " : "Connect ") + (btRow.modelData.name || btRow.safeAddr), containsMouse); onClicked: if (btRow.safeAddr) home.executeCommand(btRow.modelData.connected ? ("bluetoothctl disconnect " + btRow.safeAddr) : ("bluetoothctl connect " + btRow.safeAddr), false) } } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { readonly property bool isKb: home.paneFocused && home.kbIndex === 19; Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: (isKb || btScM.containsMouse) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (btScM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: "Scan nearby"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: btScM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Power on Bluetooth and scan for nearby accessories (10s)", containsMouse); onClicked: { home.kbIndex = 19; home.executeCommand("rfkill unblock bluetooth; bluetoothctl power on; bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false); } } }
                            Rectangle { readonly property bool isKb: home.paneFocused && home.kbIndex === 20; Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: (isKb || btAllM.containsMouse) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (btAllM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: "Bluetooth & devices 󰅂"; color: btAllM.containsMouse ? Theme.fg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: btAllM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open paired Bluetooth devices list", containsMouse); onClicked: { home.kbIndex = 20; Status.openSettingsItem("devices", "dev-bt", "bt-devices"); } } }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: stgCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: stgCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout { Layout.fillWidth: true; spacing: 10; Text { Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter; text: "󰋊"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Storage, power & recovery 󰅂"; color: stgHdrM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { id: stgHdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Storage & Btrfs filesystem details", containsMouse); onClicked: Status.openSettingsItem("system", "sys-storage") } } Text { text: "Root (/): " + Status.diskRoot + "  ·  Home: " + Status.diskHome + "  ·  RAM " + Status.mem + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } } }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Rectangle { Layout.fillWidth: true; height: 8; radius: 4; color: Theme.bg; border.width: 1; border.color: dskBarM.containsMouse ? Theme.blue : Theme.border; Rectangle { width: Math.round(parent.width * home.diskPct(Status.diskRoot)); height: parent.height; radius: 4; color: Theme.blue } MouseArea { id: dskBarM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Root (/): " + Status.diskRoot + " · Click to inspect disks", containsMouse); onClicked: Status.openSettingsItem("system", "sys-storage") } }
                            RowLayout { Layout.fillWidth: true; Text { text: "Btrfs Root & Home"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true } Text { text: "CPU " + Status.cpu + "%  ·  Temp " + Status.tempC + "°C"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: home.powerModes
                                Rectangle { id: mdBtn; required property var modelData; required property int index; readonly property bool isCur: Status.workstationMode === modelData.id; readonly property bool isKb: home.paneFocused && home.kbIndex === (21 + index); Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: isCur ? Theme.blue : ((mdM.containsMouse || isKb) ? Theme.bgHover : Theme.bg); border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (isCur ? Theme.blue : (mdM.containsMouse ? Theme.blue : Theme.border)); Text { anchors.centerIn: parent; text: mdBtn.modelData.l; color: mdBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: mdBtn.isCur ? Font.DemiBold : Font.Normal } MouseArea { id: mdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Switch workstation power mode to " + mdBtn.modelData.l, containsMouse); onClicked: { home.kbIndex = 21 + mdBtn.index; home.executeCommand("~/.local/bin/supersettings apply mode " + mdBtn.modelData.id + " || ~/.local/bin/superfedora mode " + mdBtn.modelData.id, false); } } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { readonly property bool isKb: home.paneFocused && home.kbIndex === 25; Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: (isKb || snapM.containsMouse) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (snapM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: "󰁯 Create restore point"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: snapM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Create an atomic Btrfs snapshot checkpoint now", containsMouse); onClicked: { home.kbIndex = 25; home.executeCommand("(~/.local/bin/superfedora snapshot create 'Settings Home Checkpoint' || pkexec snapper -c root create -d 'Settings Home Checkpoint') && (~/.local/bin/supernotify --banner checkpoint >/dev/null 2>&1 || true)", false); } } }
                            Rectangle { readonly property bool isKb: home.paneFocused && home.kbIndex === 26; Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: (isKb || pwrM.containsMouse) ? Theme.bgHover : Theme.bg; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (pwrM.containsMouse ? Theme.blue : Theme.border); Text { anchors.centerIn: parent; text: "Power & battery 󰅂"; color: pwrM.containsMouse ? Theme.fg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: pwrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Power, battery & CPU profile settings", containsMouse); onClicked: { home.kbIndex = 26; Status.openSettingsItem("system", "pwr-mode"); } } }
                        }
                    }
                }
            }
        }
    }
}
