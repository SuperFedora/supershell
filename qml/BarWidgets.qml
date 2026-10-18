import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// BarWidgets — the SuperBar widget library. One instance renders exactly one widgetId for any of the
// 4 edges: `vertical` flips the flow for left/right islands and `bar` is the owning SuperBar engine
// (screen, popups, helpers). Every widget is an inline Component picked by the Loader below, so
// SuperBar.qml stays a pure edge/style/hide engine that only renders edges[].widgets.
Flow {
    id: w
    property string widgetId: ""; property bool vertical: false; property var engine: null; property string submap: ""
    readonly property var monitor: (w.engine && w.engine.modelData) ? Hyprland.monitorFor(w.engine.modelData) : null
    readonly property int wsId: w.monitor && w.monitor.activeWorkspace ? w.monitor.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property int cross: Theme.barHeight
    readonly property bool ledge: !w.vertical && !!w.engine && w.engine.edge === "top"
    flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function toggle(id, itemRef) { if (w.engine) w.engine.toggleFlyout(id, itemRef); }
    function calendar(id, itemRef) { if (w.engine) w.engine.toggleCalendar(id, itemRef); }
    function tip(itemRef, txt, on) { if (w.engine && w.engine.setBarTip) w.engine.setBarTip(itemRef, txt, on); }
    function notifs() { const next = !Status.notifDrawerOpen; Status.notifDrawerOpen = next; if (Status.notifAction) Status.notifAction("setCenterOpen", next); Status.playSfx("click"); }
    Connections { target: Hyprland; function onRawEvent(event) { if (event.name === "submap") w.submap = event.data; } }
    Loader {
        id: body
        sourceComponent: w.widgetId === "|" ? divC : w.widgetId === "telemetry" ? teleC : w.widgetId === "window" ? winC : w.widgetId === "media" ? mediaC : w.widgetId === "pinned" ? pinC
            : w.widgetId === "launcher" ? launchC : w.widgetId === "workspaces" ? wsC : w.widgetId === "tools" ? toolsC : w.widgetId === "clock" ? clockC
            : w.widgetId === "forge" ? forgeC : w.widgetId === "tray" ? trayC : w.widgetId === "notifs" ? notifC : null
    }
    Component { id: divC; Item { implicitWidth: w.vertical ? w.cross : 7; implicitHeight: w.vertical ? 7 : w.cross; Rectangle { anchors.centerIn: parent; width: w.vertical ? 14 : 1; height: w.vertical ? 1 : 14; color: Theme.border } } }
    // telemetry: compact fixed-width icon chip (launches btop on L-click, cycles mode on R-click) — zero number jitter.
    Component { id: teleC
        Rectangle {
            implicitWidth: w.vertical ? w.cross : 28; implicitHeight: w.vertical ? 28 : w.cross; radius: Theme.radiusSm; color: "transparent"
            Rectangle {
                anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 26; height: w.vertical ? 26 : w.cross - 8; radius: Theme.radiusSm; color: teleM.containsMouse ? Theme.bgHover : "transparent"
                Text { anchors.centerIn: parent; text: "󰓅"; color: (Status.cpu >= 85 || Status.tempC >= 85) ? Theme.red : ((Status.cpu >= 70 || Status.tempC >= 70) ? Theme.yellow : (teleM.containsMouse ? Theme.cyan : Theme.fgDim)); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
            }
            MouseArea { id: teleM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onContainsMouseChanged: w.tip(parent, "CPU " + Status.cpu + "% · RAM " + Status.mem + "% · " + Status.tempC + "°C", containsMouse); onClicked: e => { if (e.button === Qt.RightButton) { w.run("~/.local/bin/superfedora mode cycle && qs ipc call status refresh"); Status.playSfx("toggle"); } else w.run("~/.local/bin/xdg-terminal-exec --monitor"); } }
        } }
    // window: focused Hyprland window class + title for this monitor (rotates -90° on vertical bars).
    Component { id: winC
        Rectangle {
            id: winBox; readonly property var fc: Hyprland.focusedClient; readonly property var here: (Status.clients || []).filter(c => c.workspace && c.workspace.id === w.wsId)
            readonly property var cur: (winBox.fc && winBox.fc.workspace && winBox.fc.workspace.id === w.wsId) ? winBox.fc : (winBox.here.length ? winBox.here[0] : null)
            implicitWidth: w.vertical ? w.cross : 220; implicitHeight: w.vertical ? 148 : w.cross; width: implicitWidth; height: implicitHeight; radius: Theme.radiusSm; color: winM.containsMouse ? Theme.bgHover : "transparent"
            Text { id: winTxt; anchors.centerIn: parent; rotation: w.vertical ? -90 : 0; width: (w.vertical ? parent.height : parent.width) - 12; horizontalAlignment: w.vertical ? Text.AlignHCenter : Text.AlignLeft; elide: Text.ElideRight; text: winBox.cur ? (winBox.cur.class + "  ·  " + (winBox.cur.title || "")) : "Desktop"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
            MouseArea { id: winM; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: w.tip(winBox, winBox.cur ? (winBox.cur.class + (winBox.cur.title ? " — " + winBox.cur.title : "")) : "Desktop", containsMouse) }
        } }
    // media: fixed 3-cell MPRIS transport (prev / play-pause / next) — zero bar resize, horizontal or vertical.
    Component { id: mediaC
        Flow {
            id: mediaBox; flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
            readonly property var players: Mpris.players ? Mpris.players.values : []
            readonly property var player: (mediaBox.players.find(p => p.playbackStatus === "Playing") || mediaBox.players[0] || null)
            readonly property bool playing: !!mediaBox.player && mediaBox.player.playbackStatus === "Playing"
            function act(a) {
                if (!mediaBox.player) { w.run("~/.local/bin/xdg-terminal-exec --audio"); return; }
                if (a === "prev") mediaBox.player.previous(); else if (a === "next") mediaBox.player.next(); else if (mediaBox.playing) mediaBox.player.pause(); else mediaBox.player.play(); }
            Repeater {
                model: [{ g: "󰒮", a: "prev", p: false }, { g: mediaBox.playing ? "󰏤" : (mediaBox.player ? "󰐊" : "󰎆"), a: "toggle", p: mediaBox.playing }, { g: "󰒭", a: "next", p: false }]
                Item {
                    required property var modelData; width: w.vertical ? w.cross : 28; height: w.vertical ? 28 : w.cross
                    Rectangle {
                        anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 26; height: w.vertical ? 26 : w.cross - 8; radius: Theme.radiusSm; color: modelData.p ? Theme.blue : (mbM.containsMouse ? Theme.bgHover : "transparent")
                        Text { anchors.centerIn: parent; text: modelData.g; color: modelData.p ? Theme.bg : (mbM.containsMouse ? Theme.cyan : (mediaBox.player ? Theme.fg : Theme.fgDim)); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
                        MouseArea { id: mbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onContainsMouseChanged: w.tip(parent, modelData.a === "prev" ? "Previous Track" : (modelData.a === "next" ? "Next Track" : (mediaBox.playing ? "Pause" : "Play")), containsMouse); onClicked: e => { if (e.button === Qt.RightButton) Status.openSettings("system"); else mediaBox.act(modelData.a); } }
                    }
                }
            }
        } }
    // pinned: Launchpad toggle + fixed pinned launchers (constant size, horizontal or vertical).
    Component { id: pinC
        Flow {
            id: pinBox; flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
            readonly property var topClient: (Status.clients || []).find(c => c.workspace && c.workspace.id === w.wsId && c.focusHistoryID === 0) || (Status.clients || []).find(c => c.focusHistoryID === 0) || ((Status.clients || []).length === 1 ? Status.clients[0] : null)
            readonly property string focusCls: String((Hyprland.focusedClient && Hyprland.focusedClient.class) || (pinBox.topClient && pinBox.topClient.class) || "").toLowerCase()
            readonly property string focusAddr: String((Hyprland.focusedClient && Hyprland.focusedClient.address) || (pinBox.topClient && pinBox.topClient.address) || "")
            function glyphFor(id) { const k = String(id || "").toLowerCase(); return k.includes("kitty") || k.includes("term") || k.includes("wezterm") || k.includes("foot") || k.includes("konsole") || k.includes("ptyxis") ? "󰆍" : k.includes("firefox") || k.includes("brave") || k.includes("chrom") || k.includes("zen") ? "󰈹" : k.includes("yazi") || k.includes("files") || k.includes("nautilus") || k.includes("thunar") || k.includes("dolphin") ? "󰉋" : k.includes("agy") || k.includes("antigravity") || k.includes("code") || k.includes("zed") || k.includes("nvim") || k.includes("kate") ? "󰨞" : k.includes("btop") || k.includes("monitor") || k.includes("nvtop") ? "󰓅" : k.includes("mpv") || k.includes("vlc") || k.includes("spotify") || k.includes("amberol") ? "󰎆" : k.includes("zathura") || k.includes("pdf") || k.includes("okular") ? "󰈦" : k.includes("imv") || k.includes("gimp") || k.includes("loupe") ? "󰋩" : k.includes("thunderbird") || k.includes("mail") ? "󰇮" : "󰣆"; }
            function clientsFor(cls) { const k = String(cls || "").toLowerCase(), all = (Status.clients || []).filter(c => c.workspace && String(c.class || "").toLowerCase() === k), here = all.filter(c => c.workspace.id === w.wsId); return here.length ? here : all; }
            readonly property var items: {
                const map = Object.assign({}, Status.localAppsMap || {});
                if (DesktopEntries.applications && DesktopEntries.applications.values) for (const d of DesktopEntries.applications.values) if (d && d.id) { const dk = String(d.id).replace(/\.desktop$/i, "").toLowerCase(); if (!map[dk]) map[dk] = d; if (d.startupClass && !map[String(d.startupClass).toLowerCase()]) map[String(d.startupClass).toLowerCase()] = d; }
                const seen = {}, out = [], put = (id, app, cls, pinned) => {
                    const clsKey = String(cls || id), list = pinBox.clientsFor(clsKey), cl = list[0] || null, act = list.length > 0 && (pinBox.focusCls === clsKey.toLowerCase() || (app && pinBox.focusCls === String(app.id || "").toLowerCase()));
                    out.push({ id: id, cls: clsKey, name: (app && app.name) || id, glyph: pinBox.glyphFor(clsKey || id), app: app || null, pinned: pinned, running: list.length > 0, count: list.length, active: act, address: cl ? (cl.address || "") : "", addrs: list.map(x => x.address).filter(Boolean) }); };
                for (const a of ((Status.superbarConfig && Status.superbarConfig.pinned) || [])) { const id = String(a), k = id.toLowerCase(), shortK = k.split(".").pop() || k, app = map[k] || map[shortK] || null; if (seen[k] || seen[shortK]) continue; seen[k] = true; seen[shortK] = true; put(id, app, (app && (app.wmClass || app.startupClass)) || shortK, true); }
                return out;
            }
            Item { width: w.vertical ? w.cross : 28; height: w.vertical ? 28 : w.cross
                Rectangle { anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 26; height: w.vertical ? 26 : w.cross - 8; radius: Theme.radiusSm; color: Status.appGridOpen ? Theme.blue : (lpM.containsMouse ? Theme.bgHover : "transparent")
                    Text { anchors.centerIn: parent; text: "󰀻"; color: Status.appGridOpen ? Theme.bg : (lpM.containsMouse ? Theme.cyan : Theme.blue); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
                    MouseArea { id: lpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onContainsMouseChanged: w.tip(parent, "Applications", containsMouse); onClicked: e => { if (e.button === Qt.RightButton) Status.toggleSettings("apps"); else { Status.appGridOpen = !Status.appGridOpen; Status.playSfx("click"); } } } } }
            Item { width: w.vertical ? w.cross : 5; height: w.vertical ? 5 : w.cross; Rectangle { anchors.centerIn: parent; width: w.vertical ? 14 : 1; height: w.vertical ? 1 : 14; color: Theme.border } }
            Repeater {
                model: pinBox.items
                Item {
                    required property var modelData; width: w.vertical ? w.cross : 28; height: w.vertical ? 28 : w.cross
                    Rectangle {
                        anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 26; height: w.vertical ? 26 : w.cross - 8; radius: Theme.radiusSm; transformOrigin: Item.Center
                        scale: pinM.pressed ? 0.90 : (pinM.containsMouse ? 1.08 : 1.0); color: modelData.active ? Theme.blue : (pinM.containsMouse ? Theme.bgHover : (modelData.running ? Theme.bgAlt : "transparent"))
                        Text { anchors.centerIn: parent; text: modelData.glyph; color: modelData.active ? Theme.bg : (pinM.containsMouse ? Theme.cyan : (modelData.running ? Theme.blue : Theme.fgDim)); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
                        Behavior on scale { NumberAnimation { duration: Theme.dur(150); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                    }
                    Rectangle { visible: modelData.running && !modelData.active; width: w.vertical ? 2 : (modelData.count > 1 ? 8 : 4); height: w.vertical ? (modelData.count > 1 ? 8 : 4) : 2; radius: 1; color: Theme.blue; anchors.centerIn: parent; anchors.verticalCenterOffset: w.vertical ? 0 : (w.cross / 2 - 2); anchors.horizontalCenterOffset: w.vertical ? (w.cross / 2 - 2) : 0 }
                    MouseArea {
                        id: pinM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; onContainsMouseChanged: w.tip(parent, modelData.name, containsMouse)
                        onClicked: e => {
                            const m = modelData, k = String(m.id || "").toLowerCase(); Status.playSfx("click");
                            if (e.button === Qt.MiddleButton) { if (m.address) Hyprland.dispatch("closewindow address:" + m.address); }
                            else if (e.button === Qt.RightButton) Status.runSuperBarCmd("pin-toggle " + m.id);
                            else if (m.running && m.addrs.length > 0) { const idx = m.active ? ((m.addrs.indexOf(pinBox.focusAddr) + 1) % m.addrs.length) : 0; Hyprland.dispatch("focuswindow address:" + m.addrs[Math.max(0, idx)]); }
                            else if (k === Status.defTerminal || k === Status.defFiles || k === Status.defEditor || k === Status.defMonitor) w.run("~/.local/bin/xdg-terminal-exec" + (k === Status.defFiles ? " --files" : (k === Status.defEditor ? " --editor" : (k === Status.defMonitor ? " --monitor" : ""))));
                            else if (m.app && typeof m.app.execute === "function" && !m.app.runInTerminal) m.app.execute();
                            else if (m.app && m.app.runInTerminal) w.run("~/.local/bin/xdg-terminal-exec --class floating-term --title '" + m.name.replace(/'/g, "") + "' -e " + (m.app.execCmd || k));
                            else w.run("gtk-launch '" + m.id + "' 2>/dev/null || " + m.cls.toLowerCase()); } }
                }
            }
        }
    }
    // tools: colour / shot / record / ocr / qr / clip / calc / zoom / nightlight / mode / idle chips behind an expander.
    Component { id: toolsC
        Rectangle {
            id: toolsBox; readonly property string sc: "~/.local/bin/superbar capture "; readonly property string zs: "~/.local/bin/superbar zoom ";
            readonly property string fm: (w.engine && w.engine.flyoutMode) ? w.engine.flyoutMode : ""
            readonly property var all: [
                { id: "calc", txt: "󰪚", active: false, tip: "Calculator" }, { id: "clip", txt: "󰅌", active: false, tip: "Clipboard" },
                { id: "qr", txt: "󰐲", active: false, tip: "QR Code Tool" }, { id: "shot", txt: "󰹑", active: false, tip: "Screenshot" },
                { id: "ocr", txt: "󰗊", active: false, tip: "OCR Text Grab" }, { id: "color", txt: "󰈊", active: false, tip: "Color Picker" },
                { id: "record", txt: "󰻂", active: Status.screenRecording, tip: "Screen Recorder" }, { id: "nightlight", txt: "󰖔", active: Status.nightLightRunning, tip: "Night Light" + (Status.nightLightRunning ? " · " + Status.nightLightTemp + "K" : "") },
                { id: "zoom", txt: "󰍉", active: Status.cursorZoom > 1.05, tip: "Magnifier" }, { id: "mode", txt: "󰓅", active: Status.workstationMode !== "balanced", tip: "Power Mode · " + Status.workstationMode },
                { id: "idle", txt: Status.idleMode === "lock" ? "󰌾" : (Status.idleMode === "screensaver" ? "󰅶" : "󰒲"), active: Status.idleMode !== "poweroff", tip: "Idle · " + Status.idleMode } ]
            readonly property var tools: {
                const hid = Array.isArray(Status.superbarConfig && Status.superbarConfig.hiddenTools) ? Status.superbarConfig.hiddenTools : [];
                return toolsBox.all.filter(t => hid.indexOf(t.id) < 0);
            }
            function trigger(id, rightBtn, itemRef) {
                if (id === "idle") { if (rightBtn) Status.openSettings("power"); else Status.toggleIdle(); }
                else if (id === "record") { if (rightBtn) { if (w.engine) w.engine.closePopups(); w.run(toolsBox.sc + "record-region"); } else w.toggle("record", itemRef); }
                else if (id === "shot") { if (w.engine) w.engine.closePopups(); w.run(toolsBox.sc + (rightBtn ? "screen" : "region")); }
                else if (id === "color" || id === "ocr") { if (w.engine) w.engine.closePopups(); w.run(toolsBox.sc + id); }
                else if (id === "qr") { if (rightBtn) { if (w.engine) w.engine.closePopups(); w.run(toolsBox.sc + "qr"); } else w.toggle("qr", itemRef); }
                else if (id === "clip") { if (rightBtn) w.run('~/.local/bin/cliphist wipe && notify-send -a SuperFedora Clipboard "Cleared clipboard history"'); else w.toggle("clip", itemRef); }
                else if (id === "calc") { if (rightBtn) Status.copyText(w.engine ? w.engine.calcOut : ""); else w.toggle("calc", itemRef); }
                else if (id === "zoom") { if (rightBtn) { w.run(toolsBox.zs + "in"); Status.cursorZoom = Math.min(6, Math.max(1, (Status.cursorZoom || 1) * 1.25)); } else if (Status.cursorZoom > 1.05) { w.run(toolsBox.zs + "reset"); Status.cursorZoom = 1.0; } else { w.run(toolsBox.zs + "in"); Status.cursorZoom = 1.25; } }
                else if (id === "nightlight") { if (rightBtn) { const on = !Status.nightLightRunning; Status.nightLightRunning = on; w.run("~/.local/bin/supersettings apply nightlight " + (on ? (Status.nightLightTemp || 4000) : "off")); Status.playSfx("toggle"); } else w.toggle("nightlight", itemRef); }
                else if (id === "mode") { if (rightBtn) w.run("~/.local/bin/superfedora mode cycle && qs ipc call status refresh"); else w.toggle("battery", itemRef); }
                autoHide.restart(); }
            implicitWidth: w.vertical ? w.cross : toolsRow.implicitWidth + 4; implicitHeight: w.vertical ? toolsRow.implicitHeight + 4 : w.cross; color: "transparent"
            HoverHandler { id: toolHover; onHoveredChanged: if (hovered) autoHide.stop(); else if (Status.centerToolsOpen) autoHide.restart(); } Timer { id: autoHide; interval: 6000; onTriggered: if (Status.centerToolsOpen && !toolHover.hovered && (!w.engine || !w.engine.popupOpen)) Status.centerToolsOpen = false }
            Flow {
                id: toolsRow; anchors.centerIn: parent; flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: 0
                Repeater {
                    model: toolsBox.tools
                    Item {
                        id: tSlot; required property var modelData; readonly property bool open: toolsBox.fm === modelData.id || (modelData.id === "mode" && toolsBox.fm === "battery")
                        readonly property bool shown: Status.centerToolsOpen || modelData.active; visible: width > 0.5 && height > 0.5; clip: true
                        width: w.vertical ? w.cross : (shown ? 29 : 0); height: w.vertical ? (shown ? 29 : 0) : w.cross; opacity: shown ? 1 : 0
                        Behavior on width { NumberAnimation { duration: Theme.dur(tSlot.shown ? 260 : 180); easing.type: Easing.BezierSpline; easing.bezierCurve: tSlot.shown ? Theme.curveSpatial : Theme.curveDecel } }
                        Behavior on height { NumberAnimation { duration: Theme.dur(tSlot.shown ? 260 : 180); easing.type: Easing.BezierSpline; easing.bezierCurve: tSlot.shown ? Theme.curveSpatial : Theme.curveDecel } }
                        Behavior on opacity { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
                        Component.onCompleted: if (w.engine && ["calc", "clip", "qr", "record", "nightlight"].indexOf(tSlot.modelData.id) >= 0) w.engine.iconSlots[tSlot.modelData.id] = tSlot
                        Rectangle {
                            anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 26; height: w.vertical ? 26 : w.cross - 8; radius: Theme.radiusSm; transformOrigin: Item.Center; scale: !tSlot.shown ? 0.65 : (ctM.pressed ? 0.90 : (ctM.containsMouse ? 1.08 : 1.0))
                            color: (tSlot.modelData.active || tSlot.open) ? Theme.blue : (ctM.containsMouse ? Theme.bgHover : "transparent"); border.width: 0
                            Text { anchors.centerIn: parent; text: tSlot.modelData.txt; color: (tSlot.modelData.active || tSlot.open) ? Theme.bg : (ctM.containsMouse ? Theme.cyan : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
                            Behavior on scale { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                        }
                        MouseArea { id: ctM; anchors.fill: parent; enabled: tSlot.shown; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onContainsMouseChanged: w.tip(tSlot, tSlot.modelData.tip, containsMouse); onClicked: e => { w.tip(null, "", false); toolsBox.trigger(tSlot.modelData.id, e.button === Qt.RightButton, tSlot); } }
                    }
                }
                Item { width: w.vertical ? w.cross : 22; height: w.vertical ? 22 : w.cross
                    Rectangle { anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 22; height: w.vertical ? 22 : w.cross - 8; radius: Theme.radiusSm; color: ttM.containsMouse ? Theme.bgHover : "transparent"; border.width: 0
                        Text { anchors.centerIn: parent; text: Status.centerToolsOpen ? (w.vertical ? "▴" : "▸") : (w.vertical ? "▾" : "◂"); color: Status.centerToolsOpen ? Theme.blue : (ttM.containsMouse ? Theme.cyan : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 } }
                    MouseArea { id: ttM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: w.tip(parent, "Tools", containsMouse); onClicked: { w.tip(null, "", false); Status.centerToolsOpen = !Status.centerToolsOpen; Status.playSfx("click"); if (Status.centerToolsOpen) autoHide.restart(); else autoHide.stop(); } } }
            }
        }
    }
    // launcher: SuperFedora mark (opens SuperSettings) + active hyprland submap hint.
    Component { id: launchC
        Flow {
            flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
            BarLabel { id: sfMark; vertical: w.vertical; implicitWidth: w.vertical ? w.cross : 26; text: "󰣛"; color: Status.settingsOpen ? Theme.cyan : Theme.blue; pixelSize: Theme.iconSize - 2; bar: w.engine; tooltip: "SuperSettings"; onClicked: Status.toggleSettings("home") }
            Row { id: launchRow; visible: w.submap !== "" && !w.vertical; height: w.cross; BarLabel { text: "󰌌 " + w.submap.toUpperCase() + "  ·  Esc to exit"; color: Theme.cyan; pixelSize: Theme.fontSize; bold: true; onClicked: Hyprland.dispatch("submap reset") } } } }
    // workspaces: dynamic hyprland workspace strip (already orientation aware).
    Component { id: wsC; Workspaces { monitor: w.monitor; thickness: w.cross; vertical: w.vertical; bar: w.engine } }
    // clock: date + time (stacks HH/mm on vertical bars), L/R click opens the date/time popover adjacent to the clock.
    Component { id: clockC
        BarLabel {
            id: clk; property date now: new Date(); vertical: w.vertical; bar: w.engine; tooltip: Qt.formatDateTime(clk.now, "dddd, MMMM d, yyyy") + (Status.localTz ? " · " + Status.localTz : "")
            Component.onCompleted: if (w.engine) w.engine.iconSlots["date"] = clk
            Timer { interval: Status.clockSeconds ? 1000 : 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clk.now = new Date() }
            pixelSize: w.vertical ? Theme.fontSize - 2 : Theme.fontSize; bold: true; color: (w.engine && (w.engine.calendarMode === "date" || w.engine.calendarMode === "time")) ? Theme.blue : Theme.fg
            text: w.vertical ? Qt.formatDateTime(clk.now, Status.clock24h ? "HH\nmm" : "hh\nmm") : Qt.formatDateTime(clk.now, "ddd, MMM d   " + (Status.clock24h ? (Status.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Status.clockSeconds ? "h:mm:ss AP" : "h:mm AP")))
            onClicked: w.calendar("date", clk); onRightClicked: w.calendar("time", clk)
        } }
    // forge: SuperForge progress chip. The detail popup lives on panels/ForgeRail.qml; the chip drives Status.forgeShown.
    Component { id: forgeC
        Rectangle {
            id: chip; visible: Status.forgeBusy || Status.forgeRecent; readonly property bool open: Status.forgeShown
            readonly property color col: Status.forgeState === "error" ? Theme.red : Theme.blue
            readonly property real pct: Math.max(0, Math.min(100, Status.forgePct)) / 100
            readonly property int cur: Status.forgeBusy ? (Status.forgeDone.length + 1) : Math.max(1, Status.forgeDone.length)
            readonly property int total: Status.forgeBusy ? (Status.forgeDone.length + 1 + Status.forgeQueue.length) : Math.max(1, Status.forgeDone.length + Status.forgeQueue.length)
            function setOpen(v) { Status.forgeShown = v; }
            implicitWidth: w.vertical ? w.cross : Math.min(240, forgeRow.implicitWidth + 14); implicitHeight: w.vertical ? 28 : w.cross; radius: Theme.radiusSm; clip: true; color: chipM.containsMouse || chip.open ? Theme.bgHover : Theme.bgAlt; border.width: 0
            Rectangle { width: w.vertical ? parent.width : Math.round(parent.width * chip.pct); height: w.vertical ? Math.round(parent.height * chip.pct) : parent.height; anchors.bottom: parent.bottom; color: chip.col; opacity: 0.16; Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
            Rectangle { visible: !w.vertical; width: Math.round(parent.width * chip.pct); height: 2; anchors { left: parent.left; bottom: parent.bottom } color: chip.col; Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
            Row {
                id: forgeRow; anchors.centerIn: parent; spacing: 5
                Text { text: Status.forgeState === "error" ? "󰅚" : (!Status.forgeBusy ? "󰄬" : "󰙪"); color: chip.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                Text { visible: !w.vertical; width: Math.min(implicitWidth, 96); elide: Text.ElideRight; text: Status.forgeTarget || "forging"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                Text { visible: !w.vertical; text: Status.forgePct + "%"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                Rectangle { visible: !w.vertical && chip.total > 1; implicitWidth: fBadge.implicitWidth + 8; implicitHeight: 15; radius: 3; color: Theme.blue; Text { id: fBadge; anchors.centerIn: parent; text: chip.cur + "/" + chip.total; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 5; font.bold: true } }
                Rectangle { visible: !w.vertical; implicitWidth: 15; implicitHeight: 15; radius: 3; color: stopM.containsMouse ? Theme.red : "transparent"; Text { anchors.centerIn: parent; text: "×"; color: stopM.containsMouse ? Theme.bg : (Status.forgeBusy ? Theme.red : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: stopM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { chip.setOpen(false); if (Status.forgeBusy) Status.stopForge(); else Status.dismissForgeBanner(); } } }
            }
            MouseArea { id: chipM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: w.tip(chip, "SuperForge · " + (Status.forgeTarget || "Idle") + " (" + Status.forgePct + "%)", containsMouse); onClicked: { w.tip(null, "", false); chip.setOpen(!chip.open); Status.playSfx("click"); } }
            HoverHandler { onHoveredChanged: { if (hovered) { holdTimer.stop(); popTimer.restart(); } else { popTimer.stop(); if (chip.open) holdTimer.restart(); } } }
            Timer { id: popTimer; interval: 320; onTriggered: if (chipM.containsMouse) chip.setOpen(true) }
            Timer { id: holdTimer; interval: 260; onTriggered: if (!chipM.containsMouse) chip.setOpen(false) }
            onVisibleChanged: if (!visible) chip.setOpen(false)
        }
    }
    // tray: StatusNotifier items in a collapsible pocket drawer (horizontal or vertical).
    Component { id: trayC
        Flow {
            readonly property bool open: !w.engine || w.engine.trayOpen
            flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: 2
            Item { id: trayClip; clip: true; visible: width > 0.5 && height > 0.5; width: w.vertical ? w.cross : (parent.open ? trayRow.implicitWidth : 0); height: w.vertical ? (parent.open ? trayRow.implicitHeight : 0) : w.cross; opacity: parent.open ? 1 : 0
                Behavior on width { NumberAnimation { duration: Theme.dur(trayClip.parent.open ? 260 : 180); easing.type: Easing.BezierSpline; easing.bezierCurve: trayClip.parent.open ? Theme.curveSpatial : Theme.curveDecel } }
                Behavior on height { NumberAnimation { duration: Theme.dur(trayClip.parent.open ? 260 : 180); easing.type: Easing.BezierSpline; easing.bezierCurve: trayClip.parent.open ? Theme.curveSpatial : Theme.curveDecel } }
                Behavior on opacity { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
                Tray { id: trayRow; x: w.vertical ? 0 : (trayClip.width - width); y: w.vertical ? (trayClip.height - height) : 0; bar: w.engine; vertical: w.vertical } }
            Item { visible: trayRow.count > 0; width: w.vertical ? w.cross : 22; height: w.vertical ? 22 : w.cross
                Rectangle { anchors.centerIn: parent; width: w.vertical ? w.cross - 8 : 22; height: w.vertical ? 22 : w.cross - 8; radius: Theme.radiusSm; color: ptM.containsMouse ? Theme.bgHover : "transparent"; border.width: 0
                    Text { anchors.centerIn: parent; text: (w.engine && w.engine.trayOpen) ? (w.vertical ? "▴" : "▸") : (w.vertical ? "▾" : "◂"); color: (w.engine && w.engine.trayOpen) ? Theme.blue : (ptM.containsMouse ? Theme.cyan : Theme.fgDim); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 } }
                MouseArea { id: ptM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: w.tip(parent, "System Tray", containsMouse); onClicked: { w.tip(null, "", false); if (w.engine) w.engine.trayOpen = !w.engine.trayOpen; Status.playSfx("click"); if (w.engine && w.engine.trayOpen) trayAuto.restart(); else trayAuto.stop(); } } }
            HoverHandler { id: trayHover; onHoveredChanged: { if (hovered) trayAuto.stop(); else if (w.engine && w.engine.trayOpen) trayAuto.restart(); } }
            Timer { id: trayAuto; interval: 6000; onTriggered: if (w.engine && w.engine.trayOpen && !trayHover.hovered) w.engine.trayOpen = false } } }
    // notifs: notification bell (click opens the right-side drawer, right click toggles DND).
    Component { id: notifC
        Flow {
            flow: w.vertical ? Flow.TopToBottom : Flow.LeftToRight; spacing: w.ledge ? 7 : 0
            Item { visible: w.ledge; width: 1; height: w.cross; Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: Theme.border } }
            BarLabel {
                id: nBell; vertical: w.vertical; implicitWidth: w.vertical ? w.cross : 26; implicitHeight: w.vertical ? 26 : w.cross; bold: Status.dnd || Status.notifUnread > 0 || Status.notifDrawerOpen; bar: w.engine; tooltip: Status.dnd ? "Notifications · Do Not Disturb" : (Status.notifUnread > 0 ? "Notifications · " + Status.notifUnread + " Unread" : "Notifications")
                Component.onCompleted: if (w.engine) w.engine.iconSlots["notifs"] = nBell
                color: (Status.dnd || Status.notifUnread > 0 || Status.notifDrawerOpen) ? Theme.blue : (hovered ? Theme.cyan : Theme.fgDim)
                text: Status.dnd ? "󰂛" : (Status.notifUnread > 0 ? "󰂞" : "󰂚")
                onClicked: w.notifs(); onRightClicked: { if (Status.notifAction) Status.notifAction("toggleDnd"); Status.playSfx("toggle"); }
            } } }
}
