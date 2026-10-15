import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import ".."

// Omarchy Quattro Dock: grab-and-drag edge relocation, hover tooltips, multi-window pips & Input/Output controls.
PanelWindow {
    id: win; required property var modelData; screen: modelData
    readonly property var cfg: Status.dockConfig || ({ position: "bottom", autohide: false, showAlways: true, pinned: [] })
    readonly property string position: cfg.position || "bottom"; readonly property bool isVert: position === "left" || position === "right"
    readonly property var hyprMon: Hyprland.monitorFor(modelData)
    readonly property int wsId: hyprMon && hyprMon.activeWorkspace ? hyprMon.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property string wsMode: Status.wsModeFor(win.wsId)
    readonly property bool hasFullscreen: (Status.clients || []).some(c => c.workspace && c.workspace.id === win.wsId && c.fullscreen >= 2)
    readonly property bool hasMaximized: (Status.clients || []).some(c => c.workspace && c.workspace.id === win.wsId && c.fullscreen === 1)
    readonly property bool shown: !win.hasFullscreen && !Status.superDeckOpen && (cfg.showAlways !== false || win.wsMode === "floating")
    readonly property bool autohide: cfg.autohide === true || win.hasMaximized
    readonly property var sink: Pipewire.defaultAudioSink; readonly property bool spkReady: sink !== null && sink.audio !== null
    readonly property real spkVol: spkReady ? sink.audio.volume : Status.spkVol; readonly property bool spkMuted: spkReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
    readonly property var ioItems: [
        { id: "spk", icon: win.spkMuted ? "󰝟" : (win.spkVol >= 0.5 ? "󰕾" : "󰖀"), active: !win.spkMuted, color: win.spkMuted ? Theme.red : Theme.cyan, tip: win.spkMuted ? "Speakers: Muted (Click to unmute)" : ("Speakers: " + Math.round(win.spkVol * 100) + "% (Click to mute)") },
        { id: "mic", icon: win.micMuted ? "󰍭" : "󰍬", active: !win.micMuted, color: win.micMuted ? Theme.red : Theme.green, tip: win.micMuted ? "Microphone: Muted (Click to unmute)" : ("Microphone: " + Math.round(win.micVol * 100) + "% (Click to mute)") },
        { id: "cam", icon: Status.webcamEnabled ? "󰄀" : "󰗟", active: Status.webcamEnabled, color: Status.webcamEnabled ? Theme.green : Theme.red, tip: Status.webcamEnabled ? "Web Camera: ON (Click to turn off)" : "Web Camera: OFF (Click to turn on)" }
    ]
    property bool edgeHovered: false; property bool keepRevealed: false; property var menuTarget: null
    property bool settingsMenu: false; property int menuSlotIdx: 0; property int dragIdx: -1
    property real dragStartCoord: 0; property var launchingMap: ({}); property real dockOpacity: 1.0
    property string hoveredName: ""; property int hoveredSlotIdx: 0; property bool edgeDragging: false; property string ghostEdge: ""
    readonly property bool forgeVisible: Status.forgeBusy || Status.forgeRecent
    readonly property color forgeCol: Status.forgeState === "error" ? Theme.red : ((Status.forgeState === "ok" || Status.forgeState === "done") ? Theme.green : Theme.yellow)
    readonly property bool menuOpen: win.menuTarget !== null || win.settingsMenu
    readonly property bool activelyInteracting: win.edgeHovered || bodyHover.hovered || menuHover.hovered || win.menuOpen || win.dragIdx >= 0 || win.edgeDragging || win.forgeVisible
    readonly property bool contentShown: win.shown && (!win.autohide || win.activelyInteracting || win.keepRevealed)

    Connections { target: Status; function onSuperDeckOpenChanged() { if (Status.superDeckOpen) { win.menuTarget = null; win.settingsMenu = false; } } }
    onActivelyInteractingChanged: if (win.activelyInteracting) { win.keepRevealed = true; hideTimer.stop(); } else hideTimer.restart()
    Timer { id: hideTimer; interval: 350; onTriggered: if (!win.activelyInteracting) win.keepRevealed = false }
    Timer { interval: 8000; running: Object.keys(win.launchingMap).length > 0; repeat: true; onTriggered: win.launchingMap = ({}) }

    function normId(raw) { return String(raw || "").trim().replace(/\.desktop$/i, ""); }
    function iconUrl(s) { const v = String(s || ""); return !v ? "" : (v.startsWith("file://") || v.startsWith("image://")) ? v : v.startsWith("/") ? ("file://" + v) : (Quickshell.iconPath(v, true) || ""); }
    function findEntry(idOrClass) {
        const raw = win.normId(idOrClass), low = raw.toLowerCase(); if (!raw) return null;
        if (Status.localAppsMap && Status.localAppsMap[low]) return Status.localAppsMap[low];
        let e = DesktopEntries.byId(raw) || DesktopEntries.byId(low); if (e) return e;
        if (DesktopEntries.heuristicLookup) { e = DesktopEntries.heuristicLookup(raw); if (e) return e; }
        const all = ((DesktopEntries.applications && DesktopEntries.applications.values) ? DesktopEntries.applications.values : []).concat(Status.localApps || []);
        for (let i = 0; i < all.length; i++) { const item = all[i], eid = win.normId(item.id).toLowerCase(); if (eid === low || eid.endsWith("." + low) || String(item.name || "").toLowerCase() === low) return item; }
        return null;
    }

    readonly property var dockItems: {
        const pinnedIds = Array.isArray(cfg.pinned) ? cfg.pinned : [], clients = Status.clients || [], byKey = {}, order = [];
        function ensureSlot(key, entry, isPinned) {
            if (!byKey[key]) { byKey[key] = { key: key, pinned: isPinned, entry: entry, name: entry ? (entry.name || key) : key, icon: entry ? win.iconUrl(entry.icon) : "", windows: [], focused: false, minimizedCount: 0 }; order.push(byKey[key]); }
            else if (isPinned) byKey[key].pinned = true;
            return byKey[key];
        }
        for (let i = 0; i < pinnedIds.length; i++) { const pid = win.normId(pinnedIds[i]); if (!pid) continue; const entry = win.findEntry(pid); ensureSlot(entry ? win.normId(entry.id) : pid, entry, true); }
        for (let j = 0; j < clients.length; j++) {
            const c = clients[j], cls = String(c.class || c.initialClass || ""); if (!cls || cls === "quake-ai") continue;
            const entry = win.findEntry(cls), key = entry ? win.normId(entry.id) : cls, slot = ensureSlot(key, entry, false), isMin = String((c.workspace && c.workspace.name) || "").includes("minimized");
            slot.windows.push({ address: c.address, workspaceId: c.workspace ? c.workspace.id : 1, minimized: isMin, focused: c.focusHistoryID === 0 });
            if (c.focusHistoryID === 0 && !isMin) slot.focused = true; if (isMin) slot.minimizedCount++;
        }
        return order;
    }

    function launchItem(item) {
        if (!item) return; Status.superDeckOpen = false; Status.settingsOpen = false; Status.playSfx("click"); const nextMap = Object.assign({}, win.launchingMap); nextMap[item.key] = Date.now(); win.launchingMap = nextMap;
        if (item.entry && typeof item.entry.execute === "function") item.entry.execute();
        else Quickshell.execDetached(["sh", "-c", "gtk-launch '" + item.key + "' 2>/dev/null || ~/.local/bin/" + item.key + " 2>/dev/null || " + item.key.toLowerCase()]);
    }
    function activateItem(item) {
        if (!item) return; Status.superDeckOpen = false; Status.settingsOpen = false; const wins = item.windows || []; if (wins.length === 0) { win.launchItem(item); return; } Status.playSfx("click");
        const sorted = wins.slice().sort((a, b) => (a.minimized ? 1 : (a.workspaceId === win.wsId ? 0 : 2)) - (b.minimized ? 1 : (b.workspaceId === win.wsId ? 0 : 2)));
        let pick = sorted[0]; for (let i = 0; i < sorted.length; i++) if (sorted[i].focused) { pick = sorted[(i + 1) % sorted.length]; break; }
        if (pick.minimized) Hyprland.dispatch("movetoworkspace " + win.wsId + ",address:" + pick.address);
        Hyprland.dispatch("focuswindow address:" + pick.address); Status.refresh();
    }
    function quitItem(item) { if (!item || !item.windows) return; for (let i = 0; i < item.windows.length; i++) Hyprland.dispatch("closewindow address:" + item.windows[i].address); Status.refresh(); }
    function movePin(fromIdx, toIdx) {
        const pins = win.dockItems.filter(x => x.pinned).map(x => x.key); if (fromIdx < 0 || fromIdx >= pins.length || toIdx < 0 || toIdx >= pins.length || fromIdx === toIdx) return;
        const moved = pins.splice(fromIdx, 1)[0]; pins.splice(toIdx, 0, moved); Status.runDockCmd("pinned " + pins.map(k => "'" + k + "'").join(" "));
    }
    visible: win.shown; color: "transparent"
    WlrLayershell.namespace: "superfedora-dock"; WlrLayershell.layer: WlrLayer.Top; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal; exclusiveZone: 0; anchors { bottom: true; top: true; left: true; right: true }
    mask: Region { item: win.contentShown ? dockBar : null; Region { item: (win.shown && win.autohide) ? edgeStrip : null } Region { item: win.menuOpen ? contextPopup : null } Region { item: (win.contentShown && win.forgeVisible) ? forgeBanner : null } }

    Item {
        id: edgeStrip; width: win.isVert ? 6 : Math.max(240, dockBar.width); height: win.isVert ? Math.max(240, dockBar.height) : 6
        x: win.position === "left" ? 0 : (win.position === "right" ? win.width - 6 : dockBar.x); y: win.position === "top" ? 0 : (win.position === "bottom" ? win.height - 6 : dockBar.y)
        HoverHandler { id: stripHover; onHoveredChanged: win.edgeHovered = stripHover.hovered }
    }
    Rectangle {
        id: ghostSlab; visible: win.edgeDragging && win.ghostEdge !== ""; readonly property bool gVert: win.ghostEdge === "left" || win.ghostEdge === "right"
        width: gVert ? 58 : dockBar.width; height: gVert ? dockBar.height : 58
        x: win.ghostEdge === "left" ? 8 : (win.ghostEdge === "right" ? win.width - width - 8 : Math.round((win.width - width) / 2))
        y: win.ghostEdge === "top" ? 42 : (win.ghostEdge === "bottom" ? win.height - height - 8 : Math.round((win.height - height) / 2))
        radius: Theme.radius; color: Qt.rgba(Theme.blue.r, Theme.blue.g, Theme.blue.b, 0.25); border.width: 2; border.color: Theme.cyan
    }
    Rectangle {
        id: forgeBanner; visible: win.contentShown && win.forgeVisible && !win.menuOpen && !win.edgeDragging
        width: 340; height: 54; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: win.forgeCol
        x: win.position === "left" ? (dockBar.x + dockBar.width + 8) : (win.position === "right" ? (dockBar.x - width - 8) : Math.round((win.width - width) / 2))
        y: win.position === "top" ? (dockBar.y + dockBar.height + 8) : (win.position === "bottom" ? (dockBar.y - height - 8) : Math.round(dockBar.y + (dockBar.height - height) / 2))
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleSuperDeck("forge") }
        ColumnLayout {
            anchors { fill: parent; margins: 7 } spacing: 3
            RowLayout { Layout.fillWidth: true; spacing: 6; Text { text: "󰙪 FORGE: " + (Status.forgeTarget || "working"); color: win.forgeCol; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: Status.forgePct + "%"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } Text { text: Status.forgeBusy ? "[STOP]" : "[×]"; color: Status.forgeBusy ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.forgeBusy) Status.stopForge(); else Status.dismissForgeBanner(); } } } }
            Rectangle { Layout.fillWidth: true; implicitHeight: 6; radius: 2; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; Rectangle { width: Math.round((parent.width - 2) * Math.max(0, Math.min(100, Status.forgePct)) / 100); height: 4; x: 1; y: 1; radius: 1; color: win.forgeCol } }
            Text { text: Status.forgeStep + (Status.forgeLogLine ? ("  ·  " + Status.forgeLogLine) : ""); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
    Rectangle {
        id: hoverTooltip; visible: win.contentShown && !win.menuOpen && win.hoveredName !== "" && !win.edgeDragging && !win.forgeVisible
        width: tipText.implicitWidth + 16; height: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue
        x: win.position === "left" ? (dockBar.x + dockBar.width + 8) : (win.position === "right" ? (dockBar.x - width - 8) : Math.max(8, Math.min(win.width - width - 8, dockBar.x + win.hoveredSlotIdx * 50 - Math.round(width / 2) + 28)))
        y: win.position === "top" ? (dockBar.y + dockBar.height + 8) : (win.position === "bottom" ? (dockBar.y - height - 8) : Math.max(8, Math.min(win.height - height - 8, dockBar.y + win.hoveredSlotIdx * 50 + 16)))
        Text { id: tipText; anchors.centerIn: parent; text: win.hoveredName; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
    }
    Rectangle {
        id: dockBar; visible: win.contentShown; width: win.isVert ? 58 : (dockGrid.implicitWidth + 18); height: win.isVert ? (dockGrid.implicitHeight + 18) : 58
        x: win.position === "left" ? 6 : (win.position === "right" ? win.width - width - 6 : Math.round((win.width - width) / 2))
        y: win.position === "top" ? 42 : (win.position === "bottom" ? win.height - height - 6 : Math.round((win.height - height) / 2))
        radius: Theme.radius; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, win.dockOpacity); border.width: 2; border.color: win.forgeVisible ? win.forgeCol : Theme.blue; HoverHandler { id: bodyHover }
        MouseArea {
            anchors.fill: parent; z: -1; property point startPt: Qt.point(0, 0)
            onDoubleClicked: { win.dockOpacity = win.dockOpacity < 0.99 ? 1.0 : 0.78; Status.playSfx("toggle"); }
            onPressed: e => { startPt = Qt.point(e.x, e.y); win.ghostEdge = win.position; }
            onPositionChanged: e => { if (pressed && Math.hypot(e.x - startPt.x, e.y - startPt.y) > 24) { win.edgeDragging = true; const gx = dockBar.x + e.x, gy = dockBar.y + e.y, dL = gx, dR = win.width - gx, dT = gy, dB = win.height - gy, m = Math.min(dL, dR, dT, dB); win.ghostEdge = m === dB ? "bottom" : (m === dT ? "top" : (m === dL ? "left" : "right")); } }
            onReleased: { if (win.edgeDragging && win.ghostEdge && win.ghostEdge !== win.position) { Status.runDockCmd("position " + win.ghostEdge); Status.playSfx("confirm"); } win.edgeDragging = false; win.ghostEdge = ""; }
        }
        GridLayout {
            id: dockGrid; anchors.centerIn: parent; columns: win.isVert ? 1 : 99; rows: win.isVert ? 99 : 1; rowSpacing: 6; columnSpacing: 6
            Rectangle {
                id: appsBtn; implicitWidth: 44; implicitHeight: 44; radius: Theme.radiusSm; color: Status.appGridOpen || appsMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                border.width: Status.appGridOpen || appsMouse.containsMouse ? 2 : 1; border.color: Status.appGridOpen ? Theme.cyan : (appsMouse.containsMouse ? Theme.blue : Theme.border)
                Text { anchors.centerIn: parent; text: "󰀻"; color: Status.appGridOpen ? Theme.cyan : Theme.blue; font.family: Theme.font; font.pixelSize: 22 }
                MouseArea {
                    id: appsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: { win.hoveredSlotIdx = 0; win.hoveredName = "Launchpad App Grid"; }
                    onExited: if (win.hoveredSlotIdx === 0) win.hoveredName = ""
                    onClicked: e => { if (e.button === Qt.RightButton) { win.menuTarget = null; win.menuSlotIdx = 0; win.settingsMenu = !win.settingsMenu; } else { win.menuTarget = null; win.settingsMenu = false; Status.appGridOpen = !Status.appGridOpen; Status.playSfx("click"); } }
                }
            }
            Repeater {
                model: win.dockItems
                Rectangle {
                    id: slot; required property var modelData; required property int index
                    readonly property bool running: modelData.windows.length > 0; readonly property bool launching: win.launchingMap[modelData.key] !== undefined && !running
                    implicitWidth: 44; implicitHeight: 44; radius: Theme.radiusSm; scale: slotMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    color: slotMouse.containsMouse ? Theme.bgHover : (modelData.focused ? Theme.bgAlt : "transparent")
                    border.width: modelData.focused || slotMouse.containsMouse ? 2 : 1; border.color: modelData.focused ? Theme.blue : (slotMouse.containsMouse ? Theme.cyan : "transparent")
                    Image { id: appIcon; anchors.centerIn: parent; width: 30; height: 30; sourceSize: Qt.size(64, 64); source: slot.modelData.icon; visible: status === Image.Ready; opacity: slot.running || slot.launching ? 1.0 : 0.68; smooth: true; mipmap: true }
                    Text { anchors.centerIn: parent; visible: appIcon.status !== Image.Ready; text: "󰣆"; color: slot.modelData.focused ? Theme.cyan : (slot.running ? Theme.fg : Theme.fgDim); font.family: Theme.font; font.pixelSize: 22 }
                    Row {
                        visible: slot.running || slot.launching; spacing: 3; anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
                        Repeater { model: slot.launching ? 1 : Math.min(3, slot.modelData.windows.length); Rectangle { required property int index; width: slot.modelData.focused && index === 0 ? 8 : 4; height: 3; radius: Theme.radiusSm > 0 ? 1 : 0; color: slot.launching ? Theme.yellow : (slot.modelData.focused ? Theme.cyan : (slot.modelData.minimizedCount > 0 ? Theme.orange : Theme.blue)) } }
                    }
                    MouseArea {
                        id: slotMouse; anchors.fill: parent; hoverEnabled: true; preventStealing: true; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor; property bool dragged: false
                        onEntered: { win.hoveredSlotIdx = slot.index + 1; win.hoveredName = slot.modelData.name + (slot.modelData.windows.length > 1 ? " (" + slot.modelData.windows.length + ")" : ""); }
                        onExited: if (win.hoveredSlotIdx === slot.index + 1) win.hoveredName = ""
                        onPressed: e => { slotMouse.dragged = false; if (e.button === Qt.LeftButton && slot.modelData.pinned) { win.dragIdx = slot.index; win.dragStartCoord = win.isVert ? e.y : e.x; } }
                        onPositionChanged: e => { if (win.dragIdx < 0 || !slot.modelData.pinned) return; const delta = (win.isVert ? e.y : e.x) - win.dragStartCoord; if (Math.abs(delta) > 32) { const target = win.dragIdx + (delta > 0 ? 1 : -1); slotMouse.dragged = true; win.movePin(win.dragIdx, target); win.dragIdx = target; } }
                        onReleased: win.dragIdx = -1
                        onClicked: e => {
                            if (slotMouse.dragged) return;
                            if (e.button === Qt.RightButton) { win.settingsMenu = false; win.menuSlotIdx = slot.index + 1; win.menuTarget = (win.menuTarget && win.menuTarget.key === slot.modelData.key) ? null : slot.modelData; }
                            else if (e.button === Qt.MiddleButton) { win.menuTarget = null; win.settingsMenu = false; win.launchItem(slot.modelData); }
                            else { win.menuTarget = null; win.settingsMenu = false; win.activateItem(slot.modelData); }
                        }
                    }
                }
            }
            Rectangle {
                id: forgeDockSlot; visible: win.forgeVisible; implicitWidth: 44; implicitHeight: 44; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 2; border.color: win.forgeCol
                ColumnLayout { anchors.centerIn: parent; spacing: 0; Text { Layout.alignment: Qt.AlignHCenter; text: "󰙪"; color: win.forgeCol; font.family: Theme.font; font.pixelSize: 16 } Text { Layout.alignment: Qt.AlignHCenter; text: Status.forgePct + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 9; font.bold: true } }
                Rectangle { width: Math.max(4, Math.round(36 * Status.forgePct / 100)); height: 3; anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter } color: win.forgeCol }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleSuperDeck("forge") }
            }
            Rectangle { width: win.isVert ? 28 : 2; height: win.isVert ? 2 : 28; Layout.alignment: Qt.AlignCenter; color: Theme.border }
            Repeater {
                model: win.ioItems
                Rectangle {
                    id: ioSlot; required property var modelData; required property int index
                    implicitWidth: 44; implicitHeight: 44; radius: Theme.radiusSm; scale: ioMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    color: ioMouse.containsMouse ? Theme.bgHover : (modelData.active ? Theme.bgAlt : "transparent")
                    border.width: ioMouse.containsMouse || modelData.active ? 2 : 1; border.color: ioMouse.containsMouse ? Theme.cyan : (modelData.active ? Theme.blue : Theme.border)
                    Text { anchors.centerIn: parent; text: ioSlot.modelData.icon; color: ioSlot.modelData.color; font.family: Theme.font; font.pixelSize: 20 }
                    Rectangle { width: ioSlot.modelData.active ? 8 : 4; height: 3; radius: Theme.radiusSm > 0 ? 1 : 0; anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter } color: ioSlot.modelData.color }
                    MouseArea {
                        id: ioMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: { win.hoveredSlotIdx = win.dockItems.length + 1 + ioSlot.index; win.hoveredName = ioSlot.modelData.tip; }
                        onExited: if (win.hoveredSlotIdx === win.dockItems.length + 1 + ioSlot.index) win.hoveredName = ""
                        onClicked: e => {
                            win.menuTarget = null; win.settingsMenu = false; if (e.button === Qt.RightButton) { Status.toggleSuperDeck("zerotrust"); return; }
                            if (ioSlot.modelData.id === "spk") { const m = !win.spkMuted; if (win.spkReady) win.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                            else if (ioSlot.modelData.id === "mic") { const m = !win.micMuted; if (win.micReady) win.source.audio.muted = m; Status.toggleMicMute(m); } else Status.toggleWebcam();
                        }
                        onWheel: wheel => {
                            const d = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            if (ioSlot.modelData.id === "spk") { const v = Math.max(0, Math.min(1, win.spkVol + d)); if (win.spkReady) win.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                            else if (ioSlot.modelData.id === "mic") { const v = Math.max(0, Math.min(1, win.micVol + d)); if (win.micReady) win.source.audio.volume = v; Status.setMicVolume(v); }
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: contextPopup; visible: win.contentShown && win.menuOpen; width: 196; height: menuCol.implicitHeight + 14
        x: win.position === "left" ? (dockBar.x + dockBar.width + 6) : (win.position === "right" ? (dockBar.x - width - 6) : Math.max(8, Math.min(win.width - width - 8, dockBar.x + win.menuSlotIdx * 50 - 40)))
        y: win.position === "top" ? (dockBar.y + dockBar.height + 6) : (win.position === "bottom" ? (dockBar.y - height - 6) : Math.max(8, Math.min(win.height - height - 8, dockBar.y + win.menuSlotIdx * 50 - 20)))
        radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: Theme.blue; HoverHandler { id: menuHover }
        ColumnLayout {
            id: menuCol; anchors { fill: parent; margins: 7 } spacing: 3
            Text { text: win.settingsMenu ? "QUATTRO DOCK" : (win.menuTarget ? win.menuTarget.name : ""); color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            Repeater {
                model: win.settingsMenu ? [
                    { label: (win.position === "bottom" ? "[*] " : "[ ] ") + "Position: Bottom", cmd: "position bottom" }, { label: (win.position === "left" ? "[*] " : "[ ] ") + "Position: Left", cmd: "position left" },
                    { label: (win.position === "right"  ? "[*] " : "[ ] ") + "Position: Right",  cmd: "position right" },  { label: (win.position === "top"  ? "[*] " : "[ ] ") + "Position: Top",  cmd: "position top" },
                    { label: (cfg.autohide ? "[*] " : "[ ] ") + "Auto-Hide Dock", cmd: "autohide toggle" }, { label: (cfg.showAlways !== false ? "[*] " : "[ ] ") + "Show on Tiled Workspaces", cmd: "always toggle" }
                ] : (win.menuTarget ? [
                    { label: "Open / New Window", act: "launch" }, { label: win.menuTarget.pinned ? "Remove from Dock" : "Keep in Dock", act: "pin" },
                    { label: "Uninstall WebApp", act: "unforge", hide: !String(win.menuTarget.key || "").startsWith("sf-webapp-") },
                    { label: "Minimize to Dock", act: "min", hide: win.menuTarget.windows.length === 0 }, { label: "Quit Application", act: "quit", hide: win.menuTarget.windows.length === 0 }
                ].filter(r => !r.hide) : [])
                Rectangle {
                    required property var modelData; Layout.fillWidth: true; implicitHeight: 24; radius: Theme.radiusSm; color: rMouse.containsMouse ? Theme.bgHover : "transparent"
                    Text { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 6 } text: parent.modelData.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                    MouseArea {
                        id: rMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const m = parent.modelData, t = win.menuTarget; win.menuTarget = null; win.settingsMenu = false;
                            if (m.cmd) Status.runDockCmd(m.cmd); else if (m.act === "launch" && t) win.launchItem(t);
                            else if (m.act === "pin" && t) Status.runDockCmd((t.pinned ? "unpin '" : "pin '") + t.key + "'");
                            else if (m.act === "unforge" && t) { win.quitItem(t); Status.removeForge(t.key); }
                            else if (m.act === "min" && t && t.windows.length > 0) Status.runDockCmd("minimize " + t.windows[0].address); else if (m.act === "quit" && t) win.quitItem(t);
                        }
                    }
                }
            }
        }
    }
}
