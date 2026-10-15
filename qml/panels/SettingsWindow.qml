import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."

// SuperFedora Settings Dock: Windows 11-inspired touch-friendly two-pane architecture with Top Auto-Filtering Search Bar.
PanelWindow {
    id: win
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(win.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (win.targetScreen === Quickshell.screens[0]) : (win.hyprMon !== null && win.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property string activePage: Status.normalizeSettingsPage(Status.settingsPage)
    readonly property int winW: Math.max(1180, Math.min(1520, Math.round(win.targetScreen.width * 0.84)))
    readonly property int winH: Math.max(680, Math.min(880, Math.round(win.targetScreen.height * 0.84)))
    property string searchQuery: ""

    visible: Status.settingsOpen && win.isTargetMon; screen: win.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-settings"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight; exclusionMode: ExclusionMode.Ignore

    readonly property var categories: pagesView.categories
    readonly property var currentCatObj: {
        for (const c of win.categories) if (c.id === win.activePage) return c;
        return win.categories[0] || { id: "system", tag: "[SYS]", icon: "󰍹", title: "System & Display", sub: "" };
    }

    NumberAnimation { id: openAnim; target: rootBox; property: "opacity"; from: 0.85; to: 1.0; duration: 65; easing.type: Easing.OutQuad }
    onVisibleChanged: if (win.visible) {
        win.searchQuery = "";
        searchBox.text = "";
        openAnim.restart();
        Status.refresh();
        rootBox.forceActiveFocus();
    }

    function selectCategory(id) {
        Status.settingsPage = id;
        if (win.searchQuery !== "") { win.searchQuery = ""; searchBox.text = ""; }
        Status.playSfx("click");
    }
    function stepCategory(delta) {
        const list = win.categories; if (!list || list.length === 0) return;
        const idx = list.findIndex(c => c.id === win.activePage);
        const next = (Math.max(0, idx) + delta + list.length) % list.length;
        win.selectCategory(list[next].id);
    }
    function runCmd(cmd, closeAfter) {
        if (closeAfter) Status.settingsOpen = false;
        Status.playSfx("confirm");
        Quickshell.execDetached(["sh", "-c", cmd]);
        Status.refresh();
    }

    // Click-Outside Backdrop
    MouseArea { id: bgArea; anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Status.settingsOpen = false }

    Rectangle {
        id: rootBox; width: win.winW; height: win.winH; anchors.centerIn: parent
        color: Theme.bg; radius: Theme.radius; border.width: 2; border.color: Theme.blue; focus: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (win.searchQuery !== "") { win.searchQuery = ""; searchBox.text = ""; }
                else { Status.settingsOpen = false; }
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                searchBox.forceActiveFocus(); event.accepted = true;
            } else if (!searchBox.activeFocus && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                win.stepCategory(event.key === Qt.Key_Down ? 1 : -1); event.accepted = true;
            } else if (!searchBox.activeFocus && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                searchBox.forceActiveFocus();
                searchBox.text += event.text;
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 8

            // ================ TOP BAR: Windows 11 Style Header + Auto-Filtering Search Bar ================
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 60; color: Theme.bgAlt; radius: Theme.radiusSm
                border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 14 }
                    spacing: 14

                    // Brand & Active User Account Pill
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            implicitWidth: 38; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bg
                            border.width: 1; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: "󰣛"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.bold: true }
                        }
                        ColumnLayout {
                            spacing: 1
                            Text { text: "SUPERFEDORA SETTINGS"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                            Text { text: Status.userAccount + "  ·  10 First-Principles Pillars"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                        }
                    }

                    // Centered Touch-Friendly Auto-Filtering Search Bar (44px tall)
                    Rectangle {
                        Layout.fillWidth: true; Layout.maximumWidth: 580; implicitHeight: 44; radius: Theme.radiusSm; color: Theme.bg
                        border.width: searchBox.activeFocus || win.searchQuery !== "" ? 2 : 1
                        border.color: searchBox.activeFocus || win.searchQuery !== "" ? Theme.cyan : Theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 10
                            Text { text: "󰍉"; color: searchBox.activeFocus || win.searchQuery !== "" ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true }
                            TextInput {
                                id: searchBox; Layout.fillWidth: true; verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; clip: true
                                onTextChanged: win.searchQuery = text
                                Keys.onEscapePressed: {
                                    if (searchBox.text !== "") { searchBox.text = ""; win.searchQuery = ""; rootBox.forceActiveFocus(); }
                                    else { Status.settingsOpen = false; }
                                }
                                Keys.onDownPressed: win.stepCategory(1)
                                Keys.onUpPressed: win.stepCategory(-1)
                                Text {
                                    visible: searchBox.text === ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Find a setting (type anywhere: printer, scale, bluetooth, zoom, ssh, night light)..."
                                    color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                                }
                            }
                            Rectangle {
                                visible: searchBox.text !== ""
                                implicitWidth: 64; implicitHeight: 28; radius: Theme.radiusSm
                                color: clrM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: Theme.border
                                Text { anchors.centerIn: parent; text: "[ CLEAR ]"; color: clrM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                MouseArea { id: clrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { searchBox.text = ""; win.searchQuery = ""; rootBox.forceActiveFocus(); } }
                            }
                        }
                    }

                    // Right Action Buttons: SuperDock + ESC Close (42px touch targets)
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            implicitWidth: 146; implicitHeight: 42; radius: Theme.radiusSm; color: qdM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: "[ 󰣛 SUPERDOCK ]"; color: qdM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                            MouseArea { id: qdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleSuperDeck(win.activePage) }
                        }
                        Rectangle {
                            implicitWidth: 82; implicitHeight: 42; radius: Theme.radiusSm; color: clsM.containsMouse ? Theme.red : Theme.bg; border.width: 1; border.color: clsM.containsMouse ? Theme.red : Theme.border
                            Text { anchors.centerIn: parent; text: "[ ESC ]"; color: clsM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                            MouseArea { id: clsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.settingsOpen = false }
                        }
                    }
                }
            }

            // ================ MAIN TWO-PANE BODY: Left 10-Pillar Rail + Right Scrollable Cards ================
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 8

                // LEFT SIDEBAR: 10 First-Principles Pillars (48px Touch-Friendly Rows)
                Rectangle {
                    Layout.preferredWidth: 292; Layout.fillHeight: true; color: Theme.bgAlt; radius: Theme.radiusSm
                    border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 5
                        Repeater {
                            model: win.categories
                            Rectangle {
                                id: catRow; required property var modelData
                                readonly property bool isCur: win.searchQuery === "" && win.activePage === modelData.id
                                readonly property int matchCount: pagesView.matchCountFor(modelData.id, win.searchQuery)
                                Layout.fillWidth: true; Layout.fillHeight: true; implicitHeight: 48; radius: Theme.radiusSm
                                opacity: (win.searchQuery !== "" && matchCount === 0) ? 0.42 : 1.0
                                color: isCur ? Theme.blue : (catM.containsMouse ? Theme.bgHover : Theme.bg)
                                border.width: isCur || (win.searchQuery !== "" && matchCount > 0) ? 1 : 0
                                border.color: isCur ? Theme.cyan : Theme.border
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                    spacing: 10
                                    Text { text: catRow.modelData.icon; color: catRow.isCur ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true }
                                    Text { text: catRow.modelData.tag; color: catRow.isCur ? Theme.bg : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                    Text { text: catRow.modelData.title; color: catRow.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Rectangle {
                                        visible: win.searchQuery !== "" && catRow.matchCount > 0
                                        implicitWidth: 26; implicitHeight: 20; radius: Theme.radiusSm; color: Theme.cyan
                                        Text { anchors.centerIn: parent; text: String(catRow.matchCount); color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                    }
                                    Text { visible: catRow.isCur; text: "▸"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                                }
                                MouseArea { id: catM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory(catRow.modelData.id) }
                            }
                        }
                    }
                }

                // RIGHT PANE: Category Banner + Scrollable Touch-Friendly Setting Cards
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.bgAlt; radius: Theme.radiusSm
                    border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        anchors.fill: parent; spacing: 0

                        // Active Category / Search Banner
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 58; color: "transparent"
                            RowLayout {
                                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: win.searchQuery !== ""
                                            ? ("󰍉  SEARCH RESULTS FOR \"" + win.searchQuery.toUpperCase() + "\" (" + pagesView.visibleItems.length + " MATCHING SETTINGS)")
                                            : (win.currentCatObj.icon + "  " + win.currentCatObj.tag + "  " + win.currentCatObj.title.toUpperCase())
                                        color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true
                                    }
                                    Text {
                                        text: win.searchQuery !== ""
                                            ? "Cross-listed settings matching your filter across all 10 system pillars  ·  Press ESC to clear search"
                                            : win.currentCatObj.sub
                                        color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                                    }
                                }
                            }
                            Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 } height: 1; color: Theme.border }
                        }

                        SettingsPages {
                            id: pagesView
                            Layout.fillWidth: true; Layout.fillHeight: true
                            activePage: win.activePage
                            searchQuery: win.searchQuery
                            onExecuteCommand: (cmd, closeAfter) => win.runCmd(cmd, closeAfter)
                        }
                    }
                }
            }
        }
    }
}
