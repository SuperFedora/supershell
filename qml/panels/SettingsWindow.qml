import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."

// Modern Windows 11 (WinUI 3 / Fluent) Settings Window: Left Profile + Search + Pill Nav Rail & Right Hero + Cards Pane.
PanelWindow {
    id: win
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(win.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (win.targetScreen === Quickshell.screens[0]) : (win.hyprMon !== null && win.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property string activePage: Status.normalizeSettingsPage(Status.settingsPage)
    readonly property int winW: Math.max(1060, Math.min(1340, Math.round(win.targetScreen.width * 0.76)))
    readonly property int winH: Math.max(660, Math.min(840, Math.round(win.targetScreen.height * 0.78)))
    property string searchQuery: ""

    visible: Status.settingsOpen && win.isTargetMon; screen: win.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-settings"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight; exclusionMode: ExclusionMode.Ignore

    readonly property var categories: pagesView.categories
    readonly property var currentCatObj: {
        for (const c of win.categories) if (c.id === win.activePage) return c;
        return win.categories[0] || { id: "home", icon: "󰋜", title: "Home", sub: "" };
    }
    readonly property string userShort: String(Status.userAccount || "user").split("@")[0]
    readonly property string hostShort: String(Status.userAccount || "user@fedora").split("@")[1] || "workstation"

    NumberAnimation { id: openAnim; target: rootBox; property: "opacity"; from: 0.88; to: 1.0; duration: 90; easing.type: Easing.OutCubic }
    function clearSearch() { if (win.searchQuery !== "") { win.searchQuery = ""; searchBox.text = ""; } rootBox.forceActiveFocus(); }
    function navBackAction() { if (win.searchQuery !== "") win.clearSearch(); else { rootBox.forceActiveFocus(); Status.navBack(); } }
    function navUpAction() { if (win.searchQuery !== "") win.clearSearch(); else { rootBox.forceActiveFocus(); Status.navUp(); } }
    Connections { target: Status; function onSettingsPageChanged() { win.clearSearch(); } function onExpandedSettingIdChanged() { win.clearSearch(); } function onSettingsSubPanelChanged() { win.clearSearch(); } }
    onVisibleChanged: if (win.visible) {
        win.searchQuery = ""; searchBox.text = ""; openAnim.restart(); Status.refresh(); rootBox.forceActiveFocus();
    }

    function selectCategory(id) { win.clearSearch(); Status.openSettings(id); }
    function stepCategory(delta) { const list = win.categories; if (!list || list.length === 0) return; const idx = list.findIndex(c => c.id === win.activePage); win.selectCategory(list[(Math.max(0, idx) + delta + list.length) % list.length].id); }
    function runCmd(cmd, closeAfter) { if (closeAfter) Status.settingsOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }

    MouseArea { id: bgArea; anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Status.settingsOpen = false }

    Rectangle {
        id: rootBox; width: win.winW; height: win.winH; anchors.centerIn: parent
        color: Theme.bg; radius: 8; border.width: 1; border.color: Theme.border; focus: true; clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: mouse => { rootBox.forceActiveFocus(); if (mouse.button === Qt.BackButton) win.navBackAction(); } }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { if (win.searchQuery !== "") win.clearSearch(); else if (Status.expandedSettingId !== "" || Status.settingsSubPanel !== "") win.navUpAction(); else Status.settingsOpen = false; event.accepted = true; }
            else if (((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Left) || (rootBox.activeFocus && event.key === Qt.Key_Backspace)) { win.navBackAction(); event.accepted = true; }
            else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Up) { win.navUpAction(); event.accepted = true; }
            else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) { searchBox.forceActiveFocus(); event.accepted = true; }
            else if (rootBox.activeFocus && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) { win.stepCategory(event.key === Qt.Key_Down ? 1 : -1); event.accepted = true; }
            else if (rootBox.activeFocus && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { searchBox.forceActiveFocus(); searchBox.text += event.text; event.accepted = true; }
        }

        RowLayout {
            anchors.fill: parent; spacing: 0

            // ================ LEFT NAVIGATION RAIL (Windows 11 WinUI 3 Style) ================
            Rectangle {
                Layout.preferredWidth: 272; Layout.fillHeight: true; color: Theme.bg
                ColumnLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 10; topMargin: 14; bottomMargin: 14 } spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; Layout.leftMargin: 2; spacing: 8
                        Rectangle { readonly property bool canB: Status.canNavBack || win.searchQuery !== ""; implicitWidth: 28; implicitHeight: 26; radius: 5; opacity: canB ? 1.0 : 0.38; color: railBackM.containsMouse && canB ? Theme.bgHover : "transparent"; Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: railBackM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canB; cursorShape: Qt.PointingHandCursor; onClicked: win.navBackAction() } }
                        Text { text: "󰣛"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                        Text { text: "Settings"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium }
                    }

                    // User Profile Header Card (Click -> Accounts)
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 50; radius: 6; color: usrM.containsMouse ? Theme.bgHover : "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 12
                            Rectangle { implicitWidth: 36; implicitHeight: 36; radius: 18; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: win.userShort.slice(0, 1).toUpperCase(); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true } }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: win.userShort; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: Status.userAccount; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                        }
                        MouseArea { id: usrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory("accounts") }
                    }

                    // Windows 11 "Find a setting" Search Box with Bottom Accent Line
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 34; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: searchBox.activeFocus ? Theme.blue : Theme.border
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 1; rightMargin: 1 } height: 2; radius: 1; color: searchBox.activeFocus ? Theme.blue : "transparent" }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 8
                            TextInput {
                                id: searchBox; Layout.fillWidth: true; verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                                onTextChanged: win.searchQuery = text
                                Keys.onEscapePressed: { if (searchBox.text !== "") win.clearSearch(); else if (Status.expandedSettingId !== "" || Status.settingsSubPanel !== "") win.navUpAction(); else Status.settingsOpen = false; }
                                Keys.onDownPressed: win.stepCategory(1); Keys.onUpPressed: win.stepCategory(-1)
                                Text { visible: searchBox.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Find a setting"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                            }
                            Text { text: searchBox.text !== "" ? "󰅖" : "󰍉"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; MouseArea { anchors.fill: parent; enabled: searchBox.text !== ""; cursorShape: Qt.PointingHandCursor; onClicked: win.clearSearch() } }
                        }
                    }

                    // 12 Clean Navigation Items (Home + 11 Categories) with Left Vertical Accent Indicator
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 2
                        Repeater {
                            model: win.categories
                            Rectangle {
                                id: catRow; required property var modelData
                                readonly property bool isCur: win.searchQuery === "" && win.activePage === modelData.id
                                readonly property int matchCount: pagesView.matchCountFor(modelData.id, win.searchQuery)
                                Layout.fillWidth: true; implicitHeight: 32; radius: 6
                                opacity: (win.searchQuery !== "" && modelData.id !== "home" && matchCount === 0) ? 0.42 : 1.0
                                color: isCur ? Theme.bgAlt : (catM.containsMouse ? Theme.bgHover : "transparent")
                                Rectangle { visible: catRow.isCur; width: 3; height: 16; radius: 1.5; anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter } color: Theme.blue }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 10 } spacing: 12
                                    Text { text: catRow.modelData.icon; color: catRow.isCur ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                    Text { text: catRow.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: catRow.isCur ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Rectangle { visible: win.searchQuery !== "" && catRow.matchCount > 0; implicitWidth: 22; implicitHeight: 18; radius: 9; color: Theme.bgHover; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: String(catRow.matchCount); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } }
                                }
                                MouseArea { id: catM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory(catRow.modelData.id) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.border; opacity: 0.45 }
            }

            // ================ RIGHT CONTENT PANE (Back/Up Bar + Breadcrumbs + Dedicated Panels) ================
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

                Item {
                    Layout.fillWidth: true; implicitHeight: win.searchQuery === "" && win.activePage === "system" && Status.expandedSettingId === "" ? 132 : 68
                    ColumnLayout {
                        anchors { fill: parent; leftMargin: 28; rightMargin: 24; topMargin: 16; bottomMargin: 8 } spacing: 12
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { readonly property bool canB: Status.canNavBack || win.searchQuery !== ""; implicitWidth: 68; implicitHeight: 30; radius: 5; opacity: canB ? 1.0 : 0.42; color: backBtnM.containsMouse && canB ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰁍  Back"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium } MouseArea { id: backBtnM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canB; cursorShape: Qt.PointingHandCursor; onClicked: win.navBackAction() } }
                            Rectangle { readonly property bool canU: Status.canNavUp || win.searchQuery !== ""; implicitWidth: 58; implicitHeight: 30; radius: 5; opacity: canU ? 1.0 : 0.42; color: upBtnM.containsMouse && canU ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰁝  Up"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium } MouseArea { id: upBtnM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canU; cursorShape: Qt.PointingHandCursor; onClicked: win.navUpAction() } }
                            RowLayout {
                                Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 8
                                Text { visible: win.searchQuery === "" && win.activePage !== "home" && Status.expandedSettingId === ""; text: "Home"; color: bcHmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.weight: Font.Medium; MouseArea { id: bcHmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory("home") } }
                                Text { visible: win.searchQuery === "" && win.activePage !== "home" && Status.expandedSettingId === ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                Text { visible: win.searchQuery === "" && Status.expandedSettingId !== ""; text: win.currentCatObj.title; color: bcCatM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.weight: Font.Medium; MouseArea { id: bcCatM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem(win.activePage, "", "") } }
                                Text { visible: win.searchQuery === "" && Status.expandedSettingId !== ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                Text { visible: win.searchQuery === "" && Status.expandedSettingId !== "" && Status.settingsSubPanel !== ""; text: pagesView.curItemTitle; color: bcItmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 5; font.weight: Font.Medium; elide: Text.ElideRight; Layout.maximumWidth: 260; MouseArea { id: bcItmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsSub("") } }
                                Text { visible: win.searchQuery === "" && Status.expandedSettingId !== "" && Status.settingsSubPanel !== ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                Text { text: win.searchQuery !== "" ? ("Search results for \"" + win.searchQuery + "\"") : (Status.settingsSubPanel !== "" ? pagesView.curSubTitle : (Status.expandedSettingId !== "" ? pagesView.curItemTitle : win.currentCatObj.title)); color: Theme.fg; font.family: Theme.font; font.pixelSize: Status.expandedSettingId !== "" ? (Theme.fontSize + 5) : (Theme.fontSize + 8); font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            Rectangle { implicitWidth: 106; implicitHeight: 30; radius: 5; color: qdM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "󰚩  Quick AI"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { id: qdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleSuperDeck("ai") } }
                            Rectangle { implicitWidth: 32; implicitHeight: 30; radius: 5; color: clsM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clsM.containsMouse ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: "󰅖"; color: clsM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: clsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.settingsOpen = false } }
                        }

                        // Windows 11 Hero Device Strip (Shown on System top-level page)
                        RowLayout {
                            visible: win.searchQuery === "" && win.activePage === "system" && Status.expandedSettingId === ""; Layout.fillWidth: true; spacing: 20
                            RowLayout {
                                spacing: 12
                                Rectangle { implicitWidth: 68; implicitHeight: 42; radius: 6; color: Theme.bgAlt; border.width: 2; border.color: sysMonM.containsMouse ? Theme.cyan : Theme.blue; clip: true; Image { id: sysWpImg; anchors { fill: parent; margins: 2 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false } Text { visible: sysWpImg.status !== Image.Ready; anchors.centerIn: parent; text: "󰍹"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 8 } MouseArea { id: sysMonM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } }
                                ColumnLayout { spacing: 1; Text { text: win.hostShort; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "sys-storage") } } Text { text: Status.gpuArch + "  ·  " + Theme.themeName + " 󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } } }
                            }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                spacing: 18
                                RowLayout { spacing: 8; Text { text: Status.wifiEnabled ? "󰤨" : "󰈀"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { spacing: 0; Text { text: (Status.ssid || Status.netIface) + " 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("network", "net-wifi") } } Text { text: "Connected"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                RowLayout { spacing: 8; Text { text: "󰓅"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { spacing: 0; Text { text: "Power mode 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("power", "pwr-mode") } } Text { text: Status.workstationMode; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                            }
                        }
                    }
                }

                SettingsHome {
                    visible: win.searchQuery === "" && win.activePage === "home"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    hostShort: win.hostShort
                    onSelectCategory: catId => win.selectCategory(catId)
                    onExecuteCommand: (cmd, closeAfter) => win.runCmd(cmd, closeAfter)
                }

                SettingsPages {
                    id: pagesView
                    visible: win.searchQuery !== "" || win.activePage !== "home"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    activePage: win.activePage; searchQuery: win.searchQuery
                    onClearSearchRequested: win.clearSearch()
                    onExecuteCommand: (cmd, closeAfter) => win.runCmd(cmd, closeAfter)
                }
            }
        }
    }
}
