import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

// Modern Windows 11 (WinUI 3) Multi-Level Settings Panels: Level 1 Category Cards -> Level 2 Setting Panel -> Level 3 Sub-Panel.
Item {
    id: pg
    property string activePage: "system"; property string searchQuery: ""; property string confirmDanger: ""; property bool paneFocused: false; property int kbIndex: 0
    signal clearSearchRequested(); signal executeCommand(string cmd, bool closeAfter); signal requestFocus()
    SettingsRegistry { id: reg }
    readonly property var categories: reg.categories; readonly property string qNorm: pg.searchQuery.trim().toLowerCase()
    readonly property var btList: reg.btAdapter ? Bluetooth.devices.values.slice(0, 8) : []; readonly property var curItem: reg.itemById(Status.expandedSettingId)
    readonly property var parentItem: (pg.curItem && pg.curItem.parent && pg.curItem.cats.indexOf(pg.activePage) < 0) ? reg.itemById(pg.curItem.parent) : null
    readonly property string curItemTitle: curItem ? curItem.title : ""; readonly property string curSubTitle: reg.subPanelTitle(curItem, Status.settingsSubPanel)
    readonly property var curSubPanels: reg.subPanelsFor(curItem); readonly property bool isCompact: pg.width < 560
    readonly property bool inItemPanel: pg.qNorm === "" && pg.curItem !== null && Status.settingsSubPanel === ""
    readonly property bool inSubPanel: pg.qNorm === "" && pg.curItem !== null && Status.settingsSubPanel !== ""; readonly property bool inListPanel: !pg.inItemPanel && !pg.inSubPanel; readonly property bool inChildLevel: pg.inSubPanel || (pg.inItemPanel && pg.parentItem !== null)
    function matchCountFor(catId, qStr) { return reg.matchCountFor(catId, qStr); }
    readonly property var visibleItems: pg.qNorm !== "" ? reg.items.filter(it => reg.matchesQuery(it, pg.qNorm)) : reg.items.filter(it => it.cats.indexOf(pg.activePage) >= 0)
    readonly property int subCount: (pg.inItemPanel && (pg.curSubPanels.length > 1 || (pg.curSubPanels.length === 1 && Boolean(pg.curSubPanels[0].isChildItem)))) ? pg.curSubPanels.length : 0
    readonly property int optCount: (pg.inItemPanel && pg.curItem && pg.curItem.acts) ? pg.curItem.acts.length : 0
    readonly property int heroCount: (pg.inItemPanel && pg.curItem && (pg.curItem.slider || pg.curItem.toggle)) ? 1 : 0; readonly property bool isHeroKb: pg.paneFocused && pg.heroCount === 1 && pg.kbIndex === 0
    readonly property int optBase: pg.heroCount + pg.subCount; readonly property int lnBase: pg.heroCount + pg.subCount + pg.optCount
    readonly property int totalKbCount: pg.inListPanel ? pg.visibleItems.length : (pg.lnBase + (inlineLauncher.visible ? inlineLauncher.kbCount : 0) + (pg.inChildLevel ? 1 : 0))
    readonly property string kbTip: {
        if (pg.inListPanel) { const it = pg.visibleItems[pg.kbIndex]; return it ? (it.title + " — " + it.sub) : ""; }
        if (pg.inItemPanel || pg.inSubPanel) {
            if (pg.inItemPanel && pg.kbIndex < pg.heroCount && pg.curItem) return pg.curItem.title + " — " + (pg.curItem.toggle ? ("Press Enter/Space to toggle (" + (pg.curItem.toggle.on ? "On" : "Off") + ")") : ("Left/Right to adjust (" + Math.round(reg.sliderVal(pg.curItem.slider) * 100) + "%)"));
            if (pg.inItemPanel && pg.kbIndex < pg.optBase && pg.curSubPanels[pg.kbIndex - pg.heroCount]) { const s = pg.curSubPanels[pg.kbIndex - pg.heroCount]; return s.title + " — " + s.sub; }
            if (pg.inItemPanel && pg.kbIndex < pg.lnBase && pg.curItem && pg.curItem.acts) { const a = pg.curItem.acts[pg.kbIndex - pg.optBase]; return a ? (a.l + " — " + pg.actionSub(a, pg.curItem)) : ""; }
            if (inlineLauncher.visible && inlineLauncher.activeSection.indexOf("ext-") === 0) { if (pg.kbIndex === pg.lnBase) return "Filter bar — Left/Right to switch category, Enter to search, Space to reset defaults"; const ex = (inlineLauncher.extList || [])[pg.kbIndex - pg.lnBase - 1]; if (ex) return ex.ext + " (" + ex.mime + ") — Active: " + ex.cur + "  ·  Left/Right to choose [" + inlineLauncher.installedOpts(ex).join(", ") + "]"; }
            if (pg.inItemPanel && pg.curItem && (!pg.inChildLevel || pg.kbIndex < pg.totalKbCount - 1)) return pg.curItem.title + " — " + pg.curItem.sub;
        }
        if (pg.inChildLevel && pg.kbIndex === pg.totalKbCount - 1) return "Return to " + (pg.inSubPanel ? pg.curItemTitle : pg.parentItem.title) + " — Press Enter/Space";
        return pg.curSubTitle !== "" ? (pg.curSubTitle + " — Use Arrow keys + Enter/Space to configure, Left/Up to return") : "";
    }
    Timer { interval: 4000; running: pg.confirmDanger !== ""; onTriggered: pg.confirmDanger = "" }
    function triggerAction(a) {
        if (!a) return;
        if (a.act === "cmd") pg.executeCommand(a.v, false); else if (a.act === "cmdClose") pg.executeCommand(a.v, true); else if (a.act === "bright") Status.setBrightness(Status.brightness + Number(a.v)); else if (a.act === "brightSet") Status.setBrightness(Number(a.v));
        else if (a.act === "spkMute") Status.toggleSpeakerMute(); else if (a.act === "spkStep") Status.setSpeakerVolume(Status.spkVol + Number(a.v)); else if (a.act === "spkSet") Status.setSpeakerVolume(Number(a.v)); else if (a.act === "micMute") Status.toggleMicMute(); else if (a.act === "micStep") Status.setMicVolume(Status.micVol + Number(a.v)); else if (a.act === "micSet") Status.setMicVolume(Number(a.v));
        else if (a.act === "kbdLight") Status.setKbdBacklight(); else if (a.act === "webcam") Status.toggleWebcam(); else if (a.act === "wifiToggle") Status.toggleWifiRadio(); else if (a.act === "autoTz") Status.toggleAutoTz();
    }
    function setSlider(kind, ratio) { const v = Math.max(0.0, Math.min(1.0, ratio)); if (kind === "bright") Status.setBrightness(Math.max(0.05, v)); else if (kind === "spk") Status.setSpeakerVolume(v); else if (kind === "mic") Status.setMicVolume(v); }
    function openCardPanel(it) { if (!it) return; const pCat = it.parent ? (reg.itemById(it.parent).cats[0] || pg.activePage) : pg.activePage, targetCat = it.cats.indexOf(pg.activePage) >= 0 ? pg.activePage : (it.cats[0] || pCat); pg.clearSearchRequested(); Status.openSettingsItem(targetCat, it.id, "", it.title); }
    function openSub(s) { if (!s) return; if (String(s.id).indexOf("item:") === 0) Status.openSettingsItem(pg.activePage, s.id.slice(5), "", s.title); else Status.openSettingsSub(s.id); }
    function stepUpLevel() { if (pg.inSubPanel) Status.openSettingsSub(""); else if (pg.parentItem) Status.openSettingsItem(pg.activePage, pg.parentItem.id, "", pg.parentItem.title); else Status.navUp(); }
    function triggerOpt(a) { if (!a) return; const needsC = Boolean(a.danger) && a.act !== "banner" && a.act !== "cast"; if (needsC && pg.confirmDanger !== a.l) { pg.confirmDanger = a.l; Status.playSfx("click"); } else { pg.confirmDanger = ""; pg.triggerAction(a); } }
    function cycleRoleApp(it, dir) {
        if (!it || !it.id || it.id.indexOf("app-def-") !== 0 || it.id === "app-def-suite" || it.id === "app-def-extensions" || !it.acts) return false;
        const apps = it.acts.filter(a => a.act === "cmd" && String(a.v || "").indexOf("--set ") >= 0); if (apps.length === 0) return false;
        const nextIdx = (Math.max(0, apps.findIndex(a => Boolean(a.on))) + dir + apps.length) % apps.length; if (pg.inItemPanel) pg.kbIndex = pg.optBase + nextIdx; pg.triggerAction(apps[nextIdx]); return true;
    }
    function handleKey(event) {
        const k = event.key, cnt = pg.totalKbCount;
        if (pg.inListPanel) {
            if (cnt === 0 || (k === Qt.Key_Up && pg.kbIndex === 0) || k === Qt.Key_Left) return (k === Qt.Key_Left || k === Qt.Key_Up) ? false : true;
            const cur = pg.visibleItems[Math.max(0, Math.min(cnt - 1, pg.kbIndex))];
            if (k === Qt.Key_Down || k === Qt.Key_Up || k === Qt.Key_PageDown || k === Qt.Key_PageUp || k === Qt.Key_Home || k === Qt.Key_End) {
                const d = k === Qt.Key_Down ? 1 : (k === Qt.Key_Up ? -1 : (k === Qt.Key_PageDown ? 5 : (k === Qt.Key_PageUp ? -5 : 0)));
                pg.kbIndex = k === Qt.Key_Home ? 0 : (k === Qt.Key_End ? cnt - 1 : Math.max(0, Math.min(cnt - 1, pg.kbIndex + d)));
                flick.contentY = pg.kbIndex === 0 ? 0 : Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), pg.kbIndex * 74 - flick.height * 0.35)); Status.playSfx("click"); return true;
            }
            if (k === Qt.Key_Right || k === Qt.Key_Return || k === Qt.Key_Enter) { if (cur) pg.openCardPanel(cur); return true; }
            if (k === Qt.Key_Space) { if (cur && cur.toggle) pg.triggerAction(cur.toggle); else if (cur) pg.openCardPanel(cur); return true; }
            return false;
        }
        const inL = inlineLauncher.visible && pg.kbIndex >= pg.lnBase, cols = inL ? Math.max(1, inlineLauncher.kbCols) : 1;
        if (k === Qt.Key_Up && (pg.kbIndex === 0 || (pg.lnBase === 0 && pg.kbIndex < cols && !inlineLauncher.hasHeaderRow))) return false;
        if (k === Qt.Key_Down || k === Qt.Key_Up || k === Qt.Key_PageDown || k === Qt.Key_PageUp || k === Qt.Key_Home || k === Qt.Key_End) {
            if (cnt === 0) return k === Qt.Key_Up ? false : true;
            if (k === Qt.Key_Up && inL && inlineLauncher.hasHeaderRow && (pg.kbIndex - pg.lnBase) >= inlineLauncher.hdrBase && (pg.kbIndex - pg.lnBase) < inlineLauncher.hdrBase + cols) { pg.kbIndex = pg.lnBase + inlineLauncher.hdrBase - 1; Status.playSfx("click"); return true; }
            const d = k === Qt.Key_Down ? cols : (k === Qt.Key_Up ? -cols : (k === Qt.Key_PageDown ? cols * 5 : (k === Qt.Key_PageUp ? -cols * 5 : 0)));
            pg.kbIndex = k === Qt.Key_Home ? 0 : (k === Qt.Key_End ? cnt - 1 : Math.max(0, Math.min(cnt - 1, pg.kbIndex + d)));
            flick.contentY = pg.kbIndex < cols ? 0 : Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), 120 + (pg.kbIndex / cols) * 68 - flick.height * 0.38)); Status.playSfx("click"); return true;
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right) {
            const dir = k === Qt.Key_Right ? 1 : -1;
            if (inL && cols > 1) { const n = pg.kbIndex + dir; if (n >= pg.lnBase && n < cnt) { pg.kbIndex = n; Status.playSfx("click"); return true; } if (dir < 0) { pg.stepUpLevel(); return true; } }
            if (inL && inlineLauncher.triggerKb(pg.kbIndex - pg.lnBase, dir)) return true;
            if (pg.inItemPanel && pg.cycleRoleApp(pg.curItem, dir)) return true;
            if (pg.inItemPanel && pg.curItem && pg.curItem.slider && pg.heroCount === 1 && pg.kbIndex === 0) { pg.setSlider(pg.curItem.slider, reg.sliderVal(pg.curItem.slider) + dir * 0.05); return true; }
            if (k === Qt.Key_Right) { if (pg.kbIndex >= pg.heroCount && pg.kbIndex < pg.optBase) pg.openSub(pg.curSubPanels[pg.kbIndex - pg.heroCount]); return true; }
            if (pg.inItemPanel || pg.inSubPanel) { pg.stepUpLevel(); return true; }
            return false;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (pg.kbIndex < pg.heroCount) { if (pg.curItem && pg.curItem.toggle) pg.triggerAction(pg.curItem.toggle); else if (pg.curItem && (pg.curItem.slider === "spk" || pg.curItem.slider === "mic")) pg.triggerAction({ act: pg.curItem.slider === "spk" ? "spkMute" : "micMute" }); }
            else if (pg.kbIndex < pg.optBase) pg.openSub(pg.curSubPanels[pg.kbIndex - pg.heroCount]); else if (pg.kbIndex < pg.lnBase && pg.curItem && pg.curItem.acts) pg.triggerOpt(pg.curItem.acts[pg.kbIndex - pg.optBase]);
            else if (inL && inlineLauncher.triggerKb(pg.kbIndex - pg.lnBase, 0, k)) {} else if (pg.inChildLevel && pg.kbIndex === cnt - 1) pg.stepUpLevel(); else if (pg.curItem && pg.curItem.toggle) pg.triggerAction(pg.curItem.toggle);
            return true;
        }
        return false;
    }
    function actionVerb(a, it) {
        if (!a) return "Open"; const id = it ? (it.id || "") : "", l = (a.l || "").toLowerCase(), act = a.act || "";
        if (a.verb && !a.on) return a.verb;
        if (id === "pwr-btrfs" && l.includes("create")) return "Create";
        if (id.indexOf("app-def-") === 0 && !l.startsWith("open ") && !l.startsWith("edit ") && !l.startsWith("reset ")) return a.on ? "󰄬 Default" : "Set default";
        if (a.on || (act === "brightSet" && Math.abs(Status.brightness - Number(a.v)) < 0.06) || (act === "micSet" && Math.abs(Status.micVol - Number(a.v)) < 0.06)) return "󰄬 Selected";
        if (act === "banner" || act === "cast" || l.includes("play") || l.includes("sound") || l.startsWith("test ") || l.includes("toast") || l.includes("preview") || l.includes("print test")) return "Preview";
        if (l.startsWith("edit ") || l.includes(".conf") || l.includes(".toml") || l.includes(".env") || l.includes(".list") || l.includes("clocks")) return "Edit";
        if (l.includes("status") || l.includes("inspect") || l.includes("table") || l.includes("list ") || l.includes("sockets") || l.includes("statistics") || l.includes("health") || l.includes("permissions") || l.includes("detect") || l.includes("probe") || l.includes("verify")) return "Inspect";
        if (act === "cmdClose" || l.startsWith("open ") || l.includes("tui") || l.includes("gui") || l.includes("manager") || l.includes("editor") || l.includes("console") || l.includes("mixer") || l.includes("analyzer") || l.includes("web ") || l.includes("add or manage") || l.includes("shortcuts") || id === "app-defaults") return "Open";
        if (l.includes("scan") || l.includes("rescan") || l.includes("check") || l.includes("firmware")) return "Scan"; if (l.includes("copy")) return "Copy"; if (l.includes("flush")) return "Flush"; if (l.includes("clear")) return "Clear";
        if (l.includes("reset")) return "Reset"; if (l.includes("export")) return "Export"; if (l.includes("import")) return "Import"; if (l.includes("update ") || l.startsWith("update")) return "Update";
        if (l.includes("optimize")) return "Optimize"; if (l.includes("enroll") || l.includes("generate") || l.includes("change password")) return "Configure"; if (l.includes("zoom")) return "Adjust";
        if (l.includes("mute") || l.includes("toggle") || l.includes("lock camera") || l.includes("enable camera") || l.includes("orca") || l.includes("mono") || l.includes("timezone") || act === "autoTz" || act === "kbdLight") return "Toggle";
        if (l.includes("switch") || l.startsWith("next ") || l.startsWith("previous ") || l.includes("cycle")) return "Switch";
        if (id === "disp-bright" || id === "disp-night" || id === "disp-scale" || id === "snd-spk" || id === "snd-mic" || id === "dev-touchpad" || id === "dev-kbd" || id === "acc-fontsize" || id === "acc-motion" || id === "pwr-mode" || id === "pwr-battery" || id === "pwr-idle") return "Select";
        return "Open";
    }
    function actionSub(a, it) {
        if (!a) return ""; const v = pg.actionVerb(a, it), t = it ? it.title : "setting";
        if (v === "󰄬 Default") return "Active default handler for " + t + " (Left/Right or Enter to switch)"; if (v === "Set default") return "Set as your default handler for " + t + " (Left/Right or Enter)";
        if (v === "󰄬 Selected") return "Currently active selection for " + t; if (v === "Select") return "Switch " + t + " to " + a.l; if (v === "Open") return "Launch interactive interface or window"; if (v === "Edit") return "Open configuration file in default editor";
        if (v === "Inspect") return "Inspect live system state and diagnostics"; if (v === "Preview") return "Trigger immediate live preview"; if (v === "Toggle") return "Toggle setting state immediately"; if (v === "Switch") return "Cycle to the next state";
        return v + " — " + t;
    }
    NumberAnimation { id: panelAnim; target: contentCol; property: "opacity"; from: 0.78; to: 1.0; duration: 95; easing.type: Easing.OutCubic }
    onActivePageChanged: { pg.confirmDanger = ""; pg.kbIndex = 0; flick.contentY = 0; panelAnim.restart(); }
    onSearchQueryChanged: { pg.kbIndex = 0; flick.contentY = 0; }
    Connections { target: Status; function onExpandedSettingIdChanged() { pg.confirmDanger = ""; pg.kbIndex = 0; flick.contentY = 0; if (Status.expandedSettingId !== "") pg.requestFocus(); panelAnim.restart(); } function onSettingsSubPanelChanged() { pg.confirmDanger = ""; pg.kbIndex = 0; flick.contentY = 0; if (Status.settingsSubPanel !== "") pg.requestFocus(); panelAnim.restart(); } }
    Flickable {
        id: flick; anchors { fill: parent; leftMargin: pg.isCompact ? 16 : 26; rightMargin: pg.isCompact ? 14 : 24; topMargin: 4; bottomMargin: 12 }
        contentWidth: width; contentHeight: contentCol.implicitHeight + 28; clip: true; boundsBehavior: Flickable.DragOverBounds; flickDeceleration: 3500
        ColumnLayout {
            id: contentCol; width: flick.width; spacing: 8
            Rectangle { visible: pg.inListPanel && pg.visibleItems.length === 0; Layout.fillWidth: true; implicitHeight: 80; radius: 6; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "No settings found for \"" + pg.searchQuery + "\"."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize } }
            Repeater {
                model: pg.inListPanel ? pg.visibleItems.length : 0
                Rectangle {
                    id: sCard; required property int index; readonly property var modelData: pg.visibleItems[index] || ({ id: "", title: "", sub: "", icon: "󰒓" })
                    readonly property bool isKb: (pg.paneFocused || pg.qNorm !== "") && index === pg.kbIndex; readonly property bool hasSlider: Boolean(modelData.slider); readonly property bool hasToggle: Boolean(modelData.toggle)
                    readonly property real sVal: hasSlider ? Math.max(0, Math.min(1, reg.sliderVal(modelData.slider))) : 0; readonly property bool sMuted: hasSlider && reg.sliderMuted(modelData.slider)
                    readonly property int spCnt: reg.subPanelsFor(modelData).length; readonly property int actCnt: (modelData.acts || []).length; readonly property string childBadge: spCnt > 1 ? (spCnt + " SUB-PANELS") : (actCnt > 0 ? (actCnt + " SUB-OPTIONS") : "SUB-PANEL")
                    Layout.fillWidth: true; implicitHeight: Math.max(68, cardRow.implicitHeight + 18); radius: 7; color: (hdrM.containsMouse || isKb) ? Theme.bgHover : Theme.bgAlt; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (hdrM.containsMouse ? Theme.blue : Theme.border); clip: true
                    Rectangle { width: 4; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } color: sCard.isKb ? Theme.cyan : (hdrM.containsMouse ? Theme.blue : Theme.muted); opacity: (sCard.isKb || hdrM.containsMouse) ? 1.0 : 0.45 }
                    MouseArea { id: hdrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open " + sCard.modelData.title + " — " + sCard.modelData.sub, containsMouse); onClicked: { pg.kbIndex = sCard.index; pg.requestFocus(); pg.openCardPanel(sCard.modelData); } }
                    RowLayout {
                        id: cardRow; anchors { fill: parent; leftMargin: 18; rightMargin: 14; topMargin: 9; bottomMargin: 9 } spacing: 12
                        Rectangle { implicitWidth: 38; implicitHeight: 38; radius: 7; color: Theme.bg; border.width: 1; border.color: (hdrM.containsMouse || sCard.isKb) ? Theme.blue : Theme.border; clip: true; Text { anchors.centerIn: parent; text: sCard.modelData.icon || "󰒓"; color: (hdrM.containsMouse || sCard.isKb) ? Theme.blue : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 4 } }
                        ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: sCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: sCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: pg.isCompact ? Text.WordWrap : Text.NoWrap; maximumLineCount: pg.isCompact ? 2 : 1; elide: Text.ElideRight } }
                        RowLayout {
                            visible: sCard.hasSlider; spacing: 8
                            Rectangle { visible: sCard.modelData.slider === "spk" || sCard.modelData.slider === "mic"; implicitWidth: 30; implicitHeight: 30; radius: 5; color: muteM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: muteM.containsMouse ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: sCard.sMuted ? "󰝟" : "󰕾"; color: sCard.sMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize } MouseArea { id: muteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(sCard.sMuted ? "Unmute audio" : "Mute audio", containsMouse); onClicked: pg.triggerAction({ act: sCard.modelData.slider === "spk" ? "spkMute" : "micMute" }) } }
                            Rectangle { implicitWidth: pg.isCompact ? 84 : 136; implicitHeight: 8; radius: 4; color: Theme.bg; border.width: 1; border.color: (slM.containsMouse || sCard.isKb) ? Theme.cyan : Theme.border; Rectangle { width: Math.round(parent.width * sCard.sVal); height: parent.height; radius: 4; color: (slM.containsMouse || sCard.isKb) ? Theme.cyan : Theme.blue } MouseArea { id: slM; anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Drag to adjust " + sCard.modelData.title + " (" + Math.round(sCard.sVal * 100) + "%)", containsMouse); onPressed: mouse => pg.setSlider(sCard.modelData.slider, mouse.x / width); onPositionChanged: mouse => { if (pressed) pg.setSlider(sCard.modelData.slider, mouse.x / width); } } }
                            Text { id: sPct; Layout.preferredWidth: Math.max(40, sPct.implicitWidth + 4); horizontalAlignment: Text.AlignRight; text: Math.round(sCard.sVal * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        }
                        RowLayout {
                            visible: sCard.hasToggle; spacing: 8
                            Text { visible: !pg.isCompact; text: (sCard.modelData.toggle && sCard.modelData.toggle.on) ? "On" : "Off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                            Rectangle { readonly property bool tOn: Boolean(sCard.modelData.toggle && sCard.modelData.toggle.on); implicitWidth: 42; implicitHeight: 22; radius: 11; color: tOn ? Theme.blue : (tglM.containsMouse ? Theme.bgHover : Theme.bg); border.width: 1; border.color: tOn ? Theme.blue : (tglM.containsMouse ? Theme.blue : Theme.muted); Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; x: parent.tOn ? 23 : 4; color: parent.tOn ? Theme.bg : Theme.fgDim; Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } } } MouseArea { id: tglM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Toggle " + sCard.modelData.title + " (Space)", containsMouse); onClicked: pg.triggerAction(sCard.modelData.toggle) } }
                        }
                        Rectangle { visible: !pg.isCompact; implicitWidth: chBdTxt.implicitWidth + 14; implicitHeight: 22; radius: 11; color: Theme.bg; border.width: 1; border.color: (hdrM.containsMouse || sCard.isKb) ? (sCard.spCnt > 1 ? Theme.cyan : Theme.blue) : Theme.border; Text { id: chBdTxt; anchors.centerIn: parent; text: sCard.childBadge; color: sCard.spCnt > 1 ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.weight: Font.Bold } }
                        Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 5; color: (hdrM.containsMouse || sCard.isKb) ? Theme.bg : "transparent"; Text { anchors.centerIn: parent; text: "󰅂"; color: (hdrM.containsMouse || sCard.isKb) ? Theme.blue : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } }
                    }
                }
            }
            Rectangle {
                visible: pg.inItemPanel || pg.inSubPanel; Layout.fillWidth: true; implicitHeight: heroCol.implicitHeight + 28; radius: 8; color: Theme.bgAlt; border.width: 1.5; border.color: pg.inChildLevel ? Theme.cyan : Theme.blue; clip: true
                Rectangle { width: 5; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } color: pg.inChildLevel ? Theme.cyan : Theme.blue }
                ColumnLayout {
                    id: heroCol; anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 20; rightMargin: 16; topMargin: 14 } spacing: 10
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { implicitWidth: pBdTxt.implicitWidth + 16; implicitHeight: 20; radius: 10; color: pg.inChildLevel ? Theme.bg : Theme.blue; border.width: 1; border.color: Theme.blue; Text { id: pBdTxt; anchors.centerIn: parent; text: pg.inSubPanel ? "󰒓 PARENT SETTING" : (pg.parentItem ? ("󰒓 " + pg.parentItem.title.toUpperCase()) : "󰒓 PARENT SETTING"); color: pg.inChildLevel ? Theme.blue : Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.weight: Font.Bold } MouseArea { anchors.fill: parent; enabled: pg.inChildLevel; cursorShape: pg.inChildLevel ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: pg.stepUpLevel() } }
                        Text { visible: pg.inChildLevel; text: "󰅂"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                        Rectangle { visible: pg.inChildLevel; implicitWidth: sBdTxt.implicitWidth + 16; implicitHeight: 20; radius: 10; color: Theme.cyan; Text { id: sBdTxt; anchors.centerIn: parent; text: "󰙅 SUB-PANEL · " + (pg.inSubPanel ? pg.curSubTitle : pg.curItemTitle).toUpperCase(); color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.weight: Font.Bold } }
                        Item { Layout.fillWidth: true }
                        Text { visible: pg.inItemPanel; text: (pg.subCount > 0 ? (pg.subCount + " sub-panels  ·  ") : "") + (pg.optCount > 0 ? (pg.optCount + " sub-options") : "Interactive sub-options below"); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.weight: Font.DemiBold }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 14
                        Rectangle { implicitWidth: 46; implicitHeight: 46; radius: 8; color: Theme.bg; border.width: 1.5; border.color: pg.inChildLevel ? Theme.cyan : Theme.blue; Text { anchors.centerIn: parent; text: pg.curItem ? (pg.curItem.icon || "󰒓") : "󰒓"; color: pg.inChildLevel ? Theme.cyan : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize + 8 } }
                        ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: pg.inSubPanel ? (pg.curItemTitle + "  ›  " + pg.curSubTitle) : (pg.curItem ? pg.curItem.title : ""); color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: pg.curItem ? pg.curItem.sub : ""; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.fillWidth: true; wrapMode: Text.WordWrap } Text { visible: Boolean(pg.curItem && reg.detailFor(pg.curItem)); text: pg.curItem ? reg.detailFor(pg.curItem) : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; wrapMode: Text.WordWrap } }
                        RowLayout {
                            visible: pg.inItemPanel && Boolean(pg.curItem && pg.curItem.toggle); spacing: 10
                            Text { text: (pg.curItem && pg.curItem.toggle && pg.curItem.toggle.on) ? "On" : "Off"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                            Rectangle { readonly property bool tOn: Boolean(pg.curItem && pg.curItem.toggle && pg.curItem.toggle.on); implicitWidth: 46; implicitHeight: 24; radius: 12; color: tOn ? Theme.blue : (hTglM.containsMouse ? Theme.bgHover : Theme.bg); border.width: pg.isHeroKb ? 2 : 1; border.color: pg.isHeroKb ? Theme.cyan : (tOn ? Theme.blue : (hTglM.containsMouse ? Theme.blue : Theme.muted)); Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: parent.tOn ? 25 : 4; color: parent.tOn ? Theme.bg : Theme.fgDim; Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } } } MouseArea { id: hTglM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Toggle " + (pg.curItem ? pg.curItem.title : "setting"), containsMouse); onClicked: { pg.kbIndex = 0; pg.requestFocus(); if (pg.curItem) pg.triggerAction(pg.curItem.toggle); } } }
                        }
                    }
                    RowLayout {
                        visible: pg.inItemPanel && Boolean(pg.curItem && pg.curItem.slider); Layout.fillWidth: true; spacing: 12
                        readonly property real hVal: pg.curItem && pg.curItem.slider ? Math.max(0, Math.min(1, reg.sliderVal(pg.curItem.slider))) : 0; readonly property bool hMuted: pg.curItem && pg.curItem.slider ? reg.sliderMuted(pg.curItem.slider) : false
                        Rectangle { visible: Boolean(pg.curItem && (pg.curItem.slider === "spk" || pg.curItem.slider === "mic")); implicitWidth: 34; implicitHeight: 32; radius: 5; color: hMuteM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: hMuteM.containsMouse ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: parent.parent.hMuted ? "󰝟" : "󰕾"; color: parent.parent.hMuted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } MouseArea { id: hMuteM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(parent.parent.hMuted ? "Unmute audio" : "Mute audio", containsMouse); onClicked: if (pg.curItem) pg.triggerAction({ act: pg.curItem.slider === "spk" ? "spkMute" : "micMute" }) } }
                        Text { id: hSlLbl; text: (pg.curItem && pg.curItem.slider === "bright") ? "Luminance" : "Master level"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.preferredWidth: Math.max(96, hSlLbl.implicitWidth + 8) }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Theme.bg; border.width: pg.isHeroKb ? 2 : 1; border.color: pg.isHeroKb ? Theme.cyan : (hSlM.containsMouse ? Theme.cyan : Theme.border); readonly property real sVal: parent.hVal; Rectangle { width: Math.round(parent.width * parent.sVal); height: parent.height; radius: 4; color: (hSlM.containsMouse || pg.isHeroKb) ? Theme.cyan : Theme.blue } MouseArea { id: hSlM; anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Drag or press Left/Right to adjust master level (" + Math.round(parent.sVal * 100) + "%)", containsMouse); onPressed: mouse => { pg.kbIndex = 0; pg.requestFocus(); if (pg.curItem) pg.setSlider(pg.curItem.slider, mouse.x / width); } onPositionChanged: mouse => { if (pressed && pg.curItem) pg.setSlider(pg.curItem.slider, mouse.x / width); } } }
                        Text { id: hSlPct; Layout.preferredWidth: Math.max(44, hSlPct.implicitWidth + 4); horizontalAlignment: Text.AlignRight; text: Math.round(parent.hVal * 100) + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                    }
                }
            }
            Item {
                visible: pg.inItemPanel || pg.inSubPanel; Layout.fillWidth: true; implicitHeight: childTreeCol.implicitHeight
                Rectangle { x: pg.isCompact ? 6 : 12; y: -6; width: 2; height: parent.height + 2; radius: 1; color: pg.inChildLevel ? Theme.cyan : Theme.blue; opacity: 0.55 }
                Rectangle { x: pg.isCompact ? 3 : 9; y: -4; width: 8; height: 8; radius: 4; color: pg.inChildLevel ? Theme.cyan : Theme.blue }
                ColumnLayout {
                    id: childTreeCol; anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: pg.isCompact ? 16 : 28 } spacing: 12
                    Rectangle {
                        visible: pg.inItemPanel && pg.subCount > 0; Layout.fillWidth: true; implicitHeight: subGrpCol.implicitHeight + 2; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; clip: true
                        ColumnLayout {
                            id: subGrpCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 } spacing: 0
                            Rectangle { Layout.fillWidth: true; implicitHeight: 34; color: Theme.bgAlt; RowLayout { anchors { fill: parent; leftMargin: 14; rightMargin: 14 } spacing: 8; Text { text: "├─  󰙅  SUB-PANELS & DEEP CONFIGURATION"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: spCntTxt.implicitWidth + 14; implicitHeight: 18; radius: 9; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { id: spCntTxt; anchors.centerIn: parent; text: pg.subCount + " SUB-PANELS"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.weight: Font.Bold } } } }
                            Repeater {
                                model: pg.subCount
                                Rectangle {
                                    id: subCard; required property int index; readonly property var modelData: pg.curSubPanels[index] || ({ id: "", title: "", sub: "", icon: "󰒓" }); readonly property bool isKb: pg.paneFocused && (index + pg.heroCount) === pg.kbIndex
                                    Layout.fillWidth: true; implicitHeight: Math.max(56, subCardRow.implicitHeight + 14); color: (subCardM.containsMouse || isKb) ? Theme.bgHover : Theme.bg; border.width: isKb ? 1.5 : 0; border.color: Theme.cyan
                                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.border; opacity: 0.65 }
                                    Rectangle { visible: subCard.isKb || subCardM.containsMouse; width: 3; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } color: Theme.cyan }
                                    MouseArea { id: subCardM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Open sub-panel: " + subCard.modelData.title + " — " + subCard.modelData.sub, containsMouse); onClicked: { pg.kbIndex = subCard.index + pg.heroCount; pg.requestFocus(); pg.openSub(subCard.modelData); } }
                                    RowLayout { id: subCardRow; anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 7; bottomMargin: 7 } spacing: 10; Text { text: subCard.index === pg.subCount - 1 ? "└─" : "├─"; color: subCard.isKb ? Theme.cyan : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } Rectangle { implicitWidth: 32; implicitHeight: 32; radius: 6; color: Theme.bgAlt; border.width: 1; border.color: (subCard.isKb || subCardM.containsMouse) ? Theme.cyan : Theme.border; Text { anchors.centerIn: parent; text: subCard.modelData.icon || "󰒓"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1 } } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: subCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: subCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true; wrapMode: pg.isCompact ? Text.WordWrap : Text.NoWrap; maximumLineCount: pg.isCompact ? 2 : 1; elide: Text.ElideRight } } Rectangle { implicitWidth: Math.max(pg.isCompact ? 78 : 112, subBtnTxt.implicitWidth + 20); implicitHeight: 26; radius: 5; color: (subCardM.containsMouse || subCard.isKb) ? Theme.cyan : Theme.bgAlt; border.width: 1; border.color: Theme.cyan; Text { id: subBtnTxt; anchors.centerIn: parent; text: pg.isCompact ? "SUB 󰅂" : "SUB-PANEL  󰅂"; color: (subCardM.containsMouse || subCard.isKb) ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.weight: Font.Bold } } }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: pg.inItemPanel && pg.optCount > 0; Layout.fillWidth: true; implicitHeight: optGrpCol.implicitHeight + 2; radius: 8; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; clip: true
                        ColumnLayout {
                            id: optGrpCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 } spacing: 0
                            Rectangle { Layout.fillWidth: true; implicitHeight: 34; color: Theme.bgAlt; RowLayout { anchors { fill: parent; leftMargin: 14; rightMargin: 14 } spacing: 8; Text { text: "├─  󰒓  SUB-OPTIONS & CONFIGURATION"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: opCntTxt.implicitWidth + 14; implicitHeight: 18; radius: 9; color: Theme.bg; border.width: 1; border.color: Theme.blue; Text { id: opCntTxt; anchors.centerIn: parent; text: pg.optCount + " SUB-OPTIONS"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.weight: Font.Bold } } } }
                            Repeater {
                                model: pg.optCount
                                Rectangle {
                                    id: optCard; required property int index; readonly property var modelData: (pg.curItem && pg.curItem.acts && pg.curItem.acts[index]) ? pg.curItem.acts[index] : ({ l: "", act: "" }); readonly property bool isKb: pg.paneFocused && (index + pg.optBase) === pg.kbIndex
                                    readonly property bool isOn: Boolean(modelData.on) || pg.actionVerb(modelData, pg.curItem).indexOf("󰄬") === 0; readonly property bool isDanger: Boolean(modelData.danger); readonly property bool needsConfirm: isDanger
                                    readonly property bool armed: needsConfirm && pg.confirmDanger === modelData.l; readonly property string verb: armed ? ("Confirm " + modelData.l + "?") : pg.actionVerb(modelData, pg.curItem)
                                    Layout.fillWidth: true; implicitHeight: Math.max(52, optCardRow.implicitHeight + 12); color: (optRowM.containsMouse || isKb) ? Theme.bgHover : Theme.bg; border.width: isKb ? 1.5 : 0; border.color: Theme.cyan
                                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.border; opacity: 0.65 }
                                    Rectangle { visible: optCard.isOn || optCard.isKb || optCard.isDanger; width: 3; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } color: optCard.isKb ? Theme.cyan : (optCard.isDanger ? Theme.red : Theme.blue) }
                                    MouseArea { id: optRowM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(optCard.modelData.l + " — " + pg.actionSub(optCard.modelData, pg.curItem), containsMouse); onClicked: { pg.kbIndex = optCard.index + pg.optBase; pg.requestFocus(); pg.triggerOpt(optCard.modelData); } }
                                    RowLayout { id: optCardRow; anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 6; bottomMargin: 6 } spacing: 10; Text { text: optCard.index === pg.optCount - 1 ? "└─" : "├─"; color: optCard.isKb ? Theme.cyan : (optCard.isOn ? Theme.blue : Theme.muted); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 6; color: optCard.isOn ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: optCard.isOn ? Theme.blue : Theme.border; Text { anchors.centerIn: parent; text: optCard.isOn ? "󰄬" : (optCard.isDanger ? "󰀨" : "󰘖"); color: optCard.isOn ? Theme.bg : (optCard.isDanger ? Theme.red : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.fontSize } } ColumnLayout { Layout.fillWidth: true; spacing: 1; Text { text: optCard.modelData.l; color: optCard.isDanger ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: optCard.isOn ? Font.Bold : Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: optCard.armed ? "Press Enter or click again within 4s to confirm action" : pg.actionSub(optCard.modelData, pg.curItem); color: optCard.armed ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true; wrapMode: pg.isCompact ? Text.WordWrap : Text.NoWrap; maximumLineCount: pg.isCompact ? 2 : 1; elide: Text.ElideRight } } Rectangle { implicitWidth: Math.max(84, optBtnTxt.implicitWidth + 20); implicitHeight: 26; radius: 5; color: (optCard.armed || optCard.isKb || optRowM.containsMouse || optBtnM.containsMouse) ? (optCard.isDanger ? Theme.red : Theme.blue) : (optCard.isOn ? Theme.blue : Theme.bgAlt); border.width: 1; border.color: optCard.isDanger ? Theme.red : (optCard.isOn ? Theme.blue : Theme.border); Text { id: optBtnTxt; anchors.centerIn: parent; text: optCard.verb; color: (optCard.armed || optCard.isOn || optCard.isKb || optRowM.containsMouse || optBtnM.containsMouse) ? Theme.bg : (optCard.isDanger ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold } MouseArea { id: optBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip(optCard.verb + " — " + optCard.modelData.l, containsMouse); onClicked: { pg.kbIndex = optCard.index + pg.optBase; pg.requestFocus(); pg.triggerOpt(optCard.modelData); } } } }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: inlineLauncher.visible; Layout.fillWidth: true; implicitHeight: lnGrpCol.implicitHeight + 18; radius: 8; color: Theme.bg; border.width: 1; border.color: Theme.border; clip: true
                        ColumnLayout { id: lnGrpCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 8; RowLayout { Layout.fillWidth: true; spacing: 8; Text { text: "└─  󰕮  SUB-OPTIONS · " + (pg.inSubPanel ? pg.curSubTitle : pg.curItemTitle).toUpperCase(); color: pg.inChildLevel ? Theme.cyan : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: inBdTxt.implicitWidth + 14; implicitHeight: 18; radius: 9; color: Theme.bgAlt; border.width: 1; border.color: pg.inChildLevel ? Theme.cyan : Theme.blue; Text { id: inBdTxt; anchors.centerIn: parent; text: inlineLauncher.kbCount + " ITEMS"; color: pg.inChildLevel ? Theme.cyan : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.weight: Font.Bold } } } LauncherMenu { id: inlineLauncher; readonly property string inlineSec: (pg.curSubPanels.length === 1 && !pg.curSubPanels[0].isChildItem) ? pg.curSubPanels[0].id : (pg.curItem && pg.curItem.id === "acc-profile" ? "usr-edit" : (pg.curItem && pg.curItem.id === "ai-cluster" ? "ai-nodes" : "")); visible: pg.inSubPanel || (pg.inItemPanel && inlineSec !== ""); Layout.fillWidth: true; activeSection: pg.inSubPanel ? Status.settingsSubPanel : inlineSec; parentItem: pg.curItem; btList: pg.btList; kbActive: pg.paneFocused && pg.kbIndex >= pg.lnBase; kbIndex: pg.kbIndex - pg.lnBase; onTriggerSettingAction: actObj => pg.triggerAction(actObj); onExecuteCommand: (c, cl) => pg.executeCommand(c, cl); onCloseRequested: Status.settingsOpen = false; onFocusItem: idx => { pg.kbIndex = pg.lnBase + idx; pg.requestFocus(); } } }
                    }
                    Rectangle { id: retSubBox; visible: pg.inChildLevel; readonly property bool isKb: pg.paneFocused && pg.kbIndex === pg.totalKbCount - 1; Layout.fillWidth: true; implicitHeight: 44; radius: 6; color: (isKb || retSubM.containsMouse) ? Theme.bgHover : Theme.bgAlt; border.width: isKb ? 2 : 1; border.color: isKb ? Theme.cyan : (retSubM.containsMouse ? Theme.blue : Theme.border); RowLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 16 } spacing: 10; Text { text: "󰁍  Return to parent setting (" + (pg.inSubPanel ? pg.curItemTitle : (pg.parentItem ? pg.parentItem.title : pg.curItemTitle)) + ")"; color: (retSubBox.isKb || retSubM.containsMouse) ? Theme.fg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.Medium; Layout.fillWidth: true } Text { text: "Alt + Up"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } } MouseArea { id: retSubM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: Status.setTip("Return to parent setting (Alt + Up / Esc)", containsMouse); onClicked: pg.stepUpLevel() } }
                }
            }
        }
    }
}
