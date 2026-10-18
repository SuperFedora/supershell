import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Omarchy + COSMIC dynamic workspaces:
// - Occupied workspaces compact to 1..N with zero empty gaps in between.
// - Focused workspace displays its layout glyph (Square = Tiling, Circle = Scrolling, Triangle = Floating);
//   clicking the focused workspace cycles its layout mode (like Super + Y).
// - The strip wraps its Grid in an Item so an elastic pill can be painted BEHIND the cells: two indices
//   travel at different speeds (STYLE_RESEARCH.md §4) and the pill stretches across the gap between them.
Item {
    id: root
    property var monitor: null
    property var bar: null
    property bool vertical: false
    property int thickness: Theme.barHeight
    property int occupiedCount: 1
    property real wheelAccum: 0
    readonly property int cell: 28

    readonly property int activeId: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    readonly property string activeMode: Status.wsModeFor(root.activeId)
    // One active colour for every tiling mode: pure Theme.blue, never a mode-tinted rainbow hue.
    readonly property color activeCol: Theme.blue
    // The pill always paints one standard 26 x (thickness - 8) cell (STYLE_RESEARCH.md §4).
    readonly property int span: 26

    // Dual-index elastic travel: the fast edge leads out, the slow edge catches up, so the pill
    // stretches through the jump and lands exactly on the target cell.
    property int hoverId: 0
    property real idx1: Math.max(0, root.activeId - 1)
    property real idx2: Math.max(0, root.activeId - 1)
    Behavior on idx1 { NumberAnimation { duration: Theme.dur(110); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
    Behavior on idx2 { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }

    // A horizontal bar's strip is exactly one bar tall (every cell lands on the Theme.barHeight / 2
    // centerline); a vertical bar's strip grows along the edge and is only cross-centred.
    implicitWidth: root.vertical ? root.thickness : grid.implicitWidth; width: implicitWidth
    implicitHeight: root.vertical ? grid.implicitHeight : root.thickness; height: implicitHeight

    function modeGlyph(mode) {
        if (mode === "scrolling") return "󰄯"; // Circle = Scrolling
        if (mode === "floating") return "󰐊";  // Triangle = Floating
        return "󱓻";                           // Square = Tiling (dwindle)
    }

    // Workspace layout cycling now lives in the tiling script (no dock command API).
    function toggleTiling(mode) {
        Quickshell.execDetached(["sh", "-c", "~/.local/bin/superbar tiling " + (mode === "back" ? "back" : "cycle")]);
    }

    readonly property var shown: {
        const total = Math.max(root.occupiedCount + 1, root.activeId, 1);
        const list = [];
        for (let i = 1; i <= total; i++) list.push(i);
        return list;
    }

    // ── Elastic active-workspace pill (behind the cells) ──────────────────────────────────────────
    // A SOLID Theme.blue shape, no outline: the glyph on top is Theme.bg for hard contrast.
    Rectangle {
        id: activePill
        readonly property real len: Math.abs(root.idx1 - root.idx2) * root.cell + root.span
        x: root.vertical ? (root.thickness - width) / 2 : Math.min(root.idx1, root.idx2) * root.cell + (root.cell - root.span) / 2
        y: root.vertical ? Math.min(root.idx1, root.idx2) * root.cell + (root.cell - root.span) / 2 : (root.thickness - height) / 2
        width: root.vertical ? root.thickness - 8 : activePill.len
        height: root.vertical ? activePill.len : root.thickness - 8
        radius: Theme.radiusSm
        color: root.activeCol
        border.width: 0
    }
    // Hover preview: a flat theme twin of the same pill, pointing one cell ahead of the cursor.
    Rectangle {
        id: hoverPill
        visible: root.hoverId > 0 && root.hoverId !== root.activeId
        x: root.vertical ? (root.thickness - width) / 2 : (root.hoverId - 1) * root.cell + (root.cell - root.span) / 2
        y: root.vertical ? (root.hoverId - 1) * root.cell + (root.cell - root.span) / 2 : (root.thickness - height) / 2
        width: root.vertical ? root.thickness - 8 : root.span
        height: root.vertical ? root.span : root.thickness - 8
        radius: Theme.radiusSm
        color: Theme.bgHover
        border.width: 0
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
        states: State { name: "on"; when: hoverPill.visible; PropertyChanges { target: hoverPill; opacity: 1 } }
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : Math.max(1, root.shown.length)
        spacing: 0

        Repeater {
            model: root.shown

            Item {
                required property int modelData
                readonly property bool active: modelData === root.activeId
                readonly property bool used: modelData <= root.occupiedCount
                readonly property bool isTrailingEmpty: modelData === root.occupiedCount + 1 && !used

                width: root.vertical ? root.thickness : root.cell
                height: root.vertical ? root.cell : root.thickness

                Text {
                    anchors.centerIn: parent
                    text: parent.active ? root.modeGlyph(root.activeMode) : (parent.isTrailingEmpty ? "+" : String(parent.modelData))
                    // Active glyph sits as dark text on the solid Theme.blue pill; the rest is ink.
                    color: parent.active ? Theme.bg : (parent.used ? Theme.fg : Theme.muted)
                    font.family: Theme.font
                    font.pixelSize: Theme.iconSize - 2
                    font.bold: parent.isTrailingEmpty
                }

                Component.onDestruction: if (root.bar && root.bar.tipOwner === this) root.bar.setBarTip(null, "", false)
                MouseArea {
                    id: wsM
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: {
                        root.hoverId = containsMouse ? parent.modelData : 0;
                        if (root.bar && root.bar.setBarTip) root.bar.setBarTip(parent, parent.active ? ("Workspace " + parent.modelData + " · " + root.activeMode.charAt(0).toUpperCase() + root.activeMode.slice(1)) : (parent.isTrailingEmpty ? "New Workspace" : ("Workspace " + parent.modelData)), containsMouse);
                    }
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => {
                        if (root.bar && root.bar.setBarTip) root.bar.setBarTip(null, "", false);
                        if (parent.active) {
                            root.toggleTiling(e.button === Qt.RightButton ? "back" : "cycle");
                        } else {
                            Hyprland.dispatch("workspace " + parent.modelData);
                        }
                    }
                }
            }
        }

        // Touchpad-friendly scroll accumulator across workspaces
        WheelHandler {
            onWheel: e => {
                root.wheelAccum += e.angleDelta.y;
                if (Math.abs(root.wheelAccum) < 120) return;
                const dir = root.wheelAccum > 0 ? 1 : -1;
                root.wheelAccum = 0;
                if (dir > 0) {
                    if (root.activeId > 1) Hyprland.dispatch("workspace r-1");
                } else {
                    if (root.activeId <= root.occupiedCount) Hyprland.dispatch("workspace r+1");
                }
            }
        }
    }

    Process {
        id: compactProc
        command: ["bash", "-c",
            "clients=\"$(hyprctl clients -j 2>/dev/null)\" || exit 0\n" +
            "active=\"$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')\"\n" +
            "mapfile -t occ < <(jq -r '[.[] | select(.workspace.id > 0 and .mapped) | .workspace.id] | unique | .[]' <<<\"$clients\")\n" +
            "n=\"${#occ[@]}\"\n" +
            "batch=\"\"\n" +
            "target_active=\"$active\"\n" +
            "shifted_into_active=0\n" +
            "for i in \"${!occ[@]}\"; do\n" +
            "    old=\"${occ[$i]}\"\n" +
            "    new=$((i + 1))\n" +
            "    if [ \"$old\" -ne \"$new\" ]; then\n" +
            "        while IFS= read -r addr; do\n" +
            "            [ -n \"$addr\" ] && batch+=\"dispatch movetoworkspacesilent ${new},address:${addr};\"\n" +
            "        done < <(jq -r --argjson w \"$old\" '.[] | select(.workspace.id == $w and .mapped) | .address' <<<\"$clients\")\n" +
            "        [ \"$active\" -eq \"$old\" ] && target_active=\"$new\"\n" +
            "        [ \"$active\" -eq \"$new\" ] && shifted_into_active=1\n" +
            "    fi\n" +
            "done\n" +
            "max_ws=$((n + 1))\n" +
            "[ \"$target_active\" -gt \"$max_ws\" ] && target_active=\"$max_ws\"\n" +
            "if [ \"$target_active\" -ne \"$active\" ] || [ \"$shifted_into_active\" -eq 1 ]; then\n" +
            "    batch+=\"dispatch workspace ${target_active};\"\n" +
            "fi\n" +
            "[ -n \"$batch\" ] && hyprctl --batch \"$batch\" >/dev/null 2>&1\n" +
            "echo \"$n\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10);
                if (!isNaN(n) && n >= 0) root.occupiedCount = n;
            }
        }
    }

    Timer {
        id: syncTimer
        interval: 60
        running: true
        repeat: false
        onTriggered: compactProc.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const e = event.name;
            if (e === "openwindow" || e === "closewindow" || e === "movewindow" ||
                e === "movewindowv2" || e === "workspace" || e === "workspacev2" ||
                e === "destroyworkspace" || e === "destroyworkspacev2") {
                syncTimer.restart();
            }
        }
    }
}
