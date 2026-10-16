import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

// Modern Windows 11 (WinUI 3) Multi-Level Settings Panels: Level 1 Category Cards -> Level 2 Setting Panel -> Level 3 Sub-Panel.
Item {
    id: pg
    property string activePage: "system"; property string searchQuery: ""; property string confirmDanger: ""
    signal clearSearchRequested()
    signal executeCommand(string cmd, bool closeAfter)
    SettingsRegistry { id: reg }
    readonly property var categories: reg.categories
    readonly property string qNorm: pg.searchQuery.trim().toLowerCase()
    readonly property var btList: reg.btAdapter ? Bluetooth.devices.values.slice(0, 8) : []
    readonly property var curItem: reg.itemById(Status.expandedSettingId)
    readonly property string curItemTitle: curItem ? curItem.title : ""
    readonly property string curSubTitle: reg.subPanelTitle(curItem, Status.settingsSubPanel)
    readonly property var curSubPanels: reg.subPanelsFor(curItem)
    readonly property bool inItemPanel: pg.qNorm === "" && pg.curItem !== null && Status.settingsSubPanel === ""
    readonly property bool inSubPanel: pg.qNorm === "" && pg.curItem !== null && Status.settingsSubPanel !== ""
    readonly property bool inListPanel: !pg.inItemPanel && !pg.inSubPanel
    readonly property bool isCompact: pg.width < 560
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
        else if (a.act === "barOpacity") { Theme.barOpacity = Theme.barOpacity < 0.99 ? 1.0 : 0.82; Status.playSfx("toggle"); }
        else if (a.act === "notif") { if (Status.notifAction) Status.notifAction(a.v, ""); } else if (a.act === "banner") { if (Status.notifAction) Status.notifAction("banner", a.v); } else if (a.act === "cast") { if (Status.notifAction) Status.notifAction("cast", a.v); }
        else if (a.act === "clock24") Status.saveClockPrefs(!Status.clock24h, Status.clockSeconds); else if (a.act === "clockSec") Status.saveClockPrefs(Status.clock24h, !Status.clockSeconds);
    }
    function setSlider(kind, ratio) { const v = Math.max(0.0, Math.min(1.0, ratio)); if (kind === "bright") Status.setBrightness(Math.max(0.05, v)); else if (kind === "spk") Status.setSpeakerVolume(v); else if (kind === "mic") Status.setMicVolume(v); }
    function openCardPanel(it) { if (!it) return; const targetCat = it.cats.indexOf(pg.activePage) >= 0 ? pg.activePage : (it.cats[0] || pg.activePage); pg.clearSearchRequested(); Status.openSettingsItem(targetCat, it.id, ""); }
    function actionVerb(a, it) {
        if (!a) return "Open";
        const id = it ? (it.id || "") : "", l = (a.l || "").toLowerCase(), act = a.act || "";
        if (id === "pwr-btrfs" && l.includes("create")) return "Create";
        if (id.indexOf("app-def-") === 0 && !l.startsWith("open ") && !l.startsWith("edit ") && !l.startsWith("reset ")) return a.on ? "󰄬 Default" : "Set default";
        if (a.on || (act === "brightSet" && Math.abs(Status.brightness - Number(a.v)) < 0.06) || (act === "micSet" && Math.abs(Status.micVol - Number(a.v)) < 0.06)) return "󰄬 Selected";
        if (act === "banner" || act === "cast" || l.includes("play") || l.includes("sound") || l.startsWith("test ") || l.includes("toast") || l.includes("preview") || l.includes("print test")) return "Preview";
        if (l.startsWith("edit ") || l.includes(".conf") || l.includes(".toml") || l.includes(".env") || l.includes(".list") || l.includes("clocks")) return "Edit";
        if (l.includes("status") || l.includes("inspect") || l.includes("table") || l.includes("list ") || l.includes("sockets") || l.includes("statistics") || l.includes("health") || l.includes("permissions") || l.includes("detect") || l.includes("probe") || l.includes("verify")) return "Inspect";
        if (act === "cmdClose" || l.startsWith("open ") || l.includes("tui") || l.includes("gui") || l.includes("manager") || l.includes("editor") || l.includes("console") || l.includes("mixer") || l.includes("analyzer") || l.includes("web ") || l.includes("add or manage") || l.includes("shortcuts") || id === "app-defaults") return "Open";
        if (l.includes("scan") || l.includes("rescan") || l.includes("check") || l.includes("firmware")) return "Scan"; if (l.includes("copy")) return "Copy"; if (l.includes("flush")) return "Flush";
        if (l.includes("clear")) return "Clear"; if (l.includes("reset")) return "Reset"; if (l.includes("export")) return "Export"; if (l.includes("import")) return "Import";
        if (l.includes("update ") || l.startsWith("update")) return "Update"; if (l.includes("optimize")) return "Optimize"; if (l.includes("enroll") || l.includes("generate") || l.includes("change password")) return "Configure";
        if (l.includes("zoom")) return "Adjust"; if (l.includes("mute") || l.includes("toggle") || l.includes("lock camera") || l.includes("enable camera") || l.includes("orca") || l.includes("mono") || l.includes("timezone") || act === "barOpacity" || act === "clock24" || act === "clockSec" || act === "kbdLight") return "Toggle";
        if (l.includes("switch") || l.startsWith("next ") || l.startsWith("previous ") || l.includes("cycle")) return "Switch";
        if (id === "disp-bright" || id === "disp-night" || id === "disp-scale" || id === "snd-spk" || id === "snd-mic" || id === "dev-touchpad" || id === "dev-kbd" || id === "ui-mode" || id === "wm-dock" || id === "wm-layout" || id === "acc-fontsize" || id === "acc-motion" || id === "pwr-mode" || id === "pwr-battery" || id === "pwr-idle") return "Select";
        return "Open";
    }
    function actionSub(a, it) {
        if (!a) return "";
        const v = pg.actionVerb(a, it), t = it ? it.title : "setting";
        if (v === "󰄬 Default") return "Active default handler for " + t; if (v === "Set default") return "Set as your default handler for " + t;
        if (v === "󰄬 Selected") return "Currently active selection for " + t; if (v === "Select") return "Switch " + t + " to " + a.l;
        if (v === "Open") return "Launch interactive interface or window"; if (v === "Edit") return "Open configuration file in default editor";
        if (v === "Inspect") return "Inspect live system state and diagnostics"; if (v === "Preview") return "Trigger immediate live preview";
        if (v === "Toggle") return "Toggle setting state immediately"; if (v === "Switch") return "Cycle to the next state";
        return v + " — " + t;
    }

    NumberAnimation { id: panelAnim; target: contentCol; property: "opacity"; from: 0.78; to: 1.0; duration: 95; easing.type: Easing.OutCubic }
    onActivePageChanged: { pg.confirmDanger = ""; flick.contentY = 0; panelAnim.restart(); }
    onSearchQueryChanged: flick.contentY = 0
    Connections { target: Status; function onExpandedSettingIdChanged() { pg.confirmDanger = ""; flick.contentY = 0; panelAnim.restart(); } function onSettingsSubPanelChanged() { pg.confirmDanger = ""; flick.contentY = 0; panelAnim.restart(); } }

    Flickable {
        id: flick; anchors { fill: parent; leftMargin: pg.isCompact ? 16 : 26; rightMargin: pg.isCompact ? 14 : 24; topMargin: 4; bottomMargin: 12 }
        contentWidth: width; contentHeight: contentCol.implicitHeight + 28; clip: true; boundsBehavior: Flickable.DragOverBounds; flickDeceleration: 3500
        ColumnLayout {
            id: contentCol; width: flick.width; spacing: 8
            // ================ VIEW 1: LEVEL-1 CATEGORY CARDS LIST & SEARCH RESULTS ================
            Rectangle { visible: pg.inListPanel && pg.visibleItems.length === 0; Layout.fillWidth: true; implicitHeight: 80; radius: 6; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "No settings found for \"" + pg.searchQuery + "\"."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize } }
            Repeater {
                model: pg.inListPanel ? pg.visibleItems : []
                Rectangle {
                    id: sCard; required property var modelData
                    readonly property bool hasSlider: Boolean(modelData.slider); readonly property bool hasToggle: Boolean(modelData.toggle)
                    readonly property real sVal: hasSlider ? Math.max(0, Math.min(1, reg.sliderVal(modelData.slider))) : 0
                    readonly property bool sMuted: hasSlider && reg.sliderMuted(modelData.slider)
                    Layout.fillWidth: true; implicitHeight: Math.max(66, cardRow.implicitHeight + 18); radius: 6
                    color: hdrM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: hdrM.containsMouse ? Theme.blue : Theme.border; clip: true
                    MouseArea { id: hdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.openCardPanel(sCard.modelData) }
                    RowLayout {
                        id: cardRow; anchors { fill: parent; leftMargin: 16; rightMargin: 14; topMargin: 9; bottomMargin: 9 } spacing: 12
                        Rectangle { visible: sCard.modelData.id === "ui-saver" && Status.currentWallpaper !== ""; implicitWidth: 52; implicitHeight: 32; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.blue; clip: true; Image { anchors { fill: parent; margins: 1 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false } }
                        Text { visible: !(sCard.modelData.id === "ui-saver" && Status.currentWallpaper !== ""); text: sCard.modelData.icon || "󰒓"; color: hdrM.containsMouse ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: sCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: sCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: pg.isCompact ? Text.WordWrap : Text.NoWrap; maximumLineCount: pg.isCompact ? 2 : 1; elide: Text.ElideRight }
                        }
                        RowLayout {
                            visible: sCard.hasSlider; spacing: 8
                            Rectangle {
                                visible: sCard.modelData.slider === "spk" || sCard.modelData.slider === "mic"
                                implicitWidth: 30; implicitHeight: 30; radius: 5; color: muteM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border
                                Text { anchors.centerIn: parent; text: sCard.sMuted ? "󰝟" : "󰕾"; color: sCard.sMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                                MouseArea { id: muteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction({ act: sCard.modelData.slider === "spk" ? "spkMute" : "micMute" }) }
                            }
                            Item {
                                implicitWidth: pg.isCompact ? 84 : 136; implicitHeight: 24
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.bg; border.width: 1; border.color: Theme.border }
                                Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * sCard.sVal); height: 4; radius: 2; color: Theme.blue }
                                Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * sCard.sVal) - 8)); color: Theme.blue; border.width: 3; border.color: Theme.bgAlt }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: mouse => pg.setSlider(sCard.modelData.slider, mouse.x / width); onPositionChanged: mouse => { if (pressed) pg.setSlider(sCard.modelData.slider, mouse.x / width); } }
                            }
                            Text { Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; text: Math.round(sCard.sVal * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        }
                        RowLayout {
                            visible: sCard.hasToggle; spacing: 8
                            Text { visible: !pg.isCompact; text: (sCard.modelData.toggle && sCard.modelData.toggle.on) ? "On" : "Off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                            Rectangle {
                                readonly property bool tOn: Boolean(sCard.modelData.toggle && sCard.modelData.toggle.on)
                                implicitWidth: 42; implicitHeight: 22; radius: 11; color: tOn ? Theme.blue : Theme.bg; border.width: 1; border.color: tOn ? Theme.blue : Theme.muted
                                Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: parent.tOn ? 23 : 4; color: parent.tOn ? Theme.bg : Theme.fgDim; Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.triggerAction(sCard.modelData.toggle) }
                            }
                        }
                        Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 5; color: hdrM.containsMouse ? Theme.bg : "transparent"; Text { anchors.centerIn: parent; text: "󰅂"; color: hdrM.containsMouse ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } }
                    }
                }
            }
            // ================ VIEW 2: LEVEL-2 DEDICATED SETTING PANEL (Full Right Side) ================
            ColumnLayout {
                visible: pg.inItemPanel; Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: heroCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        id: heroCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 12
                        RowLayout {
                            Layout.fillWidth: true; spacing: 14
                            Rectangle { visible: pg.curItem && pg.curItem.id === "ui-saver"; implicitWidth: pg.isCompact ? 96 : 148; implicitHeight: pg.isCompact ? 56 : 86; radius: 6; color: Theme.bg; border.width: 2; border.color: wpHeroM.containsMouse ? Theme.cyan : Theme.blue; clip: true; Image { anchors { fill: parent; margins: 2 } source: Status.currentWallpaper ? ("file://" + Status.currentWallpaper) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false } MouseArea { id: wpHeroM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsSub("wp-gallery") } }
                            Rectangle { visible: !(pg.curItem && pg.curItem.id === "ui-saver"); implicitWidth: 48; implicitHeight: 48; radius: 8; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: pg.curItem ? (pg.curItem.icon || "󰒓") : "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 8 } }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text { text: pg.curItem ? pg.curItem.title : ""; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: pg.curItem ? pg.curItem.sub : ""; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                Text { visible: Boolean(pg.curItem && reg.detailFor(pg.curItem)); text: pg.curItem ? reg.detailFor(pg.curItem) : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                            RowLayout {
                                visible: Boolean(pg.curItem && pg.curItem.toggle); spacing: 10
                                Text { text: (pg.curItem && pg.curItem.toggle && pg.curItem.toggle.on) ? "On" : "Off"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                                Rectangle {
                                    readonly property bool tOn: Boolean(pg.curItem && pg.curItem.toggle && pg.curItem.toggle.on)
                                    implicitWidth: 46; implicitHeight: 24; radius: 12; color: tOn ? Theme.blue : Theme.bg; border.width: 1; border.color: tOn ? Theme.blue : Theme.muted
                                    Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: parent.tOn ? 25 : 4; color: parent.tOn ? Theme.bg : Theme.fgDim; Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } } }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (pg.curItem) pg.triggerAction(pg.curItem.toggle) }
                                }
                            }
                        }
                        RowLayout {
                            visible: Boolean(pg.curItem && pg.curItem.slider); Layout.fillWidth: true; spacing: 12
                            readonly property real hVal: pg.curItem && pg.curItem.slider ? Math.max(0, Math.min(1, reg.sliderVal(pg.curItem.slider))) : 0
                            readonly property bool hMuted: pg.curItem && pg.curItem.slider ? reg.sliderMuted(pg.curItem.slider) : false
                            Rectangle {
                                visible: Boolean(pg.curItem && (pg.curItem.slider === "spk" || pg.curItem.slider === "mic"))
                                implicitWidth: 34; implicitHeight: 32; radius: 5; color: hMuteM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: Theme.border
                                Text { anchors.centerIn: parent; text: parent.parent.hMuted ? "󰝟" : "󰕾"; color: parent.parent.hMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 }
                                MouseArea { id: hMuteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (pg.curItem) pg.triggerAction({ act: pg.curItem.slider === "spk" ? "spkMute" : "micMute" }) }
                            }
                            Text { text: (pg.curItem && pg.curItem.slider === "bright") ? "Luminance" : "Master level"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.preferredWidth: 96 }
                            Item {
                                Layout.fillWidth: true; implicitHeight: 26
                                readonly property real sVal: parent.hVal
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.bg; border.width: 1; border.color: Theme.border }
                                Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: Math.round(parent.width * parent.sVal); height: 6; radius: 3; color: Theme.blue }
                                Rectangle { width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * parent.sVal) - 9)); color: Theme.blue; border.width: 3; border.color: Theme.bgAlt }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: mouse => { if (pg.curItem) pg.setSlider(pg.curItem.slider, mouse.x / width); } onPositionChanged: mouse => { if (pressed && pg.curItem) pg.setSlider(pg.curItem.slider, mouse.x / width); } }
                            }
                            Text { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: Math.round(parent.hVal * 100) + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                        }
                    }
                }

                // 2B. Sub-Panels & Deep Drill-Downs (Level 3 Navigation Cards)
                Text { visible: pg.curSubPanels.length > 0; text: "Sub-panels & deep configuration"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; Layout.topMargin: 4 }
                Repeater {
                    model: pg.inItemPanel ? pg.curSubPanels : []
                    Rectangle {
                        id: subCard; required property var modelData
                        Layout.fillWidth: true; implicitHeight: Math.max(64, subCardRow.implicitHeight + 18); radius: 6; color: subCardM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: subCardM.containsMouse ? Theme.blue : Theme.border
                        MouseArea { id: subCardM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsSub(subCard.modelData.id) }
                        RowLayout {
                            id: subCardRow; anchors { fill: parent; leftMargin: 18; rightMargin: 16; topMargin: 9; bottomMargin: 9 } spacing: 14
                            Rectangle { implicitWidth: 36; implicitHeight: 36; radius: 6; color: Theme.bg; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: subCard.modelData.icon || "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3 } }
                            ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: subCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: subCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: pg.isCompact ? Text.WordWrap : Text.NoWrap; maximumLineCount: pg.isCompact ? 2 : 1; elide: Text.ElideRight } }
                            Rectangle { implicitWidth: pg.isCompact ? 76 : 98; implicitHeight: 28; radius: 5; color: subCardM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: subCardM.containsMouse ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: pg.isCompact ? "Open 󰅂" : "Open panel  󰅂"; color: subCardM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } }
                        }
                    }
                }

                // 2C. Individual Setting Options (Direct selection / execution with contextual verbs)
                Text { visible: Boolean(pg.curItem && pg.curItem.acts && pg.curItem.acts.length > 0); text: "Options & actions"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; Layout.topMargin: 4 }
                Repeater {
                    model: (pg.inItemPanel && pg.curItem && pg.curItem.acts) ? pg.curItem.acts : []
                    Rectangle {
                        id: optCard; required property var modelData; required property int index
                        readonly property bool isOn: Boolean(modelData.on); readonly property bool isDanger: Boolean(modelData.danger); readonly property bool needsConfirm: isDanger && modelData.act !== "banner" && modelData.act !== "cast"
                        readonly property bool armed: needsConfirm && pg.confirmDanger === modelData.l; readonly property string verb: armed ? ("Confirm " + modelData.l + "?") : pg.actionVerb(modelData, pg.curItem)
                        Layout.fillWidth: true; implicitHeight: Math.max(60, optCardRow.implicitHeight + 16); radius: 6; color: optRowM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: (isOn || armed) ? 1.5 : 1; border.color: isDanger ? Theme.red : (isOn ? Theme.blue : (optRowM.containsMouse ? Theme.blue : Theme.border))
                        MouseArea { id: optRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (optCard.needsConfirm && !optCard.armed) { pg.confirmDanger = optCard.modelData.l; Status.playSfx("click"); } else { pg.confirmDanger = ""; pg.triggerAction(optCard.modelData); } } }
                        RowLayout {
                            id: optCardRow; anchors { fill: parent; leftMargin: 18; rightMargin: 16; topMargin: 8; bottomMargin: 8 } spacing: 14
                            Rectangle { implicitWidth: 34; implicitHeight: 34; radius: 6; color: optCard.isOn ? Theme.blue : Theme.bg; border.width: 1; border.color: optCard.isOn ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: optCard.isOn ? "󰄬" : (optCard.isDanger ? "󰀨" : (pg.curItem ? pg.curItem.icon : "󰒓")); color: optCard.isOn ? Theme.bg : (optCard.isDanger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } }
                            ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: optCard.modelData.l; color: optCard.isDanger ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: optCard.armed ? "Click again to confirm immediate hardware power action" : pg.actionSub(optCard.modelData, pg.curItem); color: optCard.armed ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: pg.isCompact ? Text.WordWrap : Text.NoWrap; maximumLineCount: pg.isCompact ? 2 : 1; elide: Text.ElideRight } }
                            Rectangle {
                                implicitWidth: Math.max(88, optBtnTxt.implicitWidth + 24); implicitHeight: 30; radius: 5; color: (optCard.armed || optRowM.containsMouse || optBtnM.containsMouse) ? (optCard.isDanger ? Theme.red : Theme.blue) : (optCard.isOn ? Theme.blue : Theme.bg); border.width: 1; border.color: optCard.isDanger ? Theme.red : (optCard.isOn ? Theme.blue : Theme.border)
                                Text { id: optBtnTxt; anchors.centerIn: parent; text: optCard.verb; color: (optCard.armed || optCard.isOn || optRowM.containsMouse || optBtnM.containsMouse) ? Theme.bg : (optCard.isDanger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                                MouseArea { id: optBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (optCard.needsConfirm && !optCard.armed) { pg.confirmDanger = optCard.modelData.l; Status.playSfx("click"); } else { pg.confirmDanger = ""; pg.triggerAction(optCard.modelData); } } }
                            }
                        }
                    }
                }
            }

            // ================ VIEW 3: LEVEL-3 DEEP SUB-PANEL & INLINE PROFILE EDITOR ================
            LauncherMenu {
                visible: pg.inSubPanel || (pg.inItemPanel && pg.curItem && pg.curItem.id === "acc-profile"); Layout.fillWidth: true
                activeSection: pg.inSubPanel ? Status.settingsSubPanel : (pg.curItem && pg.curItem.id === "acc-profile" ? "usr-edit" : ""); parentItem: pg.curItem; btList: pg.btList
                onTriggerSettingAction: actObj => pg.triggerAction(actObj); onExecuteCommand: (c, cl) => pg.executeCommand(c, cl); onCloseRequested: Status.settingsOpen = false
            }
            Rectangle {
                visible: pg.inSubPanel; Layout.fillWidth: true; implicitHeight: 46; radius: 6; color: retSubM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 16 } spacing: 10; Text { text: "󰁍  Return to " + pg.curItemTitle; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.Medium; Layout.fillWidth: true } Text { text: "Alt + Up"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                MouseArea { id: retSubM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettingsSub("") }
            }
        }
    }
}
