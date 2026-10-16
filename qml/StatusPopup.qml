import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Quick AI Console Overlay (`Super + \``): Self-Contained SuperDock Console & Built-in Harness/LLM Settings.
PanelWindow {
    id: pop
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(pop.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (pop.targetScreen === Quickshell.screens[0]) : (pop.hyprMon !== null && pop.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property int fullW: Math.max(1060, Math.min(1340, Math.round(pop.targetScreen.width * 0.76)))
    readonly property int fullH: Math.max(660, Math.min(840, Math.round(pop.targetScreen.height * 0.78)))
    property string editMode: Status.aiMode || "allinone"; property string editAgent: Status.aiAgent === "ollama" ? "agy" : (Status.aiAgent || "agy")
    property string editHarness: Status.aiHarness || "pi"; property string editHost: Status.ollamaEndpoint || "127.0.0.1:11434"; property string editModel: Status.ollamaModel || "llama3.2"

    function syncDrafts() { pop.editMode = Status.aiMode || (Status.aiAgent === "ollama" ? "modular" : "allinone"); pop.editAgent = Status.aiAgent === "ollama" ? "agy" : (Status.aiAgent || "agy"); pop.editHarness = Status.aiHarness || "pi"; pop.editHost = Status.ollamaEndpoint || "127.0.0.1:11434"; pop.editModel = Status.ollamaModel || "llama3.2"; }
    function toggleDockSettings() { Status.playSfx("click"); if (!Status.superDeckSettingsOpen) { pop.syncDrafts(); Status.refresh(); } Status.superDeckSettingsOpen = !Status.superDeckSettingsOpen; }
    function applyCurrentSelection() { const h = (hostInput.text || pop.editHost || Status.ollamaEndpoint).trim(), m = (modelInput.text || pop.editModel || Status.ollamaModel).trim(); Status.applySuperDeckConfig(pop.editMode, pop.editMode === "modular" ? pop.editHarness : pop.editAgent, h, m); }

    visible: Status.superDeckOpen && pop.isTargetMon; screen: pop.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-superdeck"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Status.superDeckSettingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight; exclusionMode: ExclusionMode.Ignore
    mask: Region { item: bgArea; Region { intersection: Intersection.Subtract; item: aiHole } }

    MouseArea { id: bgArea; anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Status.superDeckOpen = false }
    Item { id: aiHole; x: box.x + 12; y: box.y + 46; width: Status.superDeckSettingsOpen ? 0 : (pop.fullW - 24); height: Status.superDeckSettingsOpen ? 0 : (pop.fullH - 60) }

    Rectangle {
        id: box; width: pop.fullW; height: pop.fullH; anchors.centerIn: parent; color: "transparent"; radius: 8; border.width: 1; border.color: Theme.border
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 42; radius: 7; color: Theme.bg }
        Rectangle { x: 1; y: 42; width: 10; height: parent.height - 44; color: Theme.bg }
        Rectangle { x: parent.width - 11; y: 42; width: 10; height: parent.height - 44; color: Theme.bg }
        Rectangle { x: 1; y: parent.height - 12; width: parent.width - 2; height: 11; radius: 7; color: Theme.bg }
        Rectangle { x: 10; y: 44; width: parent.width - 20; height: parent.height - 56; color: Status.superDeckSettingsOpen ? Theme.bg : "transparent"; radius: 6; border.width: 1; border.color: Theme.blue }

        RowLayout {
            height: 30; spacing: 8
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 12; topMargin: 7 }
            Rectangle {
                implicitWidth: 96; implicitHeight: 28; radius: 5; color: !Status.superDeckSettingsOpen ? Theme.blue : (conTabM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: !Status.superDeckSettingsOpen ? Theme.blue : Theme.border
                Text { anchors.centerIn: parent; text: "󰆍 Console"; color: !Status.superDeckSettingsOpen ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                MouseArea { id: conTabM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); Status.superDeckSettingsOpen = false; } }
            }
            Rectangle {
                implicitWidth: 148; implicitHeight: 28; radius: 5; color: Status.superDeckSettingsOpen ? Theme.blue : (cfgTabM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: Status.superDeckSettingsOpen ? Theme.blue : Theme.border
                Text { anchors.centerIn: parent; text: "󰒓 Harness & LLM"; color: Status.superDeckSettingsOpen ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                MouseArea { id: cfgTabM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.toggleDockSettings() }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 28; radius: 5; color: pillM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: pillM.containsMouse ? Theme.blue : Theme.border
                RowLayout {
                    spacing: 8; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    Text { text: Status.aiMode === "modular" ? "󰒋" : "󰚩"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; text: Status.aiMode === "modular" ? ("Modular  ·  Harness: " + Status.aiHarness.toUpperCase() + "  ·  LLM: " + Status.ollamaModel + " @ " + Status.ollamaEndpoint) : ("All-in-One  ·  " + (Status.aiAgentLabel || Status.aiAgent.toUpperCase())) }
                    Text { text: Status.superDeckSettingsOpen ? "[View Console]" : "[Configure]"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                }
                MouseArea { id: pillM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.toggleDockSettings() }
            }
            Rectangle {
                implicitWidth: 92; implicitHeight: 28; radius: 5; color: relM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "󰑐 Restart"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                MouseArea { id: relM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); Status.superDeckSettingsOpen = false; Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh restart"]); } }
            }
            Rectangle {
                implicitWidth: 32; implicitHeight: 28; radius: 5; color: escM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: escM.containsMouse ? Theme.red : Theme.border
                Text { anchors.centerIn: parent; text: "󰅖"; color: escM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                MouseArea { id: escM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.superDeckOpen = false }
            }
        }

        // Self-Contained SuperDock Settings View (Independent of SuperSettings)
        Item {
            visible: Status.superDeckSettingsOpen; x: 12; y: 46; width: parent.width - 24; height: parent.height - 60; clip: true
            Flickable {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: bottomBar.top; margins: 16; bottomMargin: 10 }
                contentWidth: width; contentHeight: settingsCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: settingsCol; width: parent.width; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Repeater {
                            model: [
                                { id: "modular", icon: "󰒋", title: "Pick Harness + LLM (Modular)", desc: "Choose a coding harness (Pi, MiniMax, OpenCode, Aider) and pair it with any Ollama / LLM server & model." },
                                { id: "allinone", icon: "󰚩", title: "All-in-One Agent (Integrated)", desc: "Use a self-contained CLI agent with its own integrated harness and provider (Antigravity, Vibe, Grok, Claude, Codex)." }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true; implicitHeight: 66; radius: 7; readonly property bool sel: pop.editMode === modelData.id
                                color: sel ? Qt.rgba(0.48, 0.64, 0.97, 0.16) : (mCardM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: sel ? 2 : 1; border.color: sel ? Theme.blue : Theme.border
                                ColumnLayout {
                                    spacing: 4; anchors { fill: parent; margins: 12 }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 8
                                        Text { text: modelData.icon; color: sel ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                        Text { text: modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.Bold; Layout.fillWidth: true }
                                        Text { visible: sel; text: "[SELECTED]"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold }
                                    }
                                    Text { text: modelData.desc; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                MouseArea { id: mCardM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); pop.editMode = modelData.id; } }
                            }
                        }
                    }

                    // === ALL-IN-ONE AGENT PICKER ===
                    ColumnLayout {
                        visible: pop.editMode === "allinone"; Layout.fillWidth: true; spacing: 10
                        Text { text: "SELECT ALL-IN-ONE AGENT (CLICK TO SELECT, OR CLICK LAUNCH TO START IMMEDIATELY)"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Bold }
                        GridLayout {
                            Layout.fillWidth: true; columns: 2; rowSpacing: 8; columnSpacing: 10
                            Repeater {
                                model: (Status.aiHarnesses || []).filter(a => a.id !== "ollama")
                                delegate: Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 56; radius: 6; readonly property bool sel: pop.editAgent === modelData.id
                                    color: sel ? Qt.rgba(0.48, 0.64, 0.97, 0.16) : (agM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: sel ? 2 : 1; border.color: sel ? Theme.blue : Theme.border
                                    RowLayout {
                                        spacing: 10; anchors { fill: parent; margins: 10 }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { text: modelData.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "Command: " + modelData.cmd; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true }
                                        }
                                        Text { text: modelData.installed ? "[READY]" : "[MISSING]"; color: modelData.installed ? Theme.green : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold }
                                        Rectangle {
                                            implicitWidth: 68; implicitHeight: 26; radius: 4; color: lnM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.blue
                                            Text { anchors.centerIn: parent; text: "Launch"; color: lnM.containsMouse ? Theme.bg : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold }
                                            MouseArea { id: lnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { pop.editAgent = modelData.id; pop.applyCurrentSelection(); } }
                                        }
                                    }
                                    MouseArea { id: agM; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); pop.editAgent = modelData.id; } onDoubleClicked: { pop.editAgent = modelData.id; pop.applyCurrentSelection(); } }
                                }
                            }
                        }
                    }

                    // === MODULAR: PICK HARNESS + PICK LLM SERVER & MODEL ===
                    ColumnLayout {
                        visible: pop.editMode === "modular"; Layout.fillWidth: true; spacing: 12
                        Text { text: "1. PICK CODING HARNESS"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Bold }
                        GridLayout {
                            Layout.fillWidth: true; columns: 3; rowSpacing: 8; columnSpacing: 8
                            Repeater {
                                model: Status.modularHarnesses || []
                                delegate: Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 54; radius: 6; readonly property bool sel: pop.editHarness === modelData.id
                                    color: sel ? Qt.rgba(0.48, 0.64, 0.97, 0.16) : (hM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: sel ? 2 : 1; border.color: sel ? Theme.blue : Theme.border
                                    ColumnLayout {
                                        spacing: 2; anchors { fill: parent; margins: 8 }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 6
                                            Text { text: modelData.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: modelData.installed ? "[OK]" : "[--]"; color: modelData.installed ? Theme.green : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold }
                                        }
                                        Text { text: modelData.desc; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                    MouseArea { id: hM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); pop.editHarness = modelData.id; } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Text { text: "2. PICK LLM SERVER / ENDPOINT"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Bold }
                            Text { text: Status.ollamaOnline ? ("[ONLINE · " + (Status.ollamaModels || []).length + " models ready]") : "[SERVER OFFLINE OR UNPROBED]"; color: Status.ollamaOnline ? Theme.green : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold }
                            Item { Layout.fillWidth: true }
                        }
                        Flow {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: Status.llmServers || []
                                delegate: Rectangle {
                                    implicitWidth: srvTxt.implicitWidth + 20; implicitHeight: 28; radius: 5; readonly property bool sel: pop.editHost === modelData.host
                                    color: sel ? Theme.blue : (srvM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: sel ? Theme.blue : Theme.border
                                    Text { id: srvTxt; anchors.centerIn: parent; text: "󰒋 " + modelData.name + " (" + modelData.host + ")"; color: sel ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold }
                                    MouseArea { id: srvM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { pop.editHost = modelData.host; hostInput.text = modelData.host; if (modelData.model) { pop.editModel = modelData.model; modelInput.text = modelData.model; } Status.probeSuperDeckHost(modelData.host, modelData.model); } }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: hostInput.activeFocus ? Theme.blue : Theme.border
                                TextInput { id: hostInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; text: pop.editHost; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; selectByMouse: true; onTextEdited: pop.editHost = text; onAccepted: Status.probeSuperDeckHost(text, modelInput.text) }
                            }
                            Rectangle {
                                implicitWidth: 120; implicitHeight: 32; radius: 5; color: prbM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Theme.blue
                                Text { anchors.centerIn: parent; text: "󰑐 Probe Server"; color: prbM.containsMouse ? Theme.bg : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                                MouseArea { id: prbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.probeSuperDeckHost(hostInput.text, modelInput.text) }
                            }
                            Rectangle {
                                implicitWidth: 112; implicitHeight: 32; radius: 5; color: svM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                                Text { anchors.centerIn: parent; text: "+ Save Server"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                                MouseArea { id: svM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.saveLlmServer(hostInput.text, hostInput.text, "ollama", modelInput.text || pop.editModel) }
                            }
                        }

                        Text { text: "3. PICK LLM MODEL"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Bold }
                        Flow {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: Status.ollamaModels || []
                                delegate: Rectangle {
                                    implicitWidth: mdlRow.implicitWidth + 20; implicitHeight: 30; radius: 5; readonly property bool sel: pop.editModel === modelData.name
                                    color: sel ? Theme.blue : (omM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: sel ? Theme.blue : (modelData.loaded ? Theme.green : Theme.border)
                                    RowLayout {
                                        id: mdlRow; anchors.centerIn: parent; spacing: 6
                                        Text { text: modelData.name; color: sel ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                                        Text { visible: modelData.size !== ""; text: "[" + modelData.size + (modelData.loaded ? " · LOADED" : "") + "]"; color: sel ? Theme.bg : (modelData.loaded ? Theme.green : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold }
                                    }
                                    MouseArea { id: omM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); pop.editModel = modelData.name; modelInput.text = modelData.name; } onDoubleClicked: { pop.editModel = modelData.name; modelInput.text = modelData.name; pop.applyCurrentSelection(); } }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "Model ID:"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: modelInput.activeFocus ? Theme.blue : Theme.border
                                TextInput { id: modelInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; text: pop.editModel; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; selectByMouse: true; onTextEdited: pop.editModel = text; onAccepted: pop.applyCurrentSelection() }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: bottomBar; height: 48; color: Theme.bgAlt; radius: 6; border.width: 1; border.color: Theme.border
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                RowLayout {
                    spacing: 10; anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold
                        text: pop.editMode === "modular" ? ("Ready: " + pop.editHarness.toUpperCase() + "  +  " + (modelInput.text || pop.editModel) + "  @  " + (hostInput.text || pop.editHost)) : ("Ready: All-in-One  ·  " + pop.editAgent.toUpperCase())
                    }
                    Rectangle {
                        implicitWidth: 96; implicitHeight: 32; radius: 5; color: canM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        MouseArea { id: canM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); Status.superDeckSettingsOpen = false; } }
                    }
                    Rectangle {
                        implicitWidth: 210; implicitHeight: 32; radius: 5; color: appM.containsMouse ? Theme.green : Theme.blue; border.width: 1; border.color: appM.containsMouse ? Theme.green : Theme.blue
                        Text { anchors.centerIn: parent; text: "󰐊 Apply & Launch Console"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Bold }
                        MouseArea { id: appM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.applyCurrentSelection() }
                    }
                }
            }
        }
    }
}
