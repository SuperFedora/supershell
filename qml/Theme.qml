pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string theme: "12-cobalt"
    property string themeName: "Cobalt"
    property string mode: "dark"
    property bool nightlight: false
    property color bg: "#1a1b26"
    property color bgAlt: "#24283b"
    property color bgHover: "#292e42"
    property color border: "#414868"
    property color fg: "#c0caf5"
    property color fgDim: "#a9b1d6"
    property color muted: "#565f89"
    property color blue: "#7aa2f7"
    property color cyan: "#bcd3ff"
    readonly property color accent: root.blue
    readonly property color primary: root.cyan
    readonly property color green: root.mode === "light" ? "#15803d" : "#9ece6a"
    readonly property color ok: root.green
    readonly property color yellow: root.mode === "light" ? "#b45309" : "#e0af68"
    readonly property color warning: root.yellow
    readonly property color orange: root.mode === "light" ? "#c2410c" : "#ff9e64"
    readonly property color red: root.mode === "light" ? "#be123c" : "#f7768e"
    readonly property color danger: root.red
    readonly property color magenta: root.mode === "light" ? "#7e22ce" : "#bb9af7"
    readonly property string font: "JetBrainsMono Nerd Font"
    property int fontSize: 14
    readonly property int iconSize: root.fontSize + 4
    readonly property int barHeight: 36
    readonly property int pad: 14
    property string corners: "square"
    property int radius: 0
    property int radiusSm: 0
    property real barOpacity: 1.0
    property real _lockUntil: 0

    // ── M3-Expressive motion tokens (STYLE_RESEARCH.md §1) ──────────────────────────────────────
    // One gate at the token layer: Theme.animEnabled=false collapses every duration to 0 so
    // bindings stay intact instead of needing conditionals at each of the ~90 call sites.
    property bool animEnabled: true
    function dur(ms) { return root.animEnabled ? ms : 0; }
    // Qt Easing.BezierSpline control points, already in its native list<real> form: three points
    // per segment (control1, control2, end), trailing 1,1. M3-Expressive overshoots because y > 1.
    readonly property list<real> curveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1]
    readonly property list<real> curveSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
    readonly property list<real> curveDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> curveStandard: [0.2, 0, 0, 1, 1, 1]

    readonly property var _names: ({
        "01-crimson": "Crimson", "02-scarlet": "Scarlet", "03-ember": "Ember", "04-amber": "Amber",
        "05-topaz": "Topaz", "06-citrine": "Citrine", "07-peridot": "Peridot", "08-emerald": "Emerald",
        "09-verdant": "Verdant", "10-lagoon": "Lagoon", "11-glacier": "Glacier", "12-cobalt": "Cobalt",
        "13-indigo": "Indigo", "14-violet": "Violet", "15-orchid": "Orchid", "16-fuchsia": "Fuchsia"
    })

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/superfedora/quickshell-theme.json"
        onLoaded: root._parseTheme()
    }
    FileView {
        id: uiScaleFile
        path: Quickshell.env("HOME") + "/.config/superfedora/ui-scale"
        onLoaded: root._parseScale()
    }

    Timer {
        id: verifyTimer
        interval: 280; repeat: false
        onTriggered: { root._lockUntil = 0; root.reload(); }
    }

    function applyOptimistic(cmd): void {
        const c = String(cmd || "");
        const tm = c.match(/(?:supertheme|superfedora\s+theme)\s+([0-9]{2}-[a-z]+|night|day|dark|light|corners\s+rounded|corners\s+square)/);
        if (!tm) return;
        root._lockUntil = Date.now() + 900;
        const v = tm[1];
        if (v === "night" || v === "dark") root.mode = "dark";
        else if (v === "day" || v === "light") root.mode = "light";
        else if (v === "corners rounded") { root.corners = "rounded"; root.radius = 10; root.radiusSm = 6; }
        else if (v === "corners square") { root.corners = "square"; root.radius = 0; root.radiusSm = 0; }
        else { root.theme = v; if (root._names[v]) root.themeName = root._names[v]; }
        verifyTimer.restart();
    }

    function _parseScale(): void {
        const s = Number(uiScaleFile.text().trim() || "14");
        if (s >= 12 && s <= 22) root.fontSize = s;
    }

    function reloadScale(): void {
        uiScaleFile.reload();
        root._parseScale();
    }

    function _parseTheme(): void {
        const raw = themeFile.text().trim();
        if (!raw) return;
        const locked = Date.now() < root._lockUntil;
        try {
            const d = JSON.parse(raw);
            if (!locked && d.theme) root.theme = d.theme;
            if (!locked && d.name) root.themeName = d.name;
            if (!locked && d.mode) root.mode = d.mode;
            if (d.nightlight !== undefined) root.nightlight = Boolean(d.nightlight);
            if (d.bg) root.bg = d.bg;
            if (d.bgAlt) root.bgAlt = d.bgAlt;
            if (d.bgHover) root.bgHover = d.bgHover;
            if (d.border) root.border = d.border;
            if (d.fg) root.fg = d.fg;
            if (d.fgDim) root.fgDim = d.fgDim;
            if (d.muted) root.muted = d.muted;
            if (d.blue) root.blue = d.blue;
            if (d.cyan) root.cyan = d.cyan;
            if (!locked && d.corners) root.corners = d.corners;
            if (!locked && d.radius !== undefined) root.radius = Number(d.radius);
            if (!locked && d.radiusSm !== undefined) root.radiusSm = Number(d.radiusSm);
        } catch (e) {}
    }

    function reload(): void {
        root.reloadScale();
        themeFile.reload();
        root._parseTheme();
    }

    Component.onCompleted: root.reload()

    IpcHandler {
        target: "theme"
        function reload(): void { root._lockUntil = 0; root.reload(); }
    }
}
