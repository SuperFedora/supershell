import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

// Windows 11 (WinUI 3 / Fluent) Settings Home Dashboard: Live Wallpaper Monitor Banner + 2x2 Interactive Cards Grid.
Item {
    id: home
    property string hostShort: "workstation"
    signal selectCategory(string catId)
    signal executeCommand(string cmd, bool closeAfter)

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btList: btAdapter ? Bluetooth.devices.values.slice(0, 3) : []
    readonly property string wpPath: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""

    readonly property var themeSwatches: [
        { id: "01-crimson", l: "Crimson", hex: "#f7768e" }, { id: "02-scarlet", l: "Scarlet", hex: "#ff5a5f" },
        { id: "03-ember",   l: "Ember",   hex: "#ff7b54" }, { id: "04-amber",   l: "Amber",   hex: "#ff9e64" },
        { id: "05-topaz",   l: "Topaz",   hex: "#e0af68" }, { id: "06-citrine", l: "Citrine", hex: "#f9e2af" },
        { id: "07-peridot", l: "Peridot", hex: "#a6e3a1" }, { id: "08-emerald", l: "Emerald", hex: "#9ece6a" },
        { id: "09-verdant", l: "Verdant", hex: "#73daca" }, { id: "10-lagoon",  l: "Lagoon",  hex: "#2ac3de" },
        { id: "11-glacier", l: "Glacier", hex: "#7dcfff" }, { id: "12-cobalt",  l: "Cobalt",  hex: "#7aa2f7" },
        { id: "13-indigo",  l: "Indigo",  hex: "#6c71c4" }, { id: "14-violet",  l: "Violet",  hex: "#bb9af7" },
        { id: "15-orchid",  l: "Orchid",  hex: "#cba6f7" }, { id: "16-fuchsia", l: "Fuchsia", hex: "#f43f5e" }
    ]
    readonly property var powerModes: [
        { id: "stealth", l: "Stealth" }, { id: "balanced", l: "Balanced" }, { id: "forge", l: "Forge" }, { id: "arcade", l: "Arcade" }
    ]

    function diskPct(str) {
        const m = String(str || "").match(/([0-9.]+)\s*%/); if (m) return Math.max(0.06, Math.min(1.0, Number(m[1]) / 100.0));
        const p = String(str || "").split("/"); if (p.length === 2) { const u = parseFloat(p[0]), t = parseFloat(p[1]); if (t > 0 && !isNaN(u)) return Math.max(0.08, Math.min(1.0, u / t)); }
        return 0.32;
    }

    Flickable {
        id: hFlick; anchors { fill: parent; leftMargin: 28; rightMargin: 24; topMargin: 4; bottomMargin: 14 }
        contentWidth: width; contentHeight: mainCol.implicitHeight + 20; clip: true; boundsBehavior: Flickable.DragOverBounds; flickDeceleration: 3500

        ColumnLayout {
            id: mainCol; width: hFlick.width; spacing: 14

            // ================ TOP HERO DEVICE BANNER (Windows 11 Home Header with Live Wallpaper Monitor) ================
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 112; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18; topMargin: 12; bottomMargin: 12 } spacing: 18
                    ColumnLayout {
                        spacing: 3
                        Rectangle {
                            implicitWidth: 132; implicitHeight: 76; radius: 6; color: Theme.bg; border.width: 2; border.color: wpMonM.containsMouse ? Theme.cyan : Theme.blue; clip: true
                            Image { id: wpImg; anchors { fill: parent; margins: 2 } source: home.wpPath; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false }
                            Text { visible: wpImg.status !== Image.Ready; anchors.centerIn: parent; text: "󰍹"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 10 }
                            MouseArea { id: wpMonM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") }
                        }
                        Rectangle { Layout.alignment: Qt.AlignHCenter; width: 42; height: 4; radius: 2; color: wpMonM.containsMouse ? Theme.blue : Theme.border }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: home.hostShort; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "sys-storage") } }
                        Text { text: "Fedora Linux  ·  " + Status.gpuArch + "  ·  " + Theme.themeName; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "sys-gpu") } }
                        Text { text: "System specifications & display 󰅂"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "disp-scale") } }
                    }
                    Repeater {
                        model: [
                            { cat: "network", item: "net-wifi",     icon: Status.wifiEnabled ? "󰤨" : "󰈀", title: Status.ssid || Status.netIface || "Network", sub: "Connected · " + Status.netIpv4.split("/")[0] },
                            { cat: "power",   item: "pwr-mode",     icon: "󰓅", title: "Power mode", sub: Status.workstationMode.toUpperCase() + " · CPU " + Status.cpu + "%" },
                            { cat: "ai",      item: "ai-cluster",   icon: "󰚩", title: Status.aiAgentLabel || "AI Cluster", sub: Status.ollamaModel + " · " + Status.llmServers.length + " nodes" }
                        ]
                        Rectangle {
                            id: hPill; required property var modelData; implicitWidth: 168; implicitHeight: 62; radius: 6; color: hpM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: hpM.containsMouse ? Theme.blue : Theme.border
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 10
                                Text { text: hPill.modelData.icon; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4 }
                                ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: hPill.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: hPill.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                            }
                            MouseArea { id: hpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem(hPill.modelData.cat, hPill.modelData.item) }
                        }
                    }
                }
            }

            // ================ 2x2 WINDOWS 11 HOME DASHBOARD CARDS GRID ================
            GridLayout {
                Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 12

                // -------- CARD 1: RECOMMENDED & QUICK CONTROLS --------
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: recCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: recCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout { Layout.fillWidth: true; spacing: 10; Text { text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Recommended settings 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "disp-bright") } } Text { text: "Click any setting label to expand its full controls"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } } }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle { implicitWidth: 30; implicitHeight: 28; radius: 5; color: vMuteM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: Status.spkMuted ? "󰝟" : "󰕾"; color: Status.spkMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: vMuteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleSpeakerMute() } }
                            Text { text: "Volume 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.preferredWidth: 82; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "snd-spk") } }
                            Item {
                                Layout.fillWidth: true; implicitHeight: 22
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.bg; border.width: 1; border.color: Theme.border }
                                Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * Math.max(0, Math.min(1, Status.spkVol))); height: 4; radius: 2; color: Theme.blue }
                                Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * Status.spkVol) - 7)); color: Theme.blue; border.width: 2; border.color: Theme.bgAlt }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: m => Status.setSpeakerVolume(m.x / width); onPositionChanged: m => { if (pressed) Status.setSpeakerVolume(m.x / width); } }
                            }
                            Text { text: Math.round(Status.spkVol * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle { implicitWidth: 30; implicitHeight: 28; radius: 5; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰃠"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "disp-bright") } }
                            Text { text: "Brightness 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.preferredWidth: 82; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "disp-bright") } }
                            Item {
                                Layout.fillWidth: true; implicitHeight: 22
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.bg; border.width: 1; border.color: Theme.border }
                                Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * Math.max(0, Math.min(1, Status.brightness))); height: 4; radius: 2; color: Theme.blue }
                                Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * Status.brightness) - 7)); color: Theme.blue; border.width: 2; border.color: Theme.bgAlt }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: m => Status.setBrightness(m.x / width); onPositionChanged: m => { if (pressed) Status.setBrightness(m.x / width); } }
                            }
                            Text { text: Math.round(Status.brightness * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: [ { l: "Night light", icon: "󰖔", on: Status.nightLightRunning, kind: "nl" }, { l: "Do not disturb", icon: "󰂚", on: Status.dnd, kind: "dnd" }, { l: "UI sounds", icon: "󰓃", on: Status.sfxEnabled, kind: "sfx" } ]
                                Rectangle {
                                    id: qtBtn; required property var modelData; Layout.fillWidth: true; implicitHeight: 34; radius: 6; color: modelData.on ? Theme.blue : (qtM.containsMouse ? Theme.bgHover : Theme.bg); border.width: 1; border.color: modelData.on ? Theme.blue : Theme.border
                                    RowLayout { anchors.centerIn: parent; spacing: 6; Text { text: qtBtn.modelData.icon; color: qtBtn.modelData.on ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 } Text { text: qtBtn.modelData.l; color: qtBtn.modelData.on ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: qtBtn.modelData.on ? Font.DemiBold : Font.Normal } }
                                    MouseArea { id: qtM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (qtBtn.modelData.kind === "nl") home.executeCommand(Status.nightLightRunning ? "~/.local/bin/supersettings apply nightlight off" : "~/.local/bin/supersettings apply nightlight 4000", false); else if (qtBtn.modelData.kind === "dnd") { if (Status.notifAction) Status.notifAction("toggleDnd", ""); } else Status.toggleSfx(); } }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: [ { l: "Audio devices", cat: "system", item: "snd-spk" }, { l: "Taskbar & dock", cat: "windowing", item: "wm-dock" }, { l: "Accessibility", cat: "accessibility", item: "acc-fontsize" } ]
                                Rectangle { id: navChip; required property var modelData; Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: ncM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: navChip.modelData.l + " 󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: ncM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem(navChip.modelData.cat, navChip.modelData.item) } }
                            }
                        }
                    }
                }

                // -------- CARD 2: PERSONALIZE YOUR DEVICE --------
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: perCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: perCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Text { text: "󰸉"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Personalize your device 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } } Text { text: "Theme: " + Theme.themeName + "  ·  " + (Theme.mode === "light" ? "Light mode" : "Dark mode") + "  ·  " + (Theme.corners === "rounded" ? "Rounded" : "Square"); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                            Rectangle { implicitWidth: 118; implicitHeight: 28; radius: 5; color: nwM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰸉 Wallpaper picker"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: nwM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } }
                        }
                        GridLayout {
                            Layout.fillWidth: true; columns: 8; columnSpacing: 6; rowSpacing: 6
                            Repeater {
                                model: home.themeSwatches
                                Rectangle { id: swBox; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id; Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: modelData.hex; border.width: isCur ? 2 : 1; border.color: isCur ? Theme.fg : Theme.border; Text { visible: swBox.isCur; anchors.centerIn: parent; text: "󰄬"; color: "#1a1b26"; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand("~/.local/bin/supertheme " + swBox.modelData.id + " || ~/.local/bin/sf theme " + swBox.modelData.id, false) } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: [ { l: "Dark", on: Theme.mode === "dark", cmd: "~/.local/bin/supertheme night || ~/.local/bin/sf theme night" }, { l: "Light", on: Theme.mode === "light", cmd: "~/.local/bin/supertheme day || ~/.local/bin/sf theme day" }, { l: "Rounded", on: Theme.corners === "rounded", cmd: "~/.local/bin/supertheme corners rounded || ~/.local/bin/sf theme corners rounded" }, { l: "Square", on: Theme.corners === "square", cmd: "~/.local/bin/supertheme corners square || ~/.local/bin/sf theme corners square" } ]
                                Rectangle { id: pmBtn; required property var modelData; Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: modelData.on ? Theme.blue : (pmM.containsMouse ? Theme.bgHover : Theme.bg); border.width: 1; border.color: modelData.on ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: pmBtn.modelData.l; color: pmBtn.modelData.on ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: pmBtn.modelData.on ? Font.DemiBold : Font.Normal } MouseArea { id: pmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand(pmBtn.modelData.cmd, false) } }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: pMoreM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Browse wallpapers, themes, RGB lighting & screensavers 󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: pMoreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } }
                    }
                }

                // -------- CARD 3: BLUETOOTH DEVICES --------
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: btCardCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: btCardCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Text { text: "󰂯"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Bluetooth devices 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("devices", "dev-bt") } } Text { text: home.btEnabled ? ("Bluetooth is on  ·  " + home.btList.length + " recent devices") : "Bluetooth is turned off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                            RowLayout { spacing: 8; Text { text: home.btEnabled ? "On" : "Off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } Rectangle { implicitWidth: 42; implicitHeight: 22; radius: 11; color: home.btEnabled ? Theme.blue : Theme.bg; border.width: 1; border.color: home.btEnabled ? Theme.blue : Theme.muted; Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: home.btEnabled ? 23 : 4; color: home.btEnabled ? Theme.bg : Theme.fgDim } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand(home.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) } } }
                        }
                        Rectangle { visible: home.btList.length === 0; Layout.fillWidth: true; implicitHeight: 54; radius: 6; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "No paired Bluetooth accessories found. Click to manage devices."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("devices", "dev-bt") } }
                        Repeater {
                            model: home.btList
                            Rectangle {
                                id: btRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 36; radius: 5; color: Theme.bg; border.width: 1; border.color: modelData.connected ? Theme.blue : Theme.border
                                RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 8; Text { text: "󰂯  " + (btRow.modelData.name || "Accessory") + (btRow.modelData.connected ? "  ·  Connected" : ""); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: 84; implicitHeight: 24; radius: 4; color: btRow.modelData.connected ? Theme.bgAlt : Theme.blue; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: btRow.modelData.connected ? "Disconnect" : "Connect"; color: btRow.modelData.connected ? Theme.fg : Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand(btRow.modelData.connected ? ("bluetoothctl disconnect " + btRow.modelData.address) : ("bluetoothctl connect " + btRow.modelData.address), false) } } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: btScM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Scan nearby"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: btScM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand("bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false) } }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: btAllM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Bluetooth & devices 󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: btAllM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("devices", "dev-bt") } }
                        }
                    }
                }

                // -------- CARD 4: STORAGE, POWER MODE & RECOVERY --------
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 100; Layout.fillHeight: true; implicitHeight: stgCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: stgCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                        RowLayout { Layout.fillWidth: true; spacing: 10; Text { text: "󰋊"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: "Storage, power & recovery 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "sys-storage") } } Text { text: "Root (/): " + Status.diskRoot + "  ·  Home: " + Status.diskHome + "  ·  RAM " + Status.mem + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } } }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Rectangle { Layout.fillWidth: true; height: 8; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.border; Rectangle { width: Math.round(parent.width * home.diskPct(Status.diskRoot)); height: parent.height; radius: 4; color: Theme.blue } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "sys-storage") } }
                            RowLayout { Layout.fillWidth: true; Text { text: "Btrfs Root & Home"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true } Text { text: "CPU " + Status.cpu + "%  ·  Temp " + Status.tempC + "°C"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: home.powerModes
                                Rectangle { id: mdBtn; required property var modelData; readonly property bool isCur: Status.workstationMode === modelData.id; Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: isCur ? Theme.blue : (mdM.containsMouse ? Theme.bgHover : Theme.bg); border.width: 1; border.color: isCur ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: mdBtn.modelData.l; color: mdBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: mdBtn.isCur ? Font.DemiBold : Font.Normal } MouseArea { id: mdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand("~/.local/bin/supersettings apply mode " + mdBtn.modelData.id + " || ~/.local/bin/sf mode " + mdBtn.modelData.id, false) } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: snapM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰁯 Create restore point"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: snapM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: home.executeCommand("(~/.local/bin/sf snapshot create 'Settings Home Checkpoint' || pkexec snapper -c root create -d 'Settings Home Checkpoint') && (~/.local/bin/supernotify --banner checkpoint >/dev/null 2>&1 || true)", false) } }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: pwrM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Power & battery 󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { id: pwrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("power", "pwr-mode") } }
                        }
                    }
                }
            }
        }
    }
}
