import QtQuick
import QtQuick.Layouts
import Quickshell

// Windows 11 (WinUI 3) Expanded Setting Card Drawers: Wallpaper Gallery, Theme Palettes, Top Bar Organizer, SuperForge & Storage Specs.
ColumnLayout {
    id: drawer
    property string activeSection: "wallpaper"
    property string selBarIcon: "wifi"
    signal executeCommand(string cmd, bool closeAfter)
    signal closeRequested()
    Layout.fillWidth: true; spacing: 10

    readonly property var themePresets: [
        { id: "01-crimson", label: "Crimson", hex: "#f7768e" }, { id: "02-scarlet", label: "Scarlet", hex: "#ff5a5f" },
        { id: "03-ember",   label: "Ember",   hex: "#ff7b54" }, { id: "04-amber",   label: "Amber",   hex: "#ff9e64" },
        { id: "05-topaz",   label: "Topaz",   hex: "#e0af68" }, { id: "06-citrine", label: "Citrine", hex: "#f9e2af" },
        { id: "07-peridot", label: "Peridot", hex: "#a6e3a1" }, { id: "08-emerald", label: "Emerald", hex: "#9ece6a" },
        { id: "09-verdant", label: "Verdant", hex: "#73daca" }, { id: "10-lagoon",  label: "Lagoon",  hex: "#2ac3de" },
        { id: "11-glacier", label: "Glacier", hex: "#7dcfff" }, { id: "12-cobalt",  label: "Cobalt",  hex: "#7aa2f7" },
        { id: "13-indigo",  label: "Indigo",  hex: "#6c71c4" }, { id: "14-violet",  label: "Violet",  hex: "#bb9af7" },
        { id: "15-orchid",  label: "Orchid",  hex: "#cba6f7" }, { id: "16-fuchsia", label: "Fuchsia", hex: "#f43f5e" }
    ]
    readonly property var barIconLabels: ({ wifi: "󰤨 Wi-Fi", bluetooth: "󰂯 Bluetooth", speaker: "󰕾 Speaker", mic: "󰍬 Mic", camera: "󰄀 Camera", battery: "󰁹 Battery", power: "󰐥 Power" })

    function runForge(target) { const q = String(target || forgeInput.text || "").trim().replace(/['"]/g, ""); if (!q) return; forgeInput.text = ""; Status.runForge(q); }

    // ================ 1. WALLPAPER GALLERY DRAWER (Personalization > Background & wallpaper) ================
    ColumnLayout {
        visible: drawer.activeSection === "wallpaper"; Layout.fillWidth: true; spacing: 10
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Rectangle {
                implicitWidth: 164; implicitHeight: 94; radius: 6; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue; clip: true
                Image { anchors { fill: parent; margins: 2 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "Current desktop background"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold }
                Text { text: Status.currentWallpaper || "~/Pictures/Wallpapers"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideMiddle; Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: wpCustomIn.activeFocus ? Theme.blue : Theme.border
                        TextInput {
                            id: wpCustomIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true
                            Keys.onReturnPressed: if (wpCustomIn.text.trim()) { Status.setWallpaper(wpCustomIn.text.trim()); wpCustomIn.text = ""; }
                            Text { visible: wpCustomIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Paste custom image path (e.g. ~/Pictures/Wallpapers/my-wall.png)..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                        }
                    }
                    Rectangle {
                        implicitWidth: 96; implicitHeight: 32; radius: 5; color: Theme.blue
                        Text { anchors.centerIn: parent; text: "Apply path"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (wpCustomIn.text.trim()) { Status.setWallpaper(wpCustomIn.text.trim()); wpCustomIn.text = ""; } }
                    }
                }
            }
        }
        Text { text: "Choose a photo (" + Status.wallpaperList.length + " wallpapers in ~/Pictures/Wallpapers)"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true; columns: 4; columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: Status.wallpaperList
                Rectangle {
                    id: wpCard; required property string modelData
                    readonly property bool isCur: Status.currentWallpaper === modelData
                    Layout.fillWidth: true; implicitHeight: 92; radius: 6; color: Theme.bgAlt
                    border.width: isCur ? 2 : 1; border.color: isCur ? Theme.blue : (wpCardM.containsMouse ? Theme.cyan : Theme.border); clip: true
                    Image { anchors { fill: parent; margins: 2 } source: "file://" + wpCard.modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 240; sourceSize.height: 135 }
                    MouseArea { id: wpCardM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setWallpaper(wpCard.modelData) }
                }
            }
        }
    }

    // ================ 2. THEME & OPENRGB DRAWER (Personalization > Colors & window geometry) ================
    ColumnLayout {
        visible: drawer.activeSection === "theme"; Layout.fillWidth: true; spacing: 10
        Text { text: "Accent color & system palette (" + Theme.themeName + ")"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true; columns: 8; columnSpacing: 6; rowSpacing: 6
            Repeater {
                model: drawer.themePresets
                Rectangle {
                    id: tpBtn; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id
                    Layout.fillWidth: true; implicitHeight: 34; radius: 5; color: tpM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bgAlt); border.width: isCur ? 2 : 1; border.color: isCur ? Theme.fg : Theme.border
                    RowLayout { anchors.centerIn: parent; spacing: 6; Rectangle { width: 10; height: 10; radius: 5; color: tpBtn.modelData.hex } Text { text: tpBtn.modelData.label; color: tpBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: tpBtn.isCur ? Font.DemiBold : Font.Normal } }
                    MouseArea { id: tpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: drawer.executeCommand("~/.local/bin/supertheme " + tpBtn.modelData.id + " || ~/.local/bin/sf theme " + tpBtn.modelData.id, false) }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "OpenRGB hardware lighting:"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
            Text { text: Status.rgbSupported ? (Status.rgbCount + " controller(s) active") : "No OpenRGB controllers detected"; color: Status.rgbSupported ? Theme.green : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true }
            Repeater {
                model: Status.rgbSupported ? drawer.themePresets.slice(0, 8) : []
                Rectangle {
                    required property var modelData; width: 22; height: 22; radius: 4; color: modelData.hex; border.width: 1; border.color: Theme.border
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setRgbColor(parent.modelData.hex) }
                }
            }
            Rectangle { visible: Status.rgbSupported; implicitWidth: 54; implicitHeight: 24; radius: 4; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "RGB Off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setRgbColor("off") } }
        }
    }

    // ================ 3. TOP BAR ICON ORGANIZER DRAWER (Multitasking & docks > Taskbar & app dock) ================
    ColumnLayout {
        visible: drawer.activeSection === "shell"; Layout.fillWidth: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Top bar status icons (left-click to select, right-click to hide/show)"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; Layout.fillWidth: true }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: Status.barIcons.filter(x => x !== "|")
                Rectangle {
                    id: biChip; required property string modelData
                    readonly property bool isSel: drawer.selBarIcon === modelData; readonly property bool isHid: Status.barHiddenIcons.indexOf(modelData) >= 0
                    Layout.fillWidth: true; implicitHeight: 34; radius: 5; color: isSel ? Theme.blue : (biM.containsMouse ? Theme.bgHover : Theme.bgAlt)
                    border.width: 1; border.color: isSel ? Theme.blue : Theme.border; opacity: isHid ? 0.5 : 1.0
                    Text { anchors.centerIn: parent; text: (biChip.isHid ? "󰈉 " : "") + (drawer.barIconLabels[biChip.modelData] || biChip.modelData); color: biChip.isSel ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: biChip.isSel ? Font.DemiBold : Font.Normal }
                    MouseArea { id: biM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: e => { drawer.selBarIcon = biChip.modelData; if (e.button === Qt.RightButton) Status.toggleBarIconHidden(biChip.modelData); else Status.playSfx("click"); } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: [ { act: "left", l: "◀ Move left" }, { act: "right", l: "Move right ▶" }, { act: "hide", l: Status.barHiddenIcons.indexOf(drawer.selBarIcon) >= 0 ? "Show icon" : "Hide icon" }, { act: "div", l: Status.barIcons.indexOf("|") >= 0 ? "Dividers: On" : "Dividers: Off" }, { act: "reset", l: "Reset default order" } ]
                Rectangle {
                    id: biAct; required property var modelData; Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: biActM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                    Text { anchors.centerIn: parent; text: biAct.modelData.l; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                    MouseArea { id: biActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = biAct.modelData.act; if (a === "left") Status.moveBarIcon(drawer.selBarIcon, -1); else if (a === "right") Status.moveBarIcon(drawer.selBarIcon, 1); else if (a === "hide") Status.toggleBarIconHidden(drawer.selBarIcon); else if (a === "div") Status.toggleBarDividers(); else Status.resetBarIcons(); } }
                }
            }
        }
    }

    // ================ 4. SUPERFORGE & STARTUP APPS DRAWER (Apps & Forge > Default apps & SuperForge) ================
    ColumnLayout {
        visible: drawer.activeSection === "forge"; Layout.fillWidth: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "SuperForge native compiler & chromeless Firefox WebApp builder"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 196; implicitHeight: 26; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                Text { anchors.centerIn: parent; text: Status.forgeIsolated ? "Profile: Isolated sandbox" : "Profile: Shared Firefox"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Status.forgeIsolated = !Status.forgeIsolated; Status.playSfx("toggle"); } }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 34; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: forgeInput.activeFocus ? Theme.blue : Theme.border
                TextInput {
                    id: forgeInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                    Keys.onReturnPressed: drawer.runForge(forgeInput.text)
                    Text { visible: forgeInput.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Enter URL (https://claude.ai) or recipe/repo (yazi, btop, owner/repo)..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                }
            }
            Rectangle {
                implicitWidth: 124; implicitHeight: 34; radius: 5; color: Status.forgeBusy ? Theme.red : Theme.blue
                Text { anchors.centerIn: parent; text: Status.forgeBusy ? ("Stop (" + Status.forgePct + "%)") : "Forge & install"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.forgeBusy) Status.stopForge(); else drawer.runForge(forgeInput.text); } }
            }
            Rectangle {
                implicitWidth: 104; implicitHeight: 34; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "Update all"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: drawer.runForge("update") }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: ["https://claude.ai", "https://chatgpt.com", "https://github.com", "yazi", "btop", "fastfetch"]
                Rectangle {
                    id: qfBtn; required property string modelData; Layout.fillWidth: true; implicitHeight: 26; radius: 4; color: qfM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "+ " + qfBtn.modelData.replace(/^https:\/\//, ""); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                    MouseArea { id: qfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: drawer.runForge(qfBtn.modelData) }
                }
            }
        }
        Repeater {
            model: Status.forgedWebApps
            Rectangle {
                id: fwCard; required property var modelData; Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 } spacing: 8
                    Text { text: "󰖟  " + fwCard.modelData.name + "  ·  " + (fwCard.modelData.url || fwCard.modelData.mode); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 64; implicitHeight: 24; radius: 4; color: Theme.blue; Text { anchors.centerIn: parent; text: "Launch"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: drawer.executeCommand("'" + fwCard.modelData.bin + "'", true) } }
                    Rectangle { implicitWidth: 64; implicitHeight: 24; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Remove"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeForge(fwCard.modelData.slug) } }
                }
            }
        }
        Text { text: "Startup applications (~/.config/hypr/conf/autostart.conf)"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; Layout.topMargin: 4 }
        Repeater {
            model: Status.startupApps
            Rectangle {
                id: stRow; required property string modelData; Layout.fillWidth: true; implicitHeight: 30; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 } spacing: 8
                    Text { text: "󰀻  " + stRow.modelData; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 64; implicitHeight: 22; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Remove"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeStartupApp(stRow.modelData) } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: startupIn.activeFocus ? Theme.blue : Theme.border
                TextInput {
                    id: startupIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true
                    Keys.onReturnPressed: if (startupIn.text.trim()) { Status.addStartupApp(startupIn.text.trim()); startupIn.text = ""; }
                    Text { visible: startupIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Add startup command (e.g. discord, synology-drive)..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                }
            }
            Rectangle { implicitWidth: 112; implicitHeight: 32; radius: 5; color: Theme.blue; Text { anchors.centerIn: parent; text: "Add startup app"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (startupIn.text.trim()) { Status.addStartupApp(startupIn.text.trim()); startupIn.text = ""; } } }
        }
    }

    // ================ 5. STORAGE, HARDWARE SPECS & TOP PROCESSES DRAWER (System > Storage) ================
    ColumnLayout {
        visible: drawer.activeSection === "storage"; Layout.fillWidth: true; spacing: 8
        Text { text: "Hardware specifications & active processes"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 4
            Repeater {
                model: Status.fastfetchList
                Rectangle {
                    required property var modelData; Layout.fillWidth: true; implicitHeight: 28; radius: 4; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 6; Text { text: parent.parent.modelData.k + ":"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } Text { text: parent.parent.modelData.v; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                }
            }
        }
        Repeater {
            model: Status.topProcs.slice(0, 5)
            Rectangle {
                id: prRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 26; radius: 4; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 10; Text { text: "PID " + prRow.modelData.pid + "  ·  " + prRow.modelData.cmd; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: "CPU " + prRow.modelData.cpu + "%  ·  MEM " + prRow.modelData.mem + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
            }
        }
    }
}
