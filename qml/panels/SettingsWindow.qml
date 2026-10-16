import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// Modern Windows 11 (WinUI 3 / Fluent) Tiled & Responsive Settings Window: Adaptive Nav Rail + Right Hero & Cards Pane.
FloatingWindow {
    id: win
    title: "SuperSettings"
    visible: Status.settingsOpen
    implicitWidth: 1120; implicitHeight: 740
    minimumSize: Qt.size(420, 420)
    color: Theme.bg

    readonly property string activePage: Status.normalizeSettingsPage(Status.settingsPage)
    property string searchQuery: ""
    property int navMode: 0
    readonly property bool compactWindow: win.width < 860
    readonly property bool veryNarrow: win.width < 620
    readonly property bool railCollapsed: win.veryNarrow || win.navMode === 2 || (win.navMode === 0 && win.compactWindow)
    onCompactWindowChanged: win.navMode = 0

    readonly property var categories: pagesView.categories
    readonly property var currentCatObj: {
        for (const c of win.categories) if (c.id === win.activePage) return c;
        return win.categories[0] || { id: "home", icon: "󰋜", title: "Home", sub: "" };
    }
    readonly property string userShort: String(Status.userAccount || "user").split("@")[0]
    readonly property string displayUser: Status.userFullName || win.userShort
    readonly property string displaySub: Status.userEmail || Status.userAccount
    readonly property string hostShort: Status.userDeviceName || Status.hostName

    NumberAnimation { id: openAnim; target: rootBox; property: "opacity"; from: 0.88; to: 1.0; duration: 90; easing.type: Easing.OutCubic }
    function toggleRail() { win.navMode = win.railCollapsed ? 1 : 2; }
    function focusSearch() { if (win.railCollapsed && !win.veryNarrow) win.navMode = 1; searchBox.forceActiveFocus(); }
    function clearSearch() { if (win.searchQuery !== "") { win.searchQuery = ""; searchBox.text = ""; } rootBox.forceActiveFocus(); }
    function navBackAction() { if (win.searchQuery !== "") win.clearSearch(); else { rootBox.forceActiveFocus(); Status.navBack(); } }
    function navUpAction() { if (win.searchQuery !== "") win.clearSearch(); else { rootBox.forceActiveFocus(); Status.navUp(); } }
    Connections {
        target: Status
        function onSettingsOpenChanged() { if (Status.settingsOpen) rootBox.forceActiveFocus(); }
        function onSettingsPageChanged() { win.clearSearch(); }
        function onExpandedSettingIdChanged() { win.clearSearch(); }
        function onSettingsSubPanelChanged() { win.clearSearch(); }
    }
    onClosed: Status.settingsOpen = false
    onVisibleChanged: {
        if (!win.visible && Status.settingsOpen) Status.settingsOpen = false;
        if (win.visible) { win.searchQuery = ""; searchBox.text = ""; openAnim.restart(); Status.refresh(); rootBox.forceActiveFocus(); }
    }

    function selectCategory(id) { win.clearSearch(); Status.openSettings(id); }
    function stepCategory(delta) { const list = win.categories; if (!list || list.length === 0) return; const idx = list.findIndex(c => c.id === win.activePage); win.selectCategory(list[(Math.max(0, idx) + delta + list.length) % list.length].id); }
    function runCmd(cmd, closeAfter) { if (closeAfter) Status.settingsOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", closeAfter ? cmd : ("(" + cmd + "); qs ipc call status refresh >/dev/null 2>&1 || true")]); }

    Rectangle {
        id: rootBox; anchors.fill: parent; color: Theme.bg; focus: true; clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: mouse => { rootBox.forceActiveFocus(); if (mouse.button === Qt.BackButton) win.navBackAction(); } }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { if (pagesView.confirmDanger !== "") pagesView.confirmDanger = ""; else if (win.searchQuery !== "") win.clearSearch(); else if (Status.expandedSettingId !== "" || Status.settingsSubPanel !== "") win.navUpAction(); else Status.settingsOpen = false; event.accepted = true; }
            else if (((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Left) || (rootBox.activeFocus && event.key === Qt.Key_Backspace)) { win.navBackAction(); event.accepted = true; }
            else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Up) { win.navUpAction(); event.accepted = true; }
            else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) { win.focusSearch(); event.accepted = true; }
            else if (rootBox.activeFocus && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) { win.stepCategory(event.key === Qt.Key_Down ? 1 : -1); event.accepted = true; }
            else if (rootBox.activeFocus && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { win.focusSearch(); searchBox.text += event.text; event.accepted = true; }
        }

        RowLayout {
            anchors.fill: parent; spacing: 0

            // ================ LEFT NAVIGATION RAIL (Adaptive Full 264px / Compact 52px Rail) ================
            Rectangle {
                Layout.preferredWidth: win.railCollapsed ? 52 : 264; Layout.fillHeight: true; color: Theme.bg
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                ColumnLayout {
                    anchors { fill: parent; leftMargin: win.railCollapsed ? 6 : 12; rightMargin: win.railCollapsed ? 6 : 10; topMargin: 12; bottomMargin: 12 } spacing: 6
                    GridLayout {
                        Layout.fillWidth: true; columns: win.railCollapsed ? 1 : 4; columnSpacing: 6; rowSpacing: 4
                        Rectangle { implicitWidth: win.railCollapsed ? 40 : 28; implicitHeight: 28; radius: 5; color: railMenuM.containsMouse ? Theme.bgHover : "transparent"; Text { anchors.centerIn: parent; text: "󰍜"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } MouseArea { id: railMenuM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.toggleRail() } }
                        Rectangle { readonly property bool canB: Status.canNavBack || win.searchQuery !== ""; implicitWidth: win.railCollapsed ? 40 : 28; implicitHeight: 28; radius: 5; opacity: canB ? 1.0 : 0.38; color: railBackM.containsMouse && canB ? Theme.bgHover : "transparent"; Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: railBackM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canB; cursorShape: Qt.PointingHandCursor; onClicked: win.navBackAction() } }
                        Text { visible: !win.railCollapsed; text: "󰣛"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                        Text { visible: !win.railCollapsed; text: "Settings"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                    }

                    // User Profile Header Card (Click -> Accounts -> Your info / acc-profile)
                    Rectangle {
                        readonly property bool isPrfActive: win.searchQuery === "" && win.activePage === "accounts" && Status.expandedSettingId === "acc-profile"
                        Layout.fillWidth: true; implicitHeight: win.railCollapsed ? 40 : 48; radius: 6; color: isPrfActive ? Theme.bgAlt : (usrM.containsMouse ? Theme.bgHover : "transparent"); border.width: isPrfActive ? 1 : 0; border.color: Theme.blue
                        RowLayout {
                            anchors { fill: parent; leftMargin: win.railCollapsed ? 4 : 8; rightMargin: win.railCollapsed ? 4 : 8 } spacing: 10
                            Rectangle {
                                Layout.alignment: Qt.AlignCenter; implicitWidth: 32; implicitHeight: 32; radius: 16; color: Theme.bgAlt; border.width: 1; border.color: usrM.containsMouse ? Theme.blue : Theme.border; clip: true
                                Image { id: railAvImg; anchors { fill: parent; margins: 1 } source: Status.userAvatar ? ("file://" + Status.userAvatar) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; visible: status === Image.Ready }
                                Text { visible: railAvImg.status !== Image.Ready; anchors.centerIn: parent; text: win.displayUser.slice(0, 1).toUpperCase(); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                            }
                            ColumnLayout { visible: !win.railCollapsed; Layout.fillWidth: true; spacing: 1; Text { text: win.displayUser; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: win.displaySub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight; Layout.fillWidth: true } }
                        }
                        MouseArea { id: usrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.clearSearch(); Status.openSettingsItem("accounts", "acc-profile"); } }
                    }

                    // Compact Search Icon Button (when railCollapsed)
                    Rectangle {
                        visible: win.railCollapsed; Layout.fillWidth: true; implicitHeight: 34; radius: 6; color: srchIconM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "󰍉"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        MouseArea { id: srchIconM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.focusSearch() }
                    }

                    // Windows 11 "Find a setting" Search Box (when expanded)
                    Rectangle {
                        visible: !win.railCollapsed; Layout.fillWidth: true; implicitHeight: 34; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: searchBox.activeFocus ? Theme.blue : Theme.border
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 1; rightMargin: 1 } height: 2; radius: 1; color: searchBox.activeFocus ? Theme.blue : "transparent" }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 } spacing: 6
                            TextInput {
                                id: searchBox; Layout.fillWidth: true; verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                                onTextChanged: win.searchQuery = text
                                Keys.onEscapePressed: { if (searchBox.text !== "") win.clearSearch(); else if (Status.expandedSettingId !== "" || Status.settingsSubPanel !== "") win.navUpAction(); else Status.settingsOpen = false; }
                                Keys.onReturnPressed: { if (win.searchQuery !== "" && pagesView.visibleItems.length > 0) pagesView.openCardPanel(pagesView.visibleItems[0]); }
                                Keys.onDownPressed: { if (searchBox.text === "") win.stepCategory(1); else rootBox.forceActiveFocus(); }
                                Keys.onUpPressed: { if (searchBox.text === "") win.stepCategory(-1); else rootBox.forceActiveFocus(); }
                                Text { visible: searchBox.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Find a setting"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                            }
                            Text { text: searchBox.text !== "" ? "󰅖" : "󰍉"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; MouseArea { anchors.fill: parent; enabled: searchBox.text !== ""; cursorShape: Qt.PointingHandCursor; onClicked: win.clearSearch() } }
                        }
                    }

                    // 12 Clean Navigation Items (Home + 11 Categories) with Left Vertical Accent Indicator
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true; contentWidth: width; contentHeight: catCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: catCol; width: parent.width; spacing: 2
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
                                        anchors { fill: parent; leftMargin: win.railCollapsed ? 0 : 12; rightMargin: win.railCollapsed ? 0 : 8 } spacing: 10
                                        Text { Layout.alignment: win.railCollapsed ? Qt.AlignCenter : Qt.AlignVCenter; Layout.fillWidth: win.railCollapsed; horizontalAlignment: win.railCollapsed ? Text.AlignHCenter : Text.AlignLeft; text: catRow.modelData.icon; color: catRow.isCur ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                        Text { visible: !win.railCollapsed; text: catRow.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: catRow.isCur ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Rectangle { visible: !win.railCollapsed && win.searchQuery !== "" && catRow.matchCount > 0; implicitWidth: 22; implicitHeight: 18; radius: 9; color: Theme.bgHover; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: String(catRow.matchCount); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } }
                                    }
                                    MouseArea { id: catM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory(catRow.modelData.id) }
                                }
                            }
                        }
                    }
                }
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.border; opacity: 0.45 }
            }

            // ================ RIGHT CONTENT PANE (Back/Up Bar + Breadcrumbs + Dedicated Panels) ================
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

                Item {
                    Layout.fillWidth: true; implicitHeight: win.searchQuery === "" && win.activePage === "system" && Status.expandedSettingId === "" ? (win.veryNarrow ? 114 : 132) : 64
                    ColumnLayout {
                        anchors { fill: parent; leftMargin: win.compactWindow ? 16 : 26; rightMargin: win.compactWindow ? 14 : 24; topMargin: 14; bottomMargin: 6 } spacing: 10
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Rectangle { readonly property bool canB: Status.canNavBack || win.searchQuery !== ""; implicitWidth: win.veryNarrow ? 34 : 68; implicitHeight: 30; radius: 5; opacity: canB ? 1.0 : 0.42; color: backBtnM.containsMouse && canB ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: win.veryNarrow ? "󰁍" : "󰁍  Back"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium } MouseArea { id: backBtnM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canB; cursorShape: Qt.PointingHandCursor; onClicked: win.navBackAction() } }
                            Rectangle { readonly property bool canU: Status.canNavUp || win.searchQuery !== ""; implicitWidth: win.veryNarrow ? 34 : 58; implicitHeight: 30; radius: 5; opacity: canU ? 1.0 : 0.42; color: upBtnM.containsMouse && canU ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: win.veryNarrow ? "󰁝" : "󰁝  Up"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium } MouseArea { id: upBtnM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canU; cursorShape: Qt.PointingHandCursor; onClicked: win.navUpAction() } }
                            RowLayout {
                                Layout.fillWidth: true; Layout.leftMargin: 4; spacing: 6
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && win.activePage !== "home" && Status.expandedSettingId === ""; text: "Home"; color: bcHmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Medium; MouseArea { id: bcHmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory("home") } }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && win.activePage !== "home" && Status.expandedSettingId === ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && Status.expandedSettingId !== ""; text: win.currentCatObj.title; color: bcCatM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Medium; MouseArea { id: bcCatM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem(win.activePage, "", "") } }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && Status.expandedSettingId !== ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && Status.expandedSettingId !== "" && Status.settingsSubPanel !== ""; text: pagesView.curItemTitle; color: bcItmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Medium; elide: Text.ElideRight; Layout.maximumWidth: 200; MouseArea { id: bcItmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsSub("") } }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && Status.expandedSettingId !== "" && Status.settingsSubPanel !== ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                Text { text: win.searchQuery !== "" ? ("Search: \"" + win.searchQuery + "\"") : (Status.settingsSubPanel !== "" ? pagesView.curSubTitle : (Status.expandedSettingId !== "" ? pagesView.curItemTitle : win.currentCatObj.title)); color: Theme.fg; font.family: Theme.font; font.pixelSize: Status.expandedSettingId !== "" ? (Theme.fontSize + 4) : (win.veryNarrow ? Theme.fontSize + 4 : Theme.fontSize + 7); font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            Rectangle { implicitWidth: win.veryNarrow ? 36 : 104; implicitHeight: 30; radius: 5; color: qdM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: win.veryNarrow ? "󰚩" : "󰚩  Quick AI"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { id: qdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.settingsOpen = false; Status.toggleSuperDeck("ai"); } } }
                            Rectangle { implicitWidth: 32; implicitHeight: 30; radius: 5; color: clsM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clsM.containsMouse ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: "󰅖"; color: clsM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: clsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.settingsOpen = false } }
                        }

                        // Windows 11 Hero Device Strip (Shown on System top-level page)
                        RowLayout {
                            visible: win.searchQuery === "" && win.activePage === "system" && Status.expandedSettingId === ""; Layout.fillWidth: true; spacing: 16
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Rectangle { implicitWidth: 64; implicitHeight: 40; radius: 6; color: Theme.bgAlt; border.width: 2; border.color: sysMonM.containsMouse ? Theme.cyan : Theme.blue; clip: true; Image { id: sysWpImg; anchors { fill: parent; margins: 2 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false } Text { visible: sysWpImg.status !== Image.Ready; anchors.centerIn: parent; text: "󰍹"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 8 } MouseArea { id: sysMonM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } }
                                ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: win.hostShort; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("system", "sys-storage") } } Text { text: Status.gpuArch + "  ·  " + Theme.themeName + " 󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("personalization", "ui-saver") } } }
                            }
                            RowLayout {
                                visible: win.width >= 760; spacing: 16
                                RowLayout { spacing: 8; Text { text: Status.wifiEnabled ? "󰤨" : "󰈀"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { spacing: 0; Text { text: (Status.ssid || Status.netIface) + " 󰅂"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsItem("network", "net-wifi") } } Text { text: (Status.netType !== "none" && Status.netIpv4 !== "Disconnected") ? "Connected" : "Not connected"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
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
