import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

// Modern Windows 11 (WinUI 3) Expandable Settings Cards Pane: Click any card to expand all connected options inline.
Item {
    id: pg
    property string activePage: "system"; property string searchQuery: ""; property string wifiPassSsid: ""
    signal executeCommand(string cmd, bool closeAfter)
    SettingsRegistry { id: reg }
    readonly property var categories: reg.categories
    readonly property string qNorm: pg.searchQuery.trim().toLowerCase()
    readonly property var btList: reg.btAdapter ? Bluetooth.devices.values.slice(0, 8) : []
    function matchCountFor(catId, qStr) { return reg.matchCountFor(catId, qStr); }
    readonly property var visibleItems: pg.qNorm !== "" ? reg.items.filter(it => reg.matchesQuery(it, pg.qNorm)) : reg.items.filter(it => it.cats.indexOf(pg.activePage) >= 0)

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
    function setSlider(kind, ratio) { const v = Math.max(0.0, Math.min(1.0, ratio)); if (kind === "bright") Status.setBrightness(Math.max(0.05, v)); else if (kind === "spk") Status.setSpeakerVolume(v); else if (kind === "mic") Status.setMicVolume(v); }
    function wifiTrigger(w) {
        if (!w) return; const s = reg.escSh(w.ssid);
        if (w.active) pg.executeCommand("nmcli connection down '" + s + "'; sleep 0.5 && qs ipc call status refresh", false);
        else if (w.saved || w.open) pg.executeCommand("nmcli device wifi connect '" + s + "'; sleep 0.8 && qs ipc call status refresh", false);
        else { pg.wifiPassSsid = w.ssid; Status.playSfx("click"); }
    }
    function submitWifiPass(txt) { if (!pg.wifiPassSsid) return; const s = reg.escSh(pg.wifiPassSsid), p = reg.escSh(txt); pg.wifiPassSsid = ""; pg.executeCommand("nmcli device wifi connect '" + s + "' password '" + p + "'; sleep 0.9 && qs ipc call status refresh", false); }
    onActivePageChanged: flick.contentY = 0
    onSearchQueryChanged: flick.contentY = 0

    Flickable {
        id: flick; anchors { fill: parent; leftMargin: 28; rightMargin: 24; topMargin: 4; bottomMargin: 12 }
        contentWidth: width; contentHeight: contentCol.implicitHeight + 24; clip: true; boundsBehavior: Flickable.DragOverBounds; flickDeceleration: 3500
        ColumnLayout {
            id: contentCol; width: flick.width; spacing: 6
            Rectangle { visible: pg.visibleItems.length === 0; Layout.fillWidth: true; implicitHeight: 80; radius: 6; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "No settings found for \"" + pg.searchQuery + "\"."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize } }

            Repeater {
                model: pg.visibleItems
                Rectangle {
                    id: sCard; required property var modelData
                    readonly property bool hasSlider: Boolean(modelData.slider); readonly property bool hasToggle: Boolean(modelData.toggle)
                    readonly property string drawerKind: String(modelData.drawer || "")
                    readonly property bool isExpanded: Status.expandedSettingId === modelData.id || (pg.qNorm !== "" && pg.visibleItems.length === 1)
                    Layout.fillWidth: true; implicitHeight: cardCol.implicitHeight; radius: 6
                    color: Theme.bgAlt; border.width: isExpanded ? 1.5 : 1; border.color: isExpanded ? Theme.blue : (hdrM.containsMouse ? Theme.muted : Theme.border); clip: true

                    ColumnLayout {
                        id: cardCol; width: parent.width; spacing: 0

                        // -------- CARD HEADER (Always Visible — Click Anywhere to Expand/Collapse) --------
                        Item {
                            Layout.fillWidth: true; implicitHeight: Math.max(64, cardRow.implicitHeight + 18)
                            MouseArea { id: hdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.expandedSettingId = sCard.isExpanded ? "" : sCard.modelData.id; Status.playSfx("click"); } }
                            RowLayout {
                                id: cardRow; anchors { fill: parent; leftMargin: 18; rightMargin: 16; topMargin: 9; bottomMargin: 9 } spacing: 14
                                Rectangle {
                                    visible: sCard.modelData.id === "ui-saver" && Status.currentWallpaper !== ""
                                    implicitWidth: 52; implicitHeight: 32; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.blue; clip: true
                                    Image { anchors { fill: parent; margins: 1 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false }
                                }
                                Text { visible: !(sCard.modelData.id === "ui-saver" && Status.currentWallpaper !== ""); text: sCard.modelData.icon || "󰒓"; color: sCard.isExpanded ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4 }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: sCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: sCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                RowLayout {
                                    visible: sCard.hasSlider; spacing: 10
                                    Rectangle {
                                        visible: sCard.modelData.slider === "spk" || sCard.modelData.slider === "mic"
                                        implicitWidth: 30; implicitHeight: 30; radius: 5; color: muteM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border
                                        Text { anchors.centerIn: parent; text: sCard.modelData.muted ? "󰝟" : "󰕾"; color: sCard.modelData.muted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                                        MouseArea { id: muteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction({ act: sCard.modelData.slider === "spk" ? "spkMute" : "micMute" }) }
                                    }
                                    Item {
                                        implicitWidth: 148; implicitHeight: 24
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.bg; border.width: 1; border.color: Theme.border }
                                        Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * Math.max(0, Math.min(1, Number(sCard.modelData.val || 0)))); height: 4; radius: 2; color: Theme.blue }
                                        Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * Number(sCard.modelData.val || 0)) - 8)); color: Theme.blue; border.width: 3; border.color: Theme.bgAlt }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: mouse => pg.setSlider(sCard.modelData.slider, mouse.x / width); onPositionChanged: mouse => { if (pressed) pg.setSlider(sCard.modelData.slider, mouse.x / width); } }
                                    }
                                    Text { Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; text: Math.round(Number(sCard.modelData.val || 0) * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                                }
                                RowLayout {
                                    visible: !sCard.isExpanded && !sCard.hasSlider && !sCard.hasToggle; spacing: 6
                                    Repeater {
                                        model: (sCard.modelData.acts || []).slice(0, 2)
                                        Rectangle {
                                            id: qActBtn; required property var modelData
                                            readonly property bool isOn: Boolean(modelData.on); readonly property bool isDanger: Boolean(modelData.danger)
                                            implicitWidth: Math.max(68, qActTxt.implicitWidth + 20); implicitHeight: 28; radius: 5
                                            color: qActM.containsMouse ? (isDanger ? Theme.red : (isOn ? Theme.blue : Theme.bgHover)) : (isOn ? Theme.blue : Theme.bg)
                                            border.width: 1; border.color: isDanger ? Theme.red : (isOn ? Theme.blue : Theme.border)
                                            Text { id: qActTxt; anchors.centerIn: parent; text: qActBtn.modelData.l; color: (qActBtn.isOn || (qActM.containsMouse && qActBtn.isDanger)) ? Theme.bg : (qActBtn.isDanger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: qActBtn.isOn ? Font.DemiBold : Font.Normal }
                                            MouseArea { id: qActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction(qActBtn.modelData) }
                                        }
                                    }
                                }
                                RowLayout {
                                    visible: sCard.hasToggle; spacing: 10
                                    Text { text: (sCard.modelData.toggle && sCard.modelData.toggle.on) ? "On" : "Off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                                    Rectangle {
                                        readonly property bool tOn: Boolean(sCard.modelData.toggle && sCard.modelData.toggle.on)
                                        implicitWidth: 42; implicitHeight: 22; radius: 11; color: tOn ? Theme.blue : Theme.bg; border.width: 1; border.color: tOn ? Theme.blue : Theme.muted
                                        Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: parent.tOn ? 23 : 4; color: parent.tOn ? Theme.bg : Theme.fgDim; Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } } }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction(sCard.modelData.toggle) }
                                    }
                                }
                                Rectangle {
                                    implicitWidth: 28; implicitHeight: 28; radius: 5; color: hdrM.containsMouse ? Theme.bgHover : "transparent"
                                    Text { anchors.centerIn: parent; text: sCard.isExpanded ? "󰅃" : "󰅀"; color: sCard.isExpanded ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                }
                            }
                        }

                        // -------- EXPANDED DRAWER (Windows 11 WinUI 3 Expander Body) --------
                        Rectangle {
                            visible: sCard.isExpanded; Layout.fillWidth: true; implicitHeight: expCol.implicitHeight + 24; color: Theme.bg
                            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Theme.border }
                            ColumnLayout {
                                id: expCol; anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 12 } spacing: 10
                                Text { visible: Boolean(sCard.modelData.detail); text: sCard.modelData.detail || ""; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                Flow {
                                    visible: (sCard.modelData.acts || []).length > 0; Layout.fillWidth: true; spacing: 8
                                    Repeater {
                                        model: sCard.modelData.acts || []
                                        Rectangle {
                                            id: actBtn; required property var modelData
                                            readonly property bool isOn: Boolean(modelData.on); readonly property bool isDanger: Boolean(modelData.danger)
                                            implicitWidth: Math.max(82, actTxt.implicitWidth + 24); implicitHeight: 32; radius: 5
                                            color: actM.containsMouse ? (isDanger ? Theme.red : (isOn ? Theme.blue : Theme.bgHover)) : (isOn ? Theme.blue : Theme.bgAlt)
                                            border.width: 1; border.color: isDanger ? Theme.red : (isOn ? Theme.blue : Theme.border)
                                            Text { id: actTxt; anchors.centerIn: parent; text: actBtn.modelData.l; color: (actBtn.isOn || (actM.containsMouse && actBtn.isDanger)) ? Theme.bg : (actBtn.isDanger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: actBtn.isOn ? Font.DemiBold : Font.Normal }
                                            MouseArea { id: actM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction(actBtn.modelData) }
                                        }
                                    }
                                }
                                ColumnLayout {
                                    visible: sCard.drawerKind === "audio-sinks" || sCard.drawerKind === "audio-sources"; Layout.fillWidth: true; spacing: 4
                                    Text { text: sCard.drawerKind === "audio-sinks" ? "Select output speaker / headphones:" : "Select input microphone:"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                                    Repeater {
                                        model: sCard.drawerKind === "audio-sinks" ? Status.audioSinks : Status.audioSources
                                        Rectangle {
                                            id: aDev; required property var modelData; Layout.fillWidth: true; implicitHeight: 34; radius: 5; color: modelData.active ? Theme.blue : (aDevM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: modelData.active ? Theme.blue : Theme.border
                                            Text { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: Text.AlignVCenter; text: (aDev.modelData.active ? "●  " : "○  ") + aDev.modelData.name; color: aDev.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: aDev.modelData.active ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
                                            MouseArea { id: aDevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(aDev.modelData.id) }
                                        }
                                    }
                                }
                                ColumnLayout {
                                    visible: sCard.drawerKind === "bt"; Layout.fillWidth: true; spacing: 6
                                    Text { visible: pg.btList.length === 0; text: "No Bluetooth devices paired yet. Click Scan nearby above."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                                    Repeater {
                                        model: pg.btList
                                        Rectangle {
                                            id: btItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 38; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: modelData.connected ? Theme.blue : Theme.border
                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                                Text { text: "󰂯  " + (btItem.modelData.name || "Unknown") + (btItem.modelData.connected ? "  ·  Connected" : ""); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.fillWidth: true; elide: Text.ElideRight }
                                                Rectangle { implicitWidth: 92; implicitHeight: 26; radius: 5; color: btItem.modelData.connected ? Theme.bg : Theme.blue; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: btItem.modelData.connected ? "Disconnect" : "Connect"; color: btItem.modelData.connected ? Theme.fg : Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(btItem.modelData.connected ? ("bluetoothctl disconnect " + btItem.modelData.address) : ("bluetoothctl connect " + btItem.modelData.address), false) } }
                                                Rectangle { visible: btItem.modelData.paired; implicitWidth: 72; implicitHeight: 26; radius: 5; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Remove"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("bluetoothctl remove " + btItem.modelData.address, false) } }
                                            }
                                        }
                                    }
                                }
                                ColumnLayout {
                                    visible: sCard.drawerKind === "wifi"; Layout.fillWidth: true; spacing: 6
                                    RowLayout {
                                        visible: pg.wifiPassSsid !== ""; Layout.fillWidth: true; spacing: 8
                                        Text { text: "Password for " + pg.wifiPassSsid + ":"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                                        Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: Theme.blue; TextInput { id: wifiPassIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; echoMode: TextInput.Password; clip: true; Keys.onReturnPressed: { pg.submitWifiPass(wifiPassIn.text); wifiPassIn.text = ""; } } }
                                        Rectangle { implicitWidth: 88; implicitHeight: 32; radius: 5; color: Theme.blue; Text { anchors.centerIn: parent; text: "Connect"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { pg.submitWifiPass(wifiPassIn.text); wifiPassIn.text = ""; } } }
                                    }
                                    Repeater {
                                        model: Status.wifiList
                                        Rectangle {
                                            id: wRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 36; radius: 5; color: modelData.active ? Theme.bgAlt : (wRowM.containsMouse ? Theme.bgHover : Theme.bgAlt); border.width: 1; border.color: modelData.active ? Theme.blue : Theme.border
                                            MouseArea { id: wRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.wifiTrigger(wRow.modelData) }
                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                                Text { text: "󰤨  " + wRow.modelData.ssid + (wRow.modelData.active ? "  ·  Connected" : ""); color: wRow.modelData.active ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: wRow.modelData.active ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                                                Text { text: wRow.modelData.security + " · " + wRow.modelData.signal + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                                                Rectangle { implicitWidth: 88; implicitHeight: 26; radius: 5; color: wRow.modelData.active ? Theme.bg : Theme.blue; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: wRow.modelData.active ? "Disconnect" : "Connect"; color: wRow.modelData.active ? Theme.fg : Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                                            }
                                        }
                                    }
                                }
                                ColumnLayout {
                                    visible: sCard.drawerKind === "ai"; Layout.fillWidth: true; spacing: 8
                                    Repeater {
                                        model: sCard.modelData.id === "ai-cluster" ? Status.llmServers : []
                                        Rectangle {
                                            id: srvRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 36; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: modelData.active ? Theme.blue : Theme.border
                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 8
                                                Text { text: (srvRow.modelData.active ? "●  " : "○  ") + srvRow.modelData.name + "  ·  " + srvRow.modelData.host + "  (" + srvRow.modelData.model + ")"; color: srvRow.modelData.active ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: srvRow.modelData.active ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                                                Rectangle { implicitWidth: 84; implicitHeight: 26; radius: 4; color: srvRow.modelData.active ? Theme.bg : Theme.blue; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: srvRow.modelData.active ? "Connected" : "Connect"; color: srvRow.modelData.active ? Theme.fg : Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.connectLlmServer(srvRow.modelData.host, srvRow.modelData.model) } }
                                                Rectangle { implicitWidth: 64; implicitHeight: 26; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "Remove"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeLlmServer(srvRow.modelData.host) } }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        visible: sCard.modelData.id === "ai-cluster"; Layout.fillWidth: true; spacing: 6
                                        Rectangle { Layout.preferredWidth: 150; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: srvNameIn.activeFocus ? Theme.blue : Theme.border; TextInput { id: srvNameIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; Text { visible: srvNameIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Node name (GPU-01)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                        Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: srvHostIn.activeFocus ? Theme.blue : Theme.border; TextInput { id: srvHostIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; Text { visible: srvHostIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Host:Port (10.0.0.21:11434)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                        Rectangle { Layout.preferredWidth: 145; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: srvModIn.activeFocus ? Theme.blue : Theme.border; TextInput { id: srvModIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; Text { visible: srvModIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Model (qwen2.5:32b)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                        Rectangle { implicitWidth: 108; implicitHeight: 32; radius: 5; color: Theme.blue; Text { anchors.centerIn: parent; text: "Add GPU node"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (srvHostIn.text.trim()) { Status.saveLlmServer(srvNameIn.text, srvHostIn.text, "ollama", srvModIn.text || "llama3.2"); srvNameIn.text = ""; srvHostIn.text = ""; srvModIn.text = ""; } } } }
                                    }
                                    Flow {
                                        visible: sCard.modelData.id === "ai-harness"; Layout.fillWidth: true; spacing: 6
                                        Repeater {
                                            model: Status.aiHarnesses
                                            Rectangle {
                                                id: agBtn; required property var modelData; implicitWidth: Math.max(96, agRow.implicitWidth + 20); implicitHeight: 30; radius: 5; color: modelData.active ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: modelData.active ? Theme.blue : Theme.border
                                                RowLayout { id: agRow; anchors.centerIn: parent; spacing: 6; Text { text: (agBtn.modelData.active ? "● " : "") + agBtn.modelData.label; color: agBtn.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: agBtn.modelData.active ? Font.DemiBold : Font.Normal } }
                                                MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor; onClicked: mouse => { if (mouse.button === Qt.RightButton && agBtn.modelData.cat === "custom") Status.removeCustomHarness(agBtn.modelData.id); else Status.selectAiAgent(agBtn.modelData.id); } }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        visible: sCard.modelData.id === "ai-harness"; Layout.fillWidth: true; spacing: 6
                                        Rectangle { Layout.preferredWidth: 120; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: hIdIn.activeFocus ? Theme.blue : Theme.border; TextInput { id: hIdIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; Text { visible: hIdIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "ID (openclaw)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                        Rectangle { Layout.preferredWidth: 150; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: hLblIn.activeFocus ? Theme.blue : Theme.border; TextInput { id: hLblIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; Text { visible: hLblIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Label (OpenClaw)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                        Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: 5; color: Theme.bgAlt; border.width: 1; border.color: hCmdIn.activeFocus ? Theme.blue : Theme.border; TextInput { id: hCmdIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true; Text { visible: hCmdIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Command (openclaw --server http://gpu-srv-1:11434)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } }
                                        Rectangle { implicitWidth: 108; implicitHeight: 32; radius: 5; color: Theme.blue; Text { anchors.centerIn: parent; text: "Add harness"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (hIdIn.text.trim() && hCmdIn.text.trim()) { Status.addCustomHarness(hIdIn.text, hLblIn.text || hIdIn.text, hCmdIn.text); hIdIn.text = ""; hLblIn.text = ""; hCmdIn.text = ""; } } } }
                                    }
                                }
                                LauncherMenu {
                                    visible: sCard.drawerKind === "wallpaper" || sCard.drawerKind === "theme" || sCard.drawerKind === "shell" || sCard.drawerKind === "forge" || sCard.drawerKind === "storage"
                                    Layout.fillWidth: true; activeSection: sCard.drawerKind
                                    onExecuteCommand: (c, cl) => pg.executeCommand(c, cl); onCloseRequested: Status.settingsOpen = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
