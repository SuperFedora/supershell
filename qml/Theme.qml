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

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/superfedora/quickshell-theme.json"
    }
    FileView {
        id: uiScaleFile
        path: Quickshell.env("HOME") + "/.config/superfedora/ui-scale"
    }

    function reloadScale(): void {
        uiScaleFile.reload();
        const s = Number(uiScaleFile.text().trim() || "14");
        if (s >= 12 && s <= 22) root.fontSize = s;
    }

    function reload(): void {
        root.reloadScale();
        themeFile.reload();
        const raw = themeFile.text().trim();
        if (!raw) return;
        try {
            const d = JSON.parse(raw);
            if (d.theme) root.theme = d.theme;
            if (d.name) root.themeName = d.name;
            if (d.mode) root.mode = d.mode;
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
            if (d.corners) root.corners = d.corners;
            if (d.radius !== undefined) root.radius = Number(d.radius);
            if (d.radiusSm !== undefined) root.radiusSm = Number(d.radiusSm);
        } catch (e) {}
    }

    Component.onCompleted: root.reload()

    IpcHandler {
        target: "theme"
        function reload(): void { root.reload(); }
    }
}
