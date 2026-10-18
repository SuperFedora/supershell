import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "panels"

// SuperBar — unified 4-edge (top/bottom/left/right) bar & island engine, one instance per edge per
// screen. Widgets, style and hide mode all come from Status.barEdgeConfig(edge) ← ~/.config/superfedora/superbar.json:
//   style    flush = full span, radius 0, no margin · floating = 6px inset, Theme.radius, Theme.border ·
//            island = centred pill hugging content (+20), 6px inset, Theme.radius + 2, Theme.blue border
//   hideMode always = revealed + ExclusionMode.Auto · autohide = 3px edge strip (and open popups)
//            reveal it · intellihide = also revealed while this monitor has 0 tiled windows.
//   widgets  split into start | center | end by '|' tokens; bodies live in BarWidgets.qml and the
//            hardware quick pill stays here (it owns the trackers). Token-less lists keep legacy order.
PanelWindow {
    id: bar
    required property var modelData; screen: modelData
    property string edge: "top"
    readonly property var edgeCfg: Status.barEdgeConfig(edge)
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property int activeWsId: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property bool isVert: edge === "left" || edge === "right"
    readonly property string barStyle: (edgeCfg && edgeCfg.style) || "flush"
    readonly property string hideMode: (edgeCfg && edgeCfg.hideMode) || "always"
    readonly property bool edgeOn: Boolean(edgeCfg && edgeCfg.enabled !== false)
    readonly property bool island: barStyle === "island"
    readonly property int thickness: Theme.barHeight
    // A flush top bar paints the screen's top corners in its own colour, so it melts into the
    // rounded screen corner instead of butting squarely against the wallpaper (STYLE_RESEARCH §3).
    readonly property bool screenCorners: bar.barStyle === "flush" && bar.edgeOn
    readonly property int pad: barStyle === "flush" ? 0 : 6
    readonly property int inner: bar.island ? 4 : 0
    property bool edgeHover: false; property bool trayOpen: true
    property string tipText: ""; property real tipPos: 0; property bool tipReady: false; property var tipOwner: null
    readonly property string calendarMode: calendarPopup.mode
    readonly property string flyoutMode: quickFlyout.mode
    readonly property bool popupOpen: bar.calendarMode !== "" || bar.flyoutMode !== ""
    onPopupOpenChanged: if (bar.popupOpen) Status.barPopupEdge = bar.edge; else if (Status.barPopupEdge === bar.edge) Status.barPopupEdge = ""
    readonly property bool popAnim: calendarPopup.visible || quickFlyout.visible
    readonly property real popS: calendarPopup.visible ? calendarPopup.popStart : (quickFlyout.visible ? quickFlyout.popStart : -1)
    readonly property real popE: calendarPopup.visible ? calendarPopup.popEnd : (quickFlyout.visible ? quickFlyout.popEnd : -1)
    readonly property int tiledHere: (Status.clients || []).filter(c => c.workspace && c.workspace.id === bar.activeWsId && !c.floating).length
    readonly property bool revealed: bar.hideMode === "always" || bar.edgeHover || bar.popupOpen || (bar.hideMode === "intellihide" && bar.tiledHere === 0)
    // ── Zone split (start | center | end) ────────────────────────────────────────────────────────
    readonly property var wlist: (edgeCfg && Array.isArray(edgeCfg.widgets)) ? edgeCfg.widgets : []
    function _zones(l) {
        const s = [], c = [], e = [], seps = l.filter(x => x === "|").length, hasNav = l.indexOf("launcher") >= 0 || l.indexOf("workspaces") >= 0;
        for (let i = 0; i < l.length; i++) {
            const w = l[i]; if (w === "|") continue;
            const b = l.slice(0, i).filter(x => x === "|").length;
            const n = seps >= 2 ? b : (seps === 1 ? (b === 0 ? 0 : 2) : (["launcher", "workspaces"].indexOf(w) >= 0 || (w === "pinned" && !hasNav) ? 0 : (["window", "media", "tools", "clock", "pinned"].indexOf(w) >= 0 ? 1 : 2)));
            (n === 0 ? s : n === 1 ? c : e).push(w);
        }
        return { start: s, center: c, end: e };
    }
    readonly property var zz: bar._zones(wlist); readonly property int zAt: zz.center.indexOf("clock")
    readonly property var zoneStart: zz.start; readonly property var zoneEnd: zz.end
    readonly property var zonePre: zAt > 0 ? zz.center.slice(0, zAt) : []
    readonly property var zoneClock: zAt >= 0 ? zz.center.slice(zAt, zAt + 1) : zz.center
    readonly property var zonePost: zAt >= 0 ? zz.center.slice(zAt + 1) : []
    readonly property bool delegated: bar.hideMode === "activity" && bar.isVert && bar.wlist.filter(x => x !== "|").length === 1 && bar.wlist.indexOf("forge") >= 0
    visible: bar.edgeOn && !bar.delegated; color: "transparent"
    exclusionMode: bar.edgeOn && bar.hideMode === "always" ? ExclusionMode.Auto : ExclusionMode.Ignore
    anchors { top: bar.edge === "top" || (bar.isVert && !bar.island); bottom: bar.edge === "bottom" || (bar.isVert && !bar.island); left: bar.edge === "left" || (!bar.isVert && !bar.island); right: bar.edge === "right" || (!bar.isVert && !bar.island) }
    readonly property int fullW: bar.isVert ? bar.thickness + bar.pad * 2 : (bar.island ? Math.max(140, host.implicitWidth + bar.inner * 2 + bar.pad * 2) : (bar.modelData ? bar.modelData.width - bar.pad * 2 : 0))
    readonly property int fullH: bar.isVert ? (bar.island ? Math.max(140, host.implicitHeight + bar.inner * 2 + bar.pad * 2) : (bar.modelData ? bar.modelData.height - bar.pad * 2 : 0)) : bar.thickness + bar.pad * 2
    implicitWidth: (bar.isVert && !bar.revealed && bar.hideMode !== "always") ? 4 : bar.fullW
    implicitHeight: (!bar.isVert && !bar.revealed && bar.hideMode !== "always") ? 4 : bar.fullH
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function closePopups() { calendarPopup.mode = ""; quickFlyout.mode = ""; }
    property var iconSlots: ({})
    function toggleCalendar(targetMode, itemRef) {
        bar.setBarTip(null, "", false); Status.appGridOpen = false; Status.recorderOpen = false; quickFlyout.mode = ""; Status.notifDrawerOpen = false;
        if (calendarPopup.mode === targetMode) { calendarPopup.mode = ""; }
        else {
            const offX = (bar.island && !bar.isVert && bar.modelData) ? (bar.modelData.width - bar.implicitWidth) / 2 : 0;
            const offY = (bar.island && bar.isVert && bar.modelData) ? (bar.modelData.height - bar.implicitHeight) / 2 : 0;
            calendarPopup.anchorX = itemRef ? (itemRef.mapToItem(null, itemRef.width / 2, 0).x + offX) : (surface.x + surface.width / 2 + offX);
            calendarPopup.anchorY = itemRef ? (itemRef.mapToItem(null, 0, itemRef.height / 2).y + offY) : (surface.y + surface.height / 2 + offY);
            if (targetMode === "date") calendarPopup.resetToToday(); else Status.refresh();
            calendarPopup.mode = targetMode;
        }
        if (Status.notifAction) Status.notifAction("setCenterOpen", false); Status.playSfx("click"); }
    function toggleFlyout(targetMode, itemRef) {
        bar.setBarTip(null, "", false); Status.appGridOpen = false; Status.recorderOpen = false; calendarPopup.mode = ""; Status.notifDrawerOpen = false;
        if (quickFlyout.mode === targetMode) { quickFlyout.mode = ""; }
        else {
            const ref = itemRef || bar.iconSlots[targetMode] || null;
            const offX = (bar.island && !bar.isVert && bar.modelData) ? (bar.modelData.width - bar.implicitWidth) / 2 : 0;
            const offY = (bar.island && bar.isVert && bar.modelData) ? (bar.modelData.height - bar.implicitHeight) / 2 : 0;
            quickFlyout.anchorX = ref ? (ref.mapToItem(null, ref.width / 2, 0).x + offX) : -1;
            quickFlyout.anchorY = ref ? (ref.mapToItem(null, 0, ref.height / 2).y + offY) : -1;
            quickFlyout.mode = targetMode; Status.refresh();
        }
        if (Status.notifAction) Status.notifAction("setCenterOpen", false); Status.playSfx("click"); }
    function setBarTip(itemRef, text, show) {
        if (!show || !text) { if (!itemRef) { bar.tipOwner = null; bar.tipText = ""; bar.tipReady = false; tipTimer.stop(); tipHideTimer.stop(); } else if (bar.tipOwner === itemRef) { tipTimer.stop(); tipHideTimer.restart(); } return; }
        tipHideTimer.stop(); bar.tipOwner = itemRef;
        if (itemRef) { const p = itemRef.mapToItem(null, itemRef.width / 2, itemRef.height / 2); bar.tipPos = bar.isVert ? p.y : p.x; }
        bar.tipText = text; if (!bar.tipReady) tipTimer.restart(); }

    // Bar surface + ordered widget slots (edgeCfg.widgets).
    Rectangle {
        id: surface; visible: bar.revealed
        readonly property int winW: bar.width > 0 ? bar.width : bar.implicitWidth
        readonly property int winH: bar.height > 0 ? bar.height : bar.implicitHeight
        width: bar.isVert ? bar.thickness : (bar.island ? host.implicitWidth + bar.inner * 2 : Math.max(0, winW - bar.pad * 2))
        height: bar.isVert ? (bar.island ? host.implicitHeight + bar.inner * 2 : Math.max(0, winH - bar.pad * 2)) : bar.thickness
        x: (winW - width) / 2; y: (winH - height) / 2
        radius: bar.island || bar.barStyle === "floating" ? Theme.radius : 0
        color: bar.island || bar.barStyle === "floating" ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)
        border.width: bar.island || bar.barStyle === "floating" ? (Status.barFocused ? 2 : 1) : 0
        border.color: Status.barFocused ? Theme.blue : Theme.border
        readonly property real bMin: bar.isVert ? (Status.barFlushOn("top") ? bar.thickness - 2 : 0) : (Status.barFlushOn("left") ? bar.thickness - 2 : 0)
        readonly property real bMax: (bar.isVert ? surface.height : surface.width) - (bar.isVert ? (Status.barFlushOn("bottom") ? bar.thickness - 2 : 0) : ((Status.barFlushOn("right") ? bar.thickness - 2 : 0) + (bar.edge === "top" && Status.notifDrawerOpen ? (378 + Math.max(0, Theme.radius - 2)) : 0)))
        readonly property real gS: bar.popAnim && bar.popS >= 0 ? Math.max(surface.bMin, Math.min(surface.bMax, bar.popS + 2)) : surface.bMax
        readonly property real gE: bar.popAnim && bar.popE >= 0 ? Math.max(surface.bMin, Math.min(surface.bMax, bar.popE - 2)) : surface.bMax
        Rectangle { visible: Status.barFocused && bar.barStyle === "flush" && !(bar.edge === "right" && Status.notifDrawerOpen); x: bar.isVert ? (bar.edge === "left" ? parent.width - 2 : 0) : parent.bMin; y: bar.isVert ? parent.bMin : (bar.edge === "top" ? parent.height - 2 : 0); width: bar.isVert ? 2 : Math.max(0, parent.gS - parent.bMin); height: bar.isVert ? Math.max(0, parent.gS - parent.bMin) : 2; color: Theme.blue; z: 10 }
        Rectangle { visible: Status.barFocused && bar.barStyle === "flush" && !(bar.edge === "right" && Status.notifDrawerOpen) && parent.bMax > parent.gE; x: bar.isVert ? (bar.edge === "left" ? parent.width - 2 : 0) : parent.gE; y: bar.isVert ? parent.gE : (bar.edge === "top" ? parent.height - 2 : 0); width: bar.isVert ? 2 : Math.max(0, parent.bMax - parent.gE); height: bar.isVert ? Math.max(0, parent.bMax - parent.gE) : 2; color: Theme.blue; z: 10 }
        Flow { id: host; visible: bar.island; anchors { centerIn: parent } flow: bar.isVert ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
            Repeater { model: bar.wlist.filter((w, i, a) => w !== "|" || (i > 0 && i < a.length - 1 && a[i - 1] !== "|")); delegate: slotC } }
        Row { id: zStart; visible: !bar.island && !bar.isVert; spacing: 2; anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 } Repeater { model: bar.zoneStart; delegate: slotC } }
        Row { id: zEnd; visible: !bar.island && !bar.isVert; spacing: 2; anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 } Repeater { model: bar.zoneEnd; delegate: slotC } }
        Row { id: zPre; visible: !bar.island && !bar.isVert; spacing: 2; anchors { right: zClock.left; verticalCenter: parent.verticalCenter; rightMargin: 2 } Repeater { model: bar.zonePre; delegate: slotC } }
        Row { id: zClock; visible: !bar.island && !bar.isVert; spacing: 0; anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter } Repeater { model: bar.zoneClock; delegate: slotC } }
        Row { id: zPost; visible: !bar.island && !bar.isVert; spacing: 2; anchors { left: zClock.right; verticalCenter: parent.verticalCenter; leftMargin: 2 } Repeater { model: bar.zonePost; delegate: slotC } }
        Column { id: vStart; visible: !bar.island && bar.isVert; spacing: 2; anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 4 } Repeater { model: bar.zoneStart; delegate: slotC } }
        Column { id: vEnd; visible: !bar.island && bar.isVert; spacing: 2; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 } Repeater { model: bar.zoneEnd; delegate: slotC } }
        Column { id: vPre; visible: !bar.island && bar.isVert; spacing: 2; anchors { bottom: vClock.top; horizontalCenter: parent.horizontalCenter; bottomMargin: 2 } Repeater { model: bar.zonePre; delegate: slotC } }
        Column { id: vClock; visible: !bar.island && bar.isVert; spacing: 0; anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter } Repeater { model: bar.zoneClock; delegate: slotC } }
        Column { id: vPost; visible: !bar.island && bar.isVert; spacing: 2; anchors { top: vClock.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 2 } Repeater { model: bar.zonePost; delegate: slotC } }
        Component { id: slotC; Loader { id: slot; required property string modelData; sourceComponent: slot.modelData === "hardware" ? statusPillC : widgetC
            Component { id: widgetC; BarWidgets { widgetId: slot.modelData; vertical: bar.isVert; engine: bar } } } }
    }

    // Screen corners beneath any flush bar: one quarter disc per outer corner, painted in the bar colour.
    ConcaveFillet { visible: bar.screenCorners && Theme.radius > 0; x: bar.edge === "right" ? surface.winW - width : 0; y: bar.edge === "bottom" ? surface.winH - height : 0; size: Theme.radius; corner: bar.edge === "bottom" ? "BottomLeft" : (bar.edge === "right" ? "TopRight" : "TopLeft"); color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity) }
    ConcaveFillet { visible: bar.screenCorners && Theme.radius > 0; x: bar.edge === "left" ? 0 : surface.winW - width; y: (bar.edge === "bottom" || bar.isVert) ? surface.winH - height : 0; size: Theme.radius; corner: bar.edge === "top" ? "TopRight" : (bar.edge === "left" ? "BottomLeft" : "BottomRight"); color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity) }

    // Click-through background, bar opacity toggle, and the hover strip that reveals hidden edges.
    MouseArea { anchors.fill: parent; z: -1; onClicked: { bar.setBarTip(null, "", false); calendarPopup.mode = ""; quickFlyout.mode = ""; Status.forgeShown = false; Status.notifDrawerOpen = false; if (Status.notifAction) Status.notifAction("setCenterOpen", false); } onDoubleClicked: { Theme.barOpacity = Theme.barOpacity < 0.99 ? 1.0 : 0.82; Status.playSfx("toggle"); } }
    HoverHandler { onHoveredChanged: { if (hovered) { hideDelay.stop(); bar.edgeHover = true; } else { bar.setBarTip(null, "", false); hideDelay.restart(); } } }
    Timer { id: hideDelay; interval: 220; onTriggered: bar.edgeHover = false }
    Timer { id: tipTimer; interval: 260; onTriggered: if (bar.tipText !== "" && bar.tipOwner) bar.tipReady = true }
    Timer { id: tipHideTimer; interval: 140; onTriggered: { bar.tipOwner = null; bar.tipText = ""; bar.tipReady = false; } }
    Rectangle { id: strip; visible: bar.edgeOn && !bar.revealed && bar.hideMode !== "always"; anchors.centerIn: parent; width: bar.isVert ? 2 : Math.min(96, bar.implicitWidth); height: bar.isVert ? Math.min(96, bar.implicitHeight) : 2; color: Theme.blue; opacity: 0.45; radius: 1 }
    PanelWindow { id: barTipWin; visible: bar.tipReady && bar.tipText !== "" && bar.revealed && !bar.popupOpen && !Status.appGridOpen && !Status.settingsOpen && !Status.notifDrawerOpen
        screen: bar.modelData; color: "transparent"; exclusionMode: ExclusionMode.Ignore; mask: Region {}
        anchors { top: bar.edge === "top" || bar.isVert; bottom: bar.edge === "bottom"; left: bar.edge === "left" || !bar.isVert; right: bar.edge === "right" }
        margins { top: bar.edge === "top" ? bar.thickness + bar.pad + 4 : 0; bottom: bar.edge === "bottom" ? bar.thickness + bar.pad + 4 : 0; left: bar.edge === "left" ? bar.thickness + bar.pad + 4 : 0; right: bar.edge === "right" ? bar.thickness + bar.pad + 4 : 0 }
        implicitWidth: bar.isVert ? tipBox.implicitWidth + 4 : (bar.modelData ? bar.modelData.width : 1920); implicitHeight: bar.isVert ? (bar.modelData ? bar.modelData.height : 1080) : tipBox.implicitHeight + 4
        Rectangle { id: tipBox; readonly property real winOff: bar.island && bar.modelData ? ((bar.isVert ? (bar.modelData.height - bar.implicitHeight) : (bar.modelData.width - bar.implicitWidth)) / 2) : 0
            implicitWidth: tipLbl.implicitWidth + 16; implicitHeight: 24; width: implicitWidth; height: implicitHeight
            x: !bar.isVert ? Math.max(8, Math.min(parent.width - width - 8, Math.round(bar.tipPos + winOff - width / 2))) : 0; y: bar.isVert ? Math.max(8, Math.min(parent.height - height - 8, Math.round(bar.tipPos + winOff - height / 2))) : 0
            radius: Theme.radiusSm; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97); border.width: 1; border.color: Theme.blue
            Text { id: tipLbl; anchors.centerIn: parent; text: bar.tipText; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } } }
    function handleBarClick(px, py, btn) {
        for (const k in bar.iconSlots) {
            const it = bar.iconSlots[k]; if (!it || !it.visible) continue;
            const p = it.mapToItem(null, 0, 0);
            if (px >= p.x && px <= p.x + it.width && py >= p.y && py <= p.y + it.height) {
                if (k === "date") { bar.toggleCalendar(btn === Qt.RightButton ? "time" : "date", it); return; }
                if (k === "notifs") { calendarPopup.mode = ""; quickFlyout.mode = ""; Status.notifDrawerOpen = !Status.notifDrawerOpen; if (Status.notifAction) Status.notifAction("setCenterOpen", Status.notifDrawerOpen); Status.playSfx("click"); return; }
                bar.toggleFlyout(k, it); return; } }
        calendarPopup.mode = ""; quickFlyout.mode = ""; Status.playSfx("click"); }
    // Popovers positioned directly adjacent to the clicked clock or status icon on any of the 4 edges.
    Calendar { id: calendarPopup; targetScreen: bar.modelData; barEdge: bar.edge; barClick: (x, y, b) => bar.handleBarClick(x, y, b) }
    QuickFlyout { id: quickFlyout; targetScreen: bar.modelData; barEdge: bar.edge; barClick: (x, y, b) => bar.handleBarClick(x, y, b) }
    Connections { target: Status
        function onCenterToggleSeqChanged() { if (bar.edge === "top" && bar.modelData === Quickshell.screens[0] && Status.notifAction) Status.notifAction("setCenterOpen", !Status.notifDrawerOpen); }
        function onFlyoutReqSeqChanged() { if (bar.edge === "top" && bar.modelData === Quickshell.screens[0]) { if (Status.flyoutReqMode === "date" || Status.flyoutReqMode === "time") bar.toggleCalendar(Status.flyoutReqMode, null); else bar.toggleFlyout(Status.flyoutReqMode, null); } }
        function onNotifDrawerOpenChanged() { if (Status.notifDrawerOpen) { calendarPopup.mode = ""; quickFlyout.mode = ""; } }
        function onAppGridOpenChanged() { if (Status.appGridOpen) { calendarPopup.mode = ""; quickFlyout.mode = ""; } }
        function onRecorderOpenChanged() { if (Status.recorderOpen) { calendarPopup.mode = ""; quickFlyout.mode = ""; } }
        function onSettingsOpenChanged() { if (Status.settingsOpen) { calendarPopup.mode = ""; quickFlyout.mode = ""; } } }
    // Status icons pill (wifi / bluetooth / speaker / mic / camera / battery / power) — horizontal or vertical.
    Component { id: statusPillC
        Rectangle { id: pill; PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
            readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null
            readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
            readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
            readonly property real micVol: micReady ? (source.audio.muted ? 0 : source.audio.volume) : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
            readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
            readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
            readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
            readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)
            function glyph(id) {
                if (id === "wifi") { const sig = Status.signal > 0 ? Status.signal : 70; return !Status.wifiEnabled ? "󰤮" : (Status.netType === "ethernet" ? "󰀂" : (Status.netType !== "wifi" ? "󰤯" : (sig >= 75 ? "󰤨" : sig >= 55 ? "󰤥" : sig >= 35 ? "󰤢" : "󰤟"))); }
                if (id === "bluetooth") return !pill.btAdapter || !pill.btAdapter.enabled ? "󰂲" : (pill.btConnected > 0 ? "󰂱" : "󰂯");
                if (id === "speaker") return pill.muted ? "󰝟" : pill.vol >= 0.66 ? "󰕾" : pill.vol >= 0.33 ? "󰖀" : "󰕿";
                if (id === "mic") return pill.micMuted ? "󰍭" : "󰍬"; if (id === "camera") return Status.webcamEnabled ? "󰄀" : "󰗟";
                if (id === "battery") return pill.batCharging ? "󰂄" : (pill.batPct <= 15 ? "󰁺" : pill.batPct <= 40 ? "󰁼" : pill.batPct <= 75 ? "󰂀" : "󰁹"); return "󰐥"; }
            function iconColor(id, hovered) {
                if (bar.flyoutMode === id) return Theme.blue; if (hovered) return Theme.cyan;
                if (id === "battery") return pill.batCharging ? Theme.blue : (pill.batPct <= 15 ? Theme.red : Theme.fg);
                if (id === "wifi") return (!Status.wifiEnabled || Status.netType === "none") ? Theme.muted : Theme.fg;
                if (id === "bluetooth") return (pill.btAdapter && pill.btAdapter.enabled) ? (pill.btConnected > 0 ? Theme.blue : Theme.fgDim) : Theme.muted;
                if (id === "speaker") return pill.muted ? Theme.muted : Theme.fg; if (id === "mic") return pill.micMuted ? Theme.muted : Theme.fg;
                return id === "camera" ? (Status.webcamEnabled ? Theme.fg : Theme.muted) : Theme.fgDim; }
            function toggleDevice(id) {
                if (id === "wifi") Status.toggleWifiRadio();
                else if (id === "bluetooth") { bar.run(pill.btAdapter && pill.btAdapter.enabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on"); Status.playSfx("toggle"); Status.refresh(); }
                else if (id === "speaker") { const m = !pill.muted; if (pill.audioReady) pill.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                else if (id === "mic") { const m = !pill.micMuted; if (pill.micReady) pill.source.audio.muted = m; Status.toggleMicMute(m); }
                else if (id === "camera") Status.toggleWebcam(); else bar.run("qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session"); }
            function tipFor(id) { if (id === "wifi") return Status.wifiEnabled ? (Status.netType === "ethernet" ? "Ethernet" : (Status.netType === "wifi" ? (Status.ssid ? Status.ssid + " · " + Status.signal + "%" : "Wi-Fi · " + Status.signal + "%") : "Wi-Fi · Disconnected")) : "Wi-Fi Off"; if (id === "bluetooth") return pill.btAdapter && pill.btAdapter.enabled ? (pill.btConnected > 0 ? "Bluetooth · " + pill.btConnected + " Connected" : "Bluetooth") : "Bluetooth Off";
                if (id === "speaker") return "Speaker · " + (pill.muted ? "Muted" : Math.round(pill.vol * 100) + "%"); if (id === "mic") return "Microphone · " + (pill.micMuted ? "Muted" : Math.round(pill.micVol * 100) + "%");
                if (id === "camera") return "Camera · " + (Status.webcamEnabled ? "On" : "Off"); if (id === "battery") return "Battery · " + pill.batPct + "%" + (pill.batCharging ? " · Charging" : ""); return "Power Menu"; }
            implicitWidth: bar.isVert ? bar.thickness : pillRow.implicitWidth + 6; implicitHeight: bar.isVert ? pillRow.implicitHeight + 6 : bar.thickness; color: "transparent"; border.width: 0
            Flow { id: pillRow; anchors.centerIn: parent; flow: bar.isVert ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
                Repeater { model: Status.barIcons
                    Item { id: slot; required property string modelData; required property int index
                        readonly property bool isDiv: modelData === "|"
                        readonly property bool isVis: isDiv ? (index > 0 && index < Status.barIcons.length - 1) : (Status.barHiddenIcons.indexOf(modelData) < 0 && (modelData !== "battery" || pill.batPresent))
                        visible: isVis; implicitWidth: !isVis ? 0 : (bar.isVert ? bar.thickness : (isDiv ? 9 : 26)); width: implicitWidth; implicitHeight: !isVis ? 0 : (bar.isVert ? (isDiv ? 9 : 26) : bar.thickness); height: implicitHeight
                        Component.onCompleted: if (!slot.isDiv && pill.parent && pill.parent.parent && pill.parent.parent.visible) bar.iconSlots[slot.modelData] = slot
                        Rectangle { visible: slot.isDiv; anchors.centerIn: parent; width: bar.isVert ? 14 : 1; height: bar.isVert ? 1 : 14; color: Theme.border }
                        Rectangle { visible: !slot.isDiv; anchors.centerIn: parent; width: bar.isVert ? bar.thickness - 8 : 26; height: bar.isVert ? 26 : bar.thickness - 8; radius: Theme.radiusSm; transformOrigin: Item.Center; scale: slotM.pressed ? 0.90 : (slotM.containsMouse ? 1.08 : 1.0); color: slotM.pressed ? Theme.bgAlt : (slotM.containsMouse ? Theme.bgHover : "transparent"); border.width: 0
                            Text { anchors.centerIn: parent; text: pill.glyph(slot.modelData); color: pill.iconColor(slot.modelData, slotM.containsMouse); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
                            Behavior on scale { NumberAnimation { duration: Theme.dur(150); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } } }
                        MouseArea { id: slotM; visible: !slot.isDiv; property real dragStart: 0; property bool didDrag: false; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onContainsMouseChanged: bar.setBarTip(slot, pill.tipFor(slot.modelData), containsMouse)
                            onPressed: e => { slotM.dragStart = bar.isVert ? e.y : e.x; slotM.didDrag = false; }
                            onPositionChanged: e => { if (pressedButtons & Qt.LeftButton) { const cur = bar.isVert ? e.y : e.x, d = cur - slotM.dragStart; if (Math.abs(d) >= 24) { slotM.didDrag = true; Status.moveBarIcon(slot.modelData, d > 0 ? 1 : -1); slotM.dragStart = cur; } } }
                            onClicked: e => { if (!slotM.didDrag) { bar.setBarTip(null, "", false); if (e.button === Qt.RightButton) pill.toggleDevice(slot.modelData); else bar.toggleFlyout(slot.modelData, slot); } }
                            onWheel: wheel => { const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05; if (slot.modelData === "speaker") { const v = Math.max(0, Math.min(1, pill.vol + step)); if (pill.audioReady) pill.sink.audio.volume = v; Status.setSpeakerVolume(v); } else if (slot.modelData === "mic") { const v = Math.max(0, Math.min(1, pill.micVol + step)); if (pill.micReady) pill.source.audio.volume = v; Status.setMicVolume(v); } } } } } } } }

    // Right-side recorder dock (top edge only).
    PanelWindow { id: recorderDock
        visible: (Status.recorderOpen || Status.screenRecording) && bar.edge === "top" && !Status.appGridOpen && calendarPopup.mode === "" && quickFlyout.mode === ""
        screen: bar.modelData; color: "transparent"; exclusionMode: ExclusionMode.Ignore; anchors.right: true; margins.right: 8
        implicitWidth: 144; implicitHeight: recCol.implicitHeight + 24
        Rectangle { anchors.fill: parent; radius: Theme.radius; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.96); border.width: 2; border.color: Status.screenRecording ? (Status.screenPaused ? Theme.yellow : Theme.red) : Theme.cyan
            ColumnLayout { id: recCol; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 } spacing: 8
                Text { Layout.alignment: Qt.AlignHCenter; text: Status.screenRecording ? (Status.screenPaused ? "󰏤 PAUSED" : "󰻂 REC") : "󰻂 RECORDER"; color: Status.screenRecording ? (Status.screenPaused ? Theme.yellow : Theme.red) : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
                Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; readonly property color accent: Status.screenRecording && !Status.screenPaused ? Theme.yellow : Theme.green; color: recStartM.containsMouse ? accent : Theme.bgAlt; border.width: 1; border.color: accent; Text { anchors.centerIn: parent; text: !Status.screenRecording || Status.screenPaused ? "󰐊 Start" : "󰏤 Pause"; color: recStartM.containsMouse ? Theme.bg : parent.accent; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: recStartM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (!Status.screenRecording) Status.startScreenRecord(false); else Status.pauseScreenRecord(); } } }
                Rectangle { Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; readonly property color accent: Status.screenRecording ? Theme.red : Theme.cyan; color: recActM.containsMouse ? accent : Theme.bgAlt; border.width: 1; border.color: accent; Text { anchors.centerIn: parent; text: Status.screenRecording ? "󰓛 Stop" : "󰹑 Region"; color: recActM.containsMouse ? Theme.bg : parent.accent; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: recActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.screenRecording) Status.stopScreenRecord(); else Status.startScreenRecord(true); } } }
                Rectangle { visible: !Status.screenRecording; Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: recCloseM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: recCloseM.containsMouse ? Theme.red : Theme.border; Text { anchors.centerIn: parent; text: "× Close"; color: recCloseM.containsMouse ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: recCloseM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.recorderOpen = false; Status.playSfx("click"); } } } } } } }
