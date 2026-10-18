import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// Modern Windows 11 (WinUI 3 / Fluent) Tiled & Responsive Settings Window: Adaptive Nav Rail + Right Hero & Cards Pane.
FloatingWindow {
    id: win
    title: "SuperSettings"; visible: Status.settingsOpen; implicitWidth: 1120; implicitHeight: 740; minimumSize: Qt.size(420, 420); color: Theme.bg
    readonly property string activePage: Status.normalizeSettingsPage(Status.settingsPage)
    property string searchQuery: ""; property int navMode: 0; property int focusZone: 0; property int headerKbIndex: 0; property int prevFocusZone: 1
    readonly property bool compactWindow: win.width < 860; readonly property bool veryNarrow: win.width < 620
    readonly property bool railCollapsed: win.navMode === 2 || (win.navMode === 0 && win.compactWindow)
    onCompactWindowChanged: win.navMode = 0
    readonly property var categories: pagesView.categories
    readonly property var currentCatObj: { for (const c of win.categories) if (c.id === win.activePage) return c; return win.categories[0] || { id: "home", icon: "󰋜", title: "Home", sub: "" }; }
    readonly property string userShort: String(Status.userAccount || "user").split("@")[0]
    readonly property string displayUser: Status.userFullName || win.userShort; readonly property string displaySub: Status.userEmail || Status.userAccount
    readonly property string hostShort: Status.userDeviceName || Status.hostName
    NumberAnimation { id: openAnim; target: rootBox; property: "opacity"; from: 0.88; to: 1.0; duration: 90; easing.type: Easing.OutCubic }
    function toggleRail() { win.navMode = win.railCollapsed ? 1 : 2; }
    function focusSearch() { if (win.railCollapsed) win.navMode = 1; searchBox.forceActiveFocus(); }
    function clearSearch() { if (win.searchQuery !== "") { win.searchQuery = ""; searchBox.text = ""; } rootBox.forceActiveFocus(); }
    function navBackAction() { if (win.searchQuery !== "") win.clearSearch(); else { rootBox.forceActiveFocus(); Status.navBack(); } }
    function navUpAction() { if (win.searchQuery !== "") win.clearSearch(); else { rootBox.forceActiveFocus(); if (Status.expandedSettingId !== "" && win.activePage !== "home") pagesView.stepUpLevel(); else Status.navUp(); } }
    Connections {
        target: Status
        function onSettingsOpenChanged() { if (Status.settingsOpen) rootBox.forceActiveFocus(); }
        function onSettingsPageChanged() { win.clearSearch(); }
        function onExpandedSettingIdChanged() { win.clearSearch(); if (Status.expandedSettingId !== "") win.focusZone = 1; }
        function onSettingsSubPanelChanged() { win.clearSearch(); if (Status.settingsSubPanel !== "") win.focusZone = 1; }
    }
    onClosed: Status.settingsOpen = false
    onVisibleChanged: { if (!win.visible && Status.settingsOpen) Status.settingsOpen = false; if (win.visible) { win.searchQuery = ""; searchBox.text = ""; win.focusZone = Status.expandedSettingId !== "" ? 1 : 0; openAnim.restart(); Status.refresh(); rootBox.forceActiveFocus(); } }
    function selectCategory(id) { win.clearSearch(); Status.openSettings(id); }
    function stepCategory(delta) { const list = win.categories; if (!list || list.length === 0) return; const idx = list.findIndex(c => c.id === win.activePage); win.selectCategory(list[(Math.max(0, idx) + delta + list.length) % list.length].id); }
    function runCmd(cmd, closeAfter) { const c = String(cmd || ""); Status.applyOptimistic(c); Theme.applyOptimistic(c); if (closeAfter) Status.settingsOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", closeAfter ? c : ("(" + c + "); qs ipc call status refresh >/dev/null 2>&1 || true")]); }

    Rectangle {
        id: rootBox; anchors.fill: parent; color: Theme.bg; focus: true; clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: mouse => { rootBox.forceActiveFocus(); if (mouse.button === Qt.BackButton) win.navBackAction(); } }
        Keys.onPressed: event => {
            const k = event.key, mod = event.modifiers;
            if (k === Qt.Key_Escape) {
                if (pagesView.confirmDanger !== "") pagesView.confirmDanger = ""; else if (win.searchQuery !== "") win.clearSearch();
                else if (Status.expandedSettingId !== "" || Status.settingsSubPanel !== "") win.navUpAction(); else if (win.focusZone !== 0) { win.focusZone = 0; Status.playSfx("click"); } else Status.settingsOpen = false;
                event.accepted = true; return;
            }
            if (k === Qt.Key_Tab || k === Qt.Key_Backtab) { win.focusZone = win.focusZone === 0 ? 1 : (win.focusZone === 1 ? 2 : 0); rootBox.forceActiveFocus(); Status.playSfx("click"); event.accepted = true; return; }
            if ((mod & Qt.AltModifier) && k === Qt.Key_Left) { win.navBackAction(); event.accepted = true; return; }
            if (rootBox.activeFocus && k === Qt.Key_Backspace) { if (win.searchQuery !== "") { win.focusSearch(); searchBox.text = searchBox.text.slice(0, -1); } else win.navBackAction(); event.accepted = true; return; }
            if ((mod & Qt.AltModifier) && k === Qt.Key_Up) { win.navUpAction(); event.accepted = true; return; }
            if (((mod & Qt.ControlModifier) && k === Qt.Key_F) || (rootBox.activeFocus && k === Qt.Key_Slash && !(mod & (Qt.ControlModifier | Qt.AltModifier)))) { win.focusSearch(); event.accepted = true; return; }
            if (k === Qt.Key_F5 || ((mod & Qt.ControlModifier) && k === Qt.Key_R)) { Status.refresh(); Status.playSfx("confirm"); event.accepted = true; return; }
            if ((mod & Qt.AltModifier) && k >= Qt.Key_0 && k <= Qt.Key_9) { const ci = k === Qt.Key_0 ? 10 : (k - Qt.Key_1); if (win.categories[ci]) { win.selectCategory(win.categories[ci].id); win.focusZone = 1; } event.accepted = true; return; }
            if ((mod & Qt.AltModifier) && k === Qt.Key_H) { win.selectCategory("home"); win.focusZone = 1; event.accepted = true; return; }
            if (rootBox.activeFocus && (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_PageUp || k === Qt.Key_PageDown || k === Qt.Key_Home || k === Qt.Key_End || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
                if (win.focusZone === 2) {
                    if (k === Qt.Key_Right) { win.headerKbIndex = 1; Status.playSfx("click"); }
                    else if (k === Qt.Key_Left) { if (win.headerKbIndex === 1) win.headerKbIndex = 0; else win.focusZone = 0; Status.playSfx("click"); }
                    else if (k === Qt.Key_Down) { win.focusZone = win.prevFocusZone; Status.playSfx("click"); }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { if (win.headerKbIndex === 0) win.navBackAction(); else win.navUpAction(); win.focusZone = 1; }
                    event.accepted = true; return;
                }
                if (win.searchQuery !== "") { if (!pagesView.handleKey(event)) { if (k === Qt.Key_Left) win.focusZone = 0; else if (k === Qt.Key_Up) { win.prevFocusZone = 1; win.focusZone = 2; win.headerKbIndex = 0; } } event.accepted = true; return; }
                if (win.focusZone === 0) {
                    if (k === Qt.Key_Up && win.activePage === "home") { win.prevFocusZone = 0; win.focusZone = 2; win.headerKbIndex = 0; Status.playSfx("click"); }
                    else if (k === Qt.Key_Down || k === Qt.Key_Up) win.stepCategory(k === Qt.Key_Down ? 1 : -1);
                    else if (k === Qt.Key_PageDown || k === Qt.Key_PageUp) win.stepCategory(k === Qt.Key_PageDown ? 3 : -3);
                    else if (k === Qt.Key_Home && win.categories.length > 0) win.selectCategory(win.categories[0].id);
                    else if (k === Qt.Key_End && win.categories.length > 0) win.selectCategory(win.categories[win.categories.length - 1].id);
                    else if (k === Qt.Key_Right || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { win.focusZone = 1; Status.playSfx("click"); }
                } else {
                    const targetView = (win.activePage === "home") ? homeView : pagesView;
                    if (!targetView.handleKey(event)) {
                        if (k === Qt.Key_Left) { win.focusZone = 0; Status.playSfx("click"); }
                        else if (k === Qt.Key_Up) { win.prevFocusZone = 1; win.focusZone = 2; win.headerKbIndex = (Status.canNavUp && !Status.canNavBack) ? 1 : 0; Status.playSfx("click"); }
                    }
                }
                event.accepted = true; return;
            }
            if (rootBox.activeFocus && event.text && event.text.length === 1 && event.text.charCodeAt(0) > 32 && k !== Qt.Key_Slash && !(mod & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { win.focusSearch(); searchBox.text += event.text; event.accepted = true; }
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
                        Rectangle { implicitWidth: win.railCollapsed ? 40 : 28; implicitHeight: 28; radius: 5; color: railMenuM.containsMouse ? Theme.bgHover : "transparent"; Text { anchors.centerIn: parent; text: "󰍜"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } MouseArea { id: railMenuM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(win.railCollapsed ? "Expand navigation rail" : "Collapse navigation rail", containsMouse); onClicked: win.toggleRail() } }
                        Rectangle { readonly property bool canB: Status.canNavBack || win.searchQuery !== ""; implicitWidth: win.railCollapsed ? 40 : 28; implicitHeight: 28; radius: 5; opacity: canB ? 1.0 : 0.38; color: railBackM.containsMouse && canB ? Theme.bgHover : "transparent"; Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: railBackM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canB; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Navigate back (Alt + Left / Backspace)", containsMouse); onClicked: win.navBackAction() } }
                        Text { visible: !win.railCollapsed; text: "󰣛"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                        Text { visible: !win.railCollapsed; text: "Settings"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                    }

                    // User Profile Header Card (Click -> User Account page)
                    Rectangle {
                        readonly property bool isPrfActive: win.searchQuery === "" && win.activePage === "accounts"
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
                        MouseArea { id: usrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(win.displayUser + " · Open dedicated User Account page (profile, avatar & shared Keyring SSO)", containsMouse); onClicked: { win.focusZone = 1; win.selectCategory("accounts"); } }
                    }

                    // Compact Search Icon Button (when railCollapsed)
                    Rectangle {
                        visible: win.railCollapsed; Layout.fillWidth: true; implicitHeight: 34; radius: 6; color: srchIconM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: srchIconM.containsMouse ? Theme.blue : Theme.border
                        Text { anchors.centerIn: parent; text: "󰍉"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        MouseArea { id: srchIconM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Find a setting (Ctrl + F)", containsMouse); onClicked: win.focusSearch() }
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
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { win.focusZone = 1; rootBox.forceActiveFocus(); Status.playSfx("click"); event.accepted = true; }
                                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) { if (searchBox.text !== "") { win.focusZone = 1; rootBox.forceActiveFocus(); pagesView.handleKey(event); } else { rootBox.forceActiveFocus(); win.stepCategory(event.key === Qt.Key_Down ? 1 : -1); } event.accepted = true; }
                                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (searchBox.text !== "" && pagesView.visibleItems.length > 0) { win.focusZone = 1; pagesView.openCardPanel(pagesView.visibleItems[pagesView.kbIndex] || pagesView.visibleItems[0]); } else { win.focusZone = 1; rootBox.forceActiveFocus(); } event.accepted = true; }
                                    else if (event.key === Qt.Key_Escape) { if (searchBox.text !== "") win.clearSearch(); else rootBox.forceActiveFocus(); event.accepted = true; }
                                }
                                Text { visible: searchBox.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Find a setting"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                            }
                            Text { text: searchBox.text !== "" ? "󰅖" : "󰍉"; color: srchActM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; MouseArea { id: srchActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(searchBox.text !== "" ? "Clear search (Esc)" : "Focus search box (Ctrl + F)", containsMouse); onClicked: { if (searchBox.text !== "") win.clearSearch(); else win.focusSearch(); } } }
                        }
                    }

                    // 13 Clean Navigation Items (Home + 12 Categories) with Left Vertical Accent Indicator
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true; contentWidth: width; contentHeight: catCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: catCol; width: parent.width; spacing: 2
                            Repeater {
                                model: win.categories
                                Rectangle {
                                    id: catRow; required property var modelData
                                    readonly property bool isCur: win.searchQuery === "" && win.activePage === modelData.id
                                    readonly property bool isKb: isCur && win.focusZone === 0 && !searchBox.activeFocus
                                    readonly property int matchCount: pagesView.matchCountFor(modelData.id, win.searchQuery)
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 6
                                    opacity: (win.searchQuery !== "" && modelData.id !== "home" && matchCount === 0) ? 0.42 : 1.0
                                    color: isCur ? Theme.bgAlt : (catM.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: isKb ? 1.5 : 0; border.color: Theme.cyan
                                    Rectangle { visible: catRow.isCur; width: 3; height: 16; radius: 1.5; anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter } color: catRow.isKb ? Theme.cyan : Theme.blue }
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: win.railCollapsed ? 0 : 10; rightMargin: win.railCollapsed ? 0 : 8 } spacing: 10
                                        Text { Layout.preferredWidth: win.railCollapsed ? 40 : 22; Layout.alignment: Qt.AlignVCenter; horizontalAlignment: Text.AlignHCenter; text: catRow.modelData.icon; color: catRow.isCur ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
                                        Text { visible: !win.railCollapsed; text: catRow.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: catRow.isCur ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Rectangle { visible: !win.railCollapsed && win.searchQuery !== "" && catRow.matchCount > 0; implicitWidth: 22; implicitHeight: 18; radius: 9; color: Theme.bgHover; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: String(catRow.matchCount); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } }
                                    }
                                    MouseArea { id: catM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(catRow.modelData.title + (catRow.modelData.sub ? (" — " + catRow.modelData.sub) : ""), containsMouse); onClicked: { win.focusZone = 0; win.selectCategory(catRow.modelData.id); } }
                                }
                            }
                        }
                    }
                }
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.border; opacity: 0.45 }
            }

            // ================ RIGHT CONTENT PANE (Back/Up Bar + Breadcrumbs + Dedicated Panels + Docked Context Footer) ================
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

                Item {
                    Layout.fillWidth: true; implicitHeight: win.searchQuery === "" && win.activePage === "system" && Status.expandedSettingId === "" ? (win.veryNarrow ? 114 : 132) : 64
                    ColumnLayout {
                        anchors { fill: parent; leftMargin: win.compactWindow ? 16 : 26; rightMargin: win.compactWindow ? 14 : 24; topMargin: 14; bottomMargin: 6 } spacing: 10
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Rectangle { readonly property bool canB: Status.canNavBack || win.searchQuery !== ""; readonly property bool isKb: win.focusZone === 2 && win.headerKbIndex === 0; implicitWidth: win.veryNarrow ? 34 : Math.max(68, backTxt.implicitWidth + 20); implicitHeight: 30; radius: 5; opacity: (canB || isKb) ? 1.0 : 0.42; color: ((backBtnM.containsMouse && canB) || isKb) ? Theme.bgHover : Theme.bgAlt; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (backBtnM.containsMouse && canB ? Theme.blue : Theme.border); Text { id: backTxt; anchors.centerIn: parent; text: win.veryNarrow ? "󰁍" : "󰁍  Back"; color: parent.isKb ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: parent.isKb ? Font.DemiBold : Font.Medium } MouseArea { id: backBtnM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canB; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Step backward in settings history (Alt + Left / Backspace)", containsMouse); onClicked: win.navBackAction() } }
                            Rectangle { readonly property bool canU: Status.canNavUp || win.searchQuery !== ""; readonly property bool isKb: win.focusZone === 2 && win.headerKbIndex === 1; implicitWidth: win.veryNarrow ? 34 : Math.max(58, upTxt.implicitWidth + 20); implicitHeight: 30; radius: 5; opacity: (canU || isKb) ? 1.0 : 0.42; color: ((upBtnM.containsMouse && canU) || isKb) ? Theme.bgHover : Theme.bgAlt; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (upBtnM.containsMouse && canU ? Theme.blue : Theme.border); Text { id: upTxt; anchors.centerIn: parent; text: win.veryNarrow ? "󰁝" : "󰁝  Up"; color: parent.isKb ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: parent.isKb ? Font.DemiBold : Font.Medium } MouseArea { id: upBtnM; anchors.fill: parent; hoverEnabled: true; enabled: parent.canU; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Go up one level (Alt + Up / Left Arrow / Esc)", containsMouse); onClicked: win.navUpAction() } }
                            RowLayout {
                                Layout.fillWidth: true; Layout.leftMargin: 4; spacing: 6
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && win.activePage !== "home" && Status.expandedSettingId === ""; text: "Home"; color: bcHmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Medium; MouseArea { id: bcHmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Return to Settings Home dashboard", containsMouse); onClicked: win.selectCategory("home") } }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && win.activePage !== "home" && Status.expandedSettingId === ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && Status.expandedSettingId !== ""; text: win.currentCatObj.title; color: bcCatM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Medium; MouseArea { id: bcCatM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Return to " + win.currentCatObj.title + " category", containsMouse); onClicked: Status.openSettingsItem(win.activePage, "", "") } }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && Status.expandedSettingId !== ""; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && pagesView.inChildLevel; text: Status.settingsSubPanel !== "" ? pagesView.curItemTitle : (pagesView.parentItem ? pagesView.parentItem.title : ""); color: bcItmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4; font.weight: Font.Medium; elide: Text.ElideRight; Layout.maximumWidth: 200; MouseArea { id: bcItmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Return to parent setting", containsMouse); onClicked: pagesView.stepUpLevel() } }
                                Text { visible: !win.veryNarrow && win.searchQuery === "" && pagesView.inChildLevel; text: "󰅂"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                Text { text: win.searchQuery !== "" ? ("Search: \"" + win.searchQuery + "\"") : (Status.settingsSubPanel !== "" ? pagesView.curSubTitle : (Status.expandedSettingId !== "" ? pagesView.curItemTitle : win.currentCatObj.title)); color: Theme.fg; font.family: Theme.font; font.pixelSize: Status.expandedSettingId !== "" ? (Theme.fontSize + 4) : (win.veryNarrow ? Theme.fontSize + 4 : Theme.fontSize + 7); font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            Rectangle { visible: !win.veryNarrow; readonly property int lvl: win.searchQuery !== "" ? 0 : (pagesView.inChildLevel ? 3 : (Status.expandedSettingId !== "" ? 2 : 1)); implicitWidth: lvlTxt.implicitWidth + 18; implicitHeight: 26; radius: 13; color: lvl === 3 ? Theme.cyan : (lvl === 2 ? Theme.blue : Theme.bgAlt); border.width: 1; border.color: lvl >= 2 ? "transparent" : Theme.blue; Text { id: lvlTxt; anchors.centerIn: parent; text: parent.lvl === 0 ? "󰍉 SEARCH" : (parent.lvl === 3 ? "󰙅 L3 · SUB-PANEL" : (parent.lvl === 2 ? "󰒓 L2 · SETTING" : ("󰕮 L1 · " + (win.activePage === "home" ? "HOME" : "CATEGORY")))); color: parent.lvl >= 2 ? Theme.bg : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.weight: Font.Bold } MouseArea { anchors.fill: parent; enabled: parent.lvl >= 2; cursorShape: parent.lvl >= 2 ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: win.navUpAction() } }
                            Rectangle { implicitWidth: 32; implicitHeight: 30; radius: 5; color: clsM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clsM.containsMouse ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: "󰅖"; color: clsM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: clsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Close SuperSettings (Esc)", containsMouse); onClicked: Status.settingsOpen = false } }
                        }

                        // Windows 11 Hero Device Strip (Shown on System top-level page)
                        RowLayout {
                            visible: win.searchQuery === "" && win.activePage === "system" && Status.expandedSettingId === ""; Layout.fillWidth: true; spacing: 16
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Rectangle { implicitWidth: 64; implicitHeight: 40; radius: 6; color: Theme.bgAlt; border.width: 2; border.color: sysMonM.containsMouse ? Theme.cyan : Theme.blue; clip: true; Image { id: sysWpImg; anchors { fill: parent; margins: 2 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false } Text { visible: sysWpImg.status !== Image.Ready; anchors.centerIn: parent; text: "󰍹"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 8 } MouseArea { id: sysMonM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open display & monitor settings", containsMouse); onClicked: Status.openSettingsItem("system", "disp-bright") } }
                                ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: win.hostShort; color: sysHostM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { id: sysHostM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Inspect storage, hardware & workstation specs", containsMouse); onClicked: Status.openSettingsItem("system", "sys-about") } } Text { text: Status.gpuArch + "  ·  " + Theme.themeName + " 󰅂"; color: sysThmM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight; Layout.fillWidth: true; MouseArea { id: sysThmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Inspect GPU architecture, VA-API & DMABUF", containsMouse); onClicked: Status.openSettingsItem("system", "sys-gpu") } } }
                            }
                            RowLayout {
                                visible: win.width >= 760; spacing: 16
                                RowLayout { spacing: 8; Text { Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter; text: Status.wifiEnabled ? "󰤨" : "󰈀"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { spacing: 0; Text { text: (Status.ssid || Status.netIface) + " 󰅂"; color: sysNetM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; MouseArea { id: sysNetM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Wi-Fi & Network settings", containsMouse); onClicked: Status.openSettingsItem("network", "net-wifi") } } Text { text: (Status.netType !== "none" && Status.netIpv4 !== "Disconnected") ? "Connected" : "Not connected"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                RowLayout { spacing: 8; Text { Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter; text: "󰓅"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } ColumnLayout { spacing: 0; Text { text: "Power mode 󰅂"; color: sysPwrM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold; MouseArea { id: sysPwrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open Power mode & CPU profile", containsMouse); onClicked: Status.openSettingsItem("system", "pwr-mode") } } Text { text: Status.workstationMode; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                            }
                        }
                    }
                }

                SettingsHome {
                    id: homeView
                    visible: win.searchQuery === "" && win.activePage === "home"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    hostShort: win.hostShort; paneFocused: win.focusZone === 1
                    onSelectCategory: catId => win.selectCategory(catId)
                    onExecuteCommand: (cmd, closeAfter) => win.runCmd(cmd, closeAfter)
                }

                SettingsPages {
                    id: pagesView
                    visible: win.searchQuery !== "" || win.activePage !== "home"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    activePage: win.activePage; searchQuery: win.searchQuery; paneFocused: win.focusZone === 1
                    onClearSearchRequested: win.clearSearch()
                    onExecuteCommand: (cmd, closeAfter) => win.runCmd(cmd, closeAfter)
                    onRequestFocus: { win.focusZone = 1; rootBox.forceActiveFocus(); }
                }

                // Docked Contextual Status Footer Bar (Displays live hover or keyboard-highlighted item details)
                Rectangle {
                    id: statusFooter
                    readonly property string activeText: Status.settingsHoverTip !== "" ? Status.settingsHoverTip : (win.focusZone === 2 ? (win.headerKbIndex === 0 ? "Navigate back in settings history — Press Enter/Space to go back, Right for Up button, Down for page" : "Go up one level in settings hierarchy — Press Enter/Space to go up, Left for Back button, Down for page") : (win.focusZone === 0 ? (win.currentCatObj.title + " — " + (win.currentCatObj.sub || "Overview, quick controls & recent settings")) : ((win.searchQuery === "" && win.activePage === "home") ? homeView.kbTip : pagesView.kbTip)))
                    Layout.fillWidth: true; implicitHeight: 28; color: Theme.bgAlt
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.border; opacity: 0.55 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: win.compactWindow ? 16 : 26; rightMargin: win.compactWindow ? 14 : 24 } spacing: 10
                        Text { Layout.preferredWidth: 16; horizontalAlignment: Text.AlignHCenter; text: "󰋼"; color: Status.settingsHoverTip !== "" ? Theme.cyan : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        Text { Layout.fillWidth: true; text: statusFooter.activeText || (win.currentCatObj.title + " settings"); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight }
                        Text { visible: !win.compactWindow; text: "Tab: Pane  ·  Arrows: Navigate / Drill  ·  Enter/Space: Select  ·  Esc: Up/Back"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4 }
                    }
                }
            }
        }
    }
}
