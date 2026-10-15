import QtQuick
import QtQuick.Layouts
import Quickshell

// SuperDesk 16-Bit Quick-Action Modules: [6] THEME, [7] DOCK, [8] FORGE, [9] STATE, and [0] POWER.
ColumnLayout {
    id: deckBody
    property string activeSection: "theme"
    property bool batPresent: false; property int batPct: 100; property bool batCharging: false
    property string forgeStatus: "READY  ·  Compiles with -O3 -march=native -flto=auto into ~/.local/bin"; property string selBarIcon: "wifi"
    signal executeCommand(string cmd, bool closeAfter); signal requestConfirm(string label, string cmd)
    signal switchTabRequested(int tabIndex); signal cycleTabRequested(bool backward); signal closeRequested()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
    function focusSearch() { if (deckBody.activeSection === "forge") forgeInput.forceActiveFocus(); }

    readonly property var themePresets: [
        { id: "01-crimson", label: "CRIMSON", hex: "#f7768e" }, { id: "02-scarlet", label: "SCARLET", hex: "#ff5a5f" },
        { id: "03-ember",   label: "EMBER",   hex: "#ff7b54" }, { id: "04-amber",   label: "AMBER",   hex: "#ff9e64" },
        { id: "05-topaz",   label: "TOPAZ",   hex: "#e0af68" }, { id: "06-citrine", label: "CITRINE", hex: "#f9e2af" },
        { id: "07-peridot", label: "PERIDOT", hex: "#a6e3a1" }, { id: "08-emerald", label: "EMERALD", hex: "#9ece6a" },
        { id: "09-verdant", label: "VERDANT", hex: "#73daca" }, { id: "10-lagoon",  label: "LAGOON",  hex: "#2ac3de" },
        { id: "11-glacier", label: "GLACIER", hex: "#7dcfff" }, { id: "12-cobalt",  label: "COBALT",  hex: "#7aa2f7" },
        { id: "13-indigo",  label: "INDIGO",  hex: "#6c71c4" }, { id: "14-violet",  label: "VIOLET",  hex: "#bb9af7" },
        { id: "15-orchid",  label: "ORCHID",  hex: "#cba6f7" }, { id: "16-fuchsia", label: "FUCHSIA", hex: "#f43f5e" }
    ]
    readonly property var barIconLabels: ({ wifi: "󰤨 WIFI", bluetooth: "󰂯 BT", speaker: "󰕾 SPK", mic: "󰍬 MIC", camera: "󰄀 CAM", battery: "󰁹 BAT", power: "󰐥 PWR" })

    function asciiBar(pct) { const f = Math.max(0, Math.min(16, Math.round((pct / 100.0) * 16))); return "[" + "█".repeat(f) + "░".repeat(16 - f) + "]"; }
    function runForge(target) { const q = String(target || forgeInput.text || "").trim().replace(/['"]/g, ""); if (!q) return; forgeInput.text = ""; Status.runForge(q); }
    function nextDockEdge() { const order = ["bottom", "left", "right", "top"], cur = String((Status.dockConfig && Status.dockConfig.position) || "bottom").toLowerCase(); Status.runDockCmd("position " + order[(order.indexOf(cur) + 1) % order.length]); }

    // ---------------- TAB 6: [6] THEME (16 Rainbow 16-Bit Themes, OpenRGB Hardware Lighting, Mode, Corners & SFX) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "theme"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "▸ 16-BIT RAINBOW PALETTES  —  ACTIVE: " + Theme.themeName.toUpperCase(); color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                    Rectangle { implicitWidth: 148; implicitHeight: 24; radius: Theme.radiusSm; color: wpM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ 󰸉 NEXT THEME ]"; color: wpM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: wpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("~/.config/hypr/scripts/wallpaper.sh next", false) } }
                }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; columns: 8; rowSpacing: 6; columnSpacing: 6
                    Repeater {
                        model: deckBody.themePresets
                        Rectangle {
                            id: tpBtn; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: tpM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bg); border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : modelData.hex
                            RowLayout { anchors.centerIn: parent; spacing: 5; Rectangle { width: 9; height: 9; radius: 2; color: tpBtn.modelData.hex; border.width: 1; border.color: tpBtn.isCur ? Theme.bg : Theme.fg } Text { text: tpBtn.modelData.label; color: tpBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                            MouseArea { id: tpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("~/.local/bin/supertheme " + tpBtn.modelData.id + " || ~/.local/bin/sf theme " + tpBtn.modelData.id, false) }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Status.rgbSupported ? Theme.cyan : Theme.border
            opacity: Status.rgbSupported ? 1.0 : 0.42; enabled: Status.rgbSupported
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 4
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "▸ OPENRGB HARDWARE LIGHTING"; color: Status.rgbSupported ? Theme.cyan : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                    Text { text: Status.rgbSupported ? ("[ " + Status.rgbCount + " RGB CONTROLLER(S) ONLINE ]") : "[ NO RGB HARDWARE DETECTED — DISABLED ]"; color: Status.rgbSupported ? Theme.green : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
                    Repeater {
                        model: deckBody.themePresets
                        Rectangle {
                            required property var modelData; readonly property bool isSel: ("#" + Status.rgbHex.toLowerCase()) === modelData.hex.toLowerCase()
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: modelData.hex; border.width: isSel ? 2 : 1; border.color: isSel ? Theme.fg : Theme.bg
                            MouseArea { anchors.fill: parent; cursorShape: Status.rgbSupported ? Qt.PointingHandCursor : Qt.ForbiddenCursor; onClicked: Status.setRgbColor(parent.modelData.hex) }
                        }
                    }
                    Rectangle { implicitWidth: 68; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "[ OFF ]"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Status.rgbSupported ? Qt.PointingHandCursor : Qt.ForbiddenCursor; onClicked: Status.setRgbColor("off") } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 62; spacing: 8
            Repeater {
                model: [
                    { act: "mode", label: "[ MODE: " + (Theme.mode === "light" ? "DAY" : "NIGHT") + " ]", sub: "Toggle Light / Dark Palette", col: Theme.cyan },
                    { act: "corners", label: "[ CORNERS: " + (Theme.corners === "rounded" ? "ROUNDED" : "SQUARE 90°") + " ]", sub: "Toggle Window & Panel Bevels", col: Theme.blue },
                    { act: "sfx", label: "[ 16-BIT SFX: " + (Status.sfxEnabled ? "ON" : "OFF") + " ]", sub: "Retro 16-Bit UI Audio Feedback", col: Status.sfxEnabled ? Theme.green : Theme.muted }
                ]
                Rectangle {
                    id: sfTog; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: sfM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: sfM.containsMouse ? Theme.cyan : modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 2; Text { Layout.alignment: Qt.AlignHCenter; text: sfTog.modelData.label; color: sfTog.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: sfTog.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                    MouseArea { id: sfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = sfTog.modelData.act; if (a === "sfx") Status.toggleSfx(); else if (a === "corners") deckBody.executeCommand("~/.local/bin/supertheme corners toggle || ~/.local/bin/sf theme corners toggle", false); else deckBody.executeCommand("~/.local/bin/supertheme toggle || ~/.local/bin/sf theme toggle", false); } }
                }
            }
        }
    }

    // ---------------- TAB 7: [7] DOCK (Quick Top Bar & SuperDock Controls) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "shell"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 8
                RowLayout { Layout.fillWidth: true; Text { text: "▸ QUICK BAR ICON ORGANIZER"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: "LEFT-CLICK TO SELECT  ·  RIGHT-CLICK TO HIDE"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Repeater {
                        model: Status.barIcons.filter(x => x !== "|")
                        Rectangle {
                            id: biChip; required property string modelData; readonly property bool isSel: deckBody.selBarIcon === modelData; readonly property bool isHid: Status.barHiddenIcons.indexOf(modelData) >= 0
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: biM.containsMouse ? Theme.bgHover : (isSel ? Theme.blue : Theme.bg); border.width: isSel ? 2 : 1; border.color: isSel ? Theme.cyan : (isHid ? Theme.muted : Theme.border)
                            Text { anchors.centerIn: parent; text: (biChip.isHid ? "× " : "") + (deckBody.barIconLabels[biChip.modelData] || biChip.modelData); color: biChip.isSel ? Theme.bg : (biChip.isHid ? Theme.muted : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                            MouseArea { id: biM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: e => { deckBody.selBarIcon = biChip.modelData; if (e.button === Qt.RightButton) Status.toggleBarIconHidden(biChip.modelData); else Status.playSfx("nav"); } }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; implicitHeight: 36; spacing: 8
                    Repeater {
                        model: [{ act: "left", label: "[ ◀ MOVE LEFT ]" }, { act: "right", label: "[ MOVE RIGHT ▶ ]" }, { act: "hide", label: Status.barHiddenIcons.indexOf(deckBody.selBarIcon) >= 0 ? "[ SHOW ICON ]" : "[ HIDE ICON ]" }, { act: "div", label: Status.barIcons.indexOf("|") >= 0 ? "[ DIVIDERS │: ON ]" : "[ DIVIDERS │: OFF ]" }, { act: "reset", label: "[ RESET ORDER ]" }]
                        Rectangle {
                            id: biAct; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: biActM.containsMouse ? Theme.cyan : Theme.bg; border.width: 2; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: biAct.modelData.label; color: biActM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                            MouseArea { id: biActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = biAct.modelData.act; if (a === "left") Status.moveBarIcon(deckBody.selBarIcon, -1); else if (a === "right") Status.moveBarIcon(deckBody.selBarIcon, 1); else if (a === "hide") Status.toggleBarIconHidden(deckBody.selBarIcon); else if (a === "div") Status.toggleBarDividers(); else Status.resetBarIcons(); } }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 82; spacing: 8
            Repeater {
                model: [{ act: "edge", label: "[ DOCK EDGE: " + String((Status.dockConfig && Status.dockConfig.position) || "bottom").toUpperCase() + " ]", sub: "Cycle Bottom / Left / Right / Top", col: Theme.yellow }, { act: "vis", label: "[ DOCK: " + ((Status.dockConfig && Status.dockConfig.showAlways === false) ? "AUTO-HIDE" : "ALWAYS ON") + " ]", sub: "Toggle Dock Visibility", col: Theme.cyan }, { act: "tiling", label: "[ WORKSPACE LAYOUT ]", sub: "Super + Y  ·  Tiling / Floating", col: Theme.green }, { act: "gaps", label: "[ TOGGLE WINDOW GAPS ]", sub: "Super + Backspace  ·  Zero / 10px", col: Theme.blue }]
                Rectangle {
                    id: shCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: shM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: shCard.modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 4; Text { Layout.alignment: Qt.AlignHCenter; text: shCard.modelData.label; color: shCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: shCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                    MouseArea { id: shM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = shCard.modelData.act; if (a === "edge") deckBody.nextDockEdge(); else if (a === "vis") Status.runDockCmd("always toggle"); else if (a === "tiling") deckBody.executeCommand("~/.config/hypr/scripts/toggle-tiling.sh cycle", false); else deckBody.executeCommand("~/.config/hypr/scripts/toggle-gaps.sh", false); } }
                }
            }
        }
    }

    // ---------------- TAB 8: [8] FORGE (Source Compiler & Chromeless Firefox WebApp Forge) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "forge"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Status.forgeBusy ? Theme.yellow : Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 8
                RowLayout { Layout.fillWidth: true; Text { text: "▸ SOURCE & CHROMELESS FIREFOX WEBAPP FORGE"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Rectangle { implicitWidth: 274; implicitHeight: 28; radius: Theme.radiusSm; color: profM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Status.forgeIsolated ? Theme.orange : Theme.green; Text { anchors.centerIn: parent; text: Status.forgeIsolated ? "[ PROFILE: ISOLATED SANDBOX ]" : "[ PROFILE: SHARED (MAIN FIREFOX) ]"; color: Status.forgeIsolated ? Theme.orange : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: profM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.forgeIsolated = !Status.forgeIsolated; Status.playSfx("toggle"); } } } }
                Text { text: "Enter a Website URL (or URL|Custom Name) for a chromeless Firefox WebApp, or a GitHub repo/preset to compile with -O3 -march=native"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: forgeInput.activeFocus ? Theme.cyan : Theme.border
                        TextInput {
                            id: forgeInput; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; Keys.onReturnPressed: deckBody.runForge(forgeInput.text)
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) { deckBody.closeRequested(); event.accepted = true; }
                                else if ((event.modifiers & (Qt.MetaModifier | Qt.AltModifier | Qt.ControlModifier)) && (event.key === Qt.Key_QuoteLeft || event.key === Qt.Key_AsciiTilde)) { deckBody.switchTabRequested(0); event.accepted = true; }
                                else if ((event.modifiers & (Qt.MetaModifier | Qt.AltModifier | Qt.ControlModifier)) && ((event.key >= Qt.Key_1 && event.key <= Qt.Key_9) || event.key === Qt.Key_0)) { deckBody.switchTabRequested(event.key === Qt.Key_0 ? 10 : (event.key - Qt.Key_1 + 1)); event.accepted = true; }
                                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { deckBody.cycleTabRequested(event.key === Qt.Key_Backtab || Boolean(event.modifiers & Qt.ShiftModifier)); event.accepted = true; }
                            }
                            Text { visible: forgeInput.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "https://claude.ai  or  https://site.io|App Name  or  owner/repo"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                        }
                    }
                    Rectangle { implicitWidth: 168; implicitHeight: 40; radius: Theme.radiusSm; color: Status.forgeBusy ? Theme.red : (fgGo.containsMouse ? Theme.cyan : Theme.blue); Text { anchors.centerIn: parent; text: Status.forgeBusy ? ("[ 󰅖 STOP (" + Status.forgePct + "%) ]") : "[ FORGE & INSTALL ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } MouseArea { id: fgGo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.forgeBusy) Status.stopForge(); else deckBody.runForge(forgeInput.text); } } }
                    Rectangle { implicitWidth: 148; implicitHeight: 40; radius: Theme.radiusSm; color: fgUpd.containsMouse ? Theme.green : Theme.bg; border.width: 2; border.color: Theme.green; Text { anchors.centerIn: parent; text: "[ 󰚰 UPDATE ALL ]"; color: fgUpd.containsMouse ? Theme.bg : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } MouseArea { id: fgUpd; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForge("update") } }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 46; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Status.forgeBusy ? Theme.yellow : (Status.forgeState === "error" ? Theme.red : Theme.border)
                    ColumnLayout {
                        anchors { fill: parent; margins: 8 } spacing: 2
                        RowLayout { Layout.fillWidth: true; Text { text: (Status.forgeBusy || Status.forgeRecent) ? ("󰙪 " + Status.forgeTarget + " — " + Status.forgeStep) : deckBody.forgeStatus; color: Status.forgeState === "error" ? Theme.red : (Status.forgeBusy ? Theme.yellow : Theme.green); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: deckBody.asciiBar(Status.forgePct) + " " + Status.forgePct + "%"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                        Text { text: Status.forgeLogLine || "WebApps are pinned to SuperDock and added to App Grid automatically."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
                RowLayout { Layout.fillWidth: true; implicitHeight: 28; spacing: 6; Repeater { model: ["https://claude.ai", "https://chatgpt.com", "https://github.com", "https://youtube.com", "btop", "fastfetch"]; Rectangle { id: qfBtn; required property string modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: qfM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "+ " + qfBtn.modelData.replace(/^https:\/\//, ""); color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: qfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForge(qfBtn.modelData) } } } }
                RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6; Text { text: "WEBAPPS:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } Text { visible: Status.forgedWebApps.length === 0; text: "No forged WebApps installed yet."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true } Repeater { model: Status.forgedWebApps; Rectangle { id: fwCard; required property var modelData; Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue; RowLayout { anchors { fill: parent; leftMargin: 8; rightMargin: 6 } spacing: 6; Text { text: "▸ " + fwCard.modelData.name + " [" + (fwCard.modelData.mode || "shared").toUpperCase() + "]"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: 54; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[OPEN]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("'" + fwCard.modelData.bin + "'", true) } } Rectangle { implicitWidth: 26; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "×"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeForge(fwCard.modelData.slug) } } } } } }
            }
        }
    }

    // ---------------- TAB 9: [9] STATE (Quick Btrfs Checkpoint & Rollback) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "state"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 102; spacing: 8
            Repeater {
                model: [{ title: "CPU UTILIZATION", val: Status.cpu, unit: "%", col: Status.cpu > 80 ? Theme.red : Theme.cyan }, { title: "MEMORY ALLOCATED", val: Status.mem, unit: "%", col: Status.mem > 85 ? Theme.yellow : Theme.blue }, { title: "THERMAL SENSOR", val: Status.tempC, unit: "°C", col: Status.tempC > 80 ? Theme.red : Theme.green }]
                Rectangle {
                    id: stCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 4; Text { Layout.alignment: Qt.AlignHCenter; text: stCard.modelData.title; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: stCard.modelData.val + stCard.modelData.unit; color: stCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: deckBody.asciiBar(stCard.modelData.val); color: stCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: ckM.containsMouse ? Theme.green : Theme.bgAlt; border.width: 2; border.color: Theme.green
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout { anchors.centerIn: parent; spacing: 8; Text { Layout.alignment: Qt.AlignHCenter; text: (ckM.containsMouse ? "▸ " : "") + "[ + SAVE BTRFS CHECKPOINT ]"; color: ckM.containsMouse ? Theme.bg : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: "Create Atomic Root Snapshot via Snapper"; color: ckM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                MouseArea { id: ckM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("(pkexec snapper -c root create -d 'SuperDesk Checkpoint' || ~/.local/bin/sf rollback --create 'SuperDesk Checkpoint') && (~/.local/bin/supernotify --banner checkpoint >/dev/null 2>&1 || ~/.local/bin/sf notify --banner checkpoint >/dev/null 2>&1 || true) && notify-send -a SuperFedora 'Btrfs Checkpoint' 'Saved SuperDesk Checkpoint'", false) }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: rbM.containsMouse ? Theme.yellow : Theme.bgAlt; border.width: 2; border.color: Theme.yellow
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout { anchors.centerIn: parent; spacing: 8; Text { Layout.alignment: Qt.AlignHCenter; text: (rbM.containsMouse ? "▸ " : "") + "[ ↺ ROLLBACK TO BASELINE ]"; color: rbM.containsMouse ? Theme.bg : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: "Restore Clean Pre-Install Btrfs Baseline"; color: rbM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                MouseArea { id: rbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.requestConfirm("ROLLBACK TO BASELINE SNAPSHOT", "pkexec ~/.local/bin/sf rollback --baseline || ~/.local/bin/sf rollback --baseline") }
            }
        }
    }

    // ---------------- TAB 0: [0] POWER (Quick Battery & Session Power Actions) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "power"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 108; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: deckBody.batCharging ? Theme.green : Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 10 } spacing: 6
                RowLayout { Layout.fillWidth: true; Text { text: "▸ " + (deckBody.batCharging ? "󰂄" : "󰁹") + "  BATTERY HEALTH & ENERGY TANK"; color: deckBody.batCharging ? Theme.green : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: deckBody.asciiBar(deckBody.batPresent ? deckBody.batPct : 100) + " " + (deckBody.batPresent ? deckBody.batPct : 100) + "% — " + (deckBody.batPresent ? (deckBody.batCharging ? "AC CHARGING" : "DISCHARGING") : "AC LINE POWER"); color: deckBody.batCharging ? Theme.green : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } }
                RowLayout { Layout.fillWidth: true; height: 22; spacing: 4; Repeater { model: 16; Rectangle { required property int index; readonly property int pct: deckBody.batPresent ? deckBody.batPct : 100; readonly property bool lit: (index + 1) * 6.25 <= pct + 2; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: !lit ? Theme.bg : (deckBody.batCharging ? Theme.green : (pct <= 20 ? Theme.red : Theme.cyan)); border.width: 1; border.color: lit ? Theme.cyan : Theme.border } } }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: Status.bat0Present ? ("THINKPAD BAT0 CHARGE THRESHOLD: " + Status.bat0Threshold) : "POWER SUPPLY: STANDARD ACPI / THINKPAD BAT0 READY"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true }
                    Rectangle { implicitWidth: 218; implicitHeight: 24; radius: Theme.radiusSm; color: Status.idleMode === "lock" ? Theme.cyan : (Status.idleMode === "screensaver" ? Theme.yellow : (awakeM.containsMouse ? Theme.blue : Theme.bg)); border.width: 1; border.color: Status.idleMode === "screensaver" ? Theme.yellow : Theme.cyan; Text { anchors.centerIn: parent; text: Status.idleMode === "lock" ? "[ 󰅶 󰌾 COFFEE: LOCK ONLY ]" : (Status.idleMode === "screensaver" ? "[ 󰅶 COFFEE: SCREENSAVER ]" : "[ 󰒲 AUTO-IDLE: POWER OFF ]"); color: (Status.idleMode !== "poweroff" || awakeM.containsMouse) ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: awakeM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleIdle() } }
                    Rectangle { implicitWidth: 186; implicitHeight: 24; radius: Theme.radiusSm; color: dpmsM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ 󰍹 SCREEN + KBD OFF ]"; color: dpmsM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: dpmsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off", true) } }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 8; columnSpacing: 8
            Repeater { model: [{ label: "[ 󰌾 LOCK SCREEN ]", sub: "SUPER + Esc  ·  Instant Session Lock", cmd: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", confirm: false, col: Theme.cyan }, { label: "[ 󰤄 SLEEP / SUSPEND ]", sub: "Low-Power S3 / s2idle Suspend", cmd: "systemctl suspend", confirm: true, col: Theme.yellow }, { label: "[ 󰜉 REBOOT SYSTEM ]", sub: "Warm Hardware Restart", cmd: "systemctl reboot", confirm: true, col: Theme.orange }, { label: "[ 󰐥 POWER OFF ]", sub: "Full System Shutdown", cmd: "systemctl poweroff", confirm: true, col: Theme.red }]; Rectangle { id: pwCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: pwM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: pwM.containsMouse ? Theme.cyan : modelData.col; Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius } ColumnLayout { anchors.centerIn: parent; spacing: 6; Text { Layout.alignment: Qt.AlignHCenter; text: (pwM.containsMouse ? "▸ " : "") + pwCard.modelData.label; color: pwCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: pwCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } } MouseArea { id: pwM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const d = pwCard.modelData; if (d.confirm) deckBody.requestConfirm(d.label, d.cmd); else deckBody.executeCommand(d.cmd, true); } } } }
        }
    }
}
