import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// StatusNotifier tray with zero-trust icon resolution:
// 1. Direct flat-directory IconThemePath resolution (?path=/dir + name.png/.svg) for Steam, Electron & AppIndicator apps
// 2. Native Quickshell IconImage (IconPixmap / XDG theme icon)
// 3. Desktop app icon fallback via Quickshell.iconPath(id / title)
// 4. Monogram glyph badge if all image sources fail (never renders an invisible slot)
Flow {
    id: root
    property var bar: null
    property bool vertical: false
    readonly property int count: trayRep.count
    readonly property int edgeAnchor: !root.bar ? Edges.Bottom : (root.bar.edge === "bottom" ? Edges.Top : (root.bar.edge === "left" ? Edges.Right : (root.bar.edge === "right" ? Edges.Left : Edges.Bottom)))
    flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
    spacing: 4
    width: root.vertical ? Theme.barHeight : implicitWidth
    height: root.vertical ? implicitHeight : Theme.barHeight

    function parseCustomPng(rawIcon) {
        const s = String(rawIcon || "");
        if (!s.startsWith("image://icon/")) return "";
        const q = s.indexOf("?path=");
        if (q < 0) return "";
        const name = decodeURIComponent(s.slice(13, q));
        const dir = decodeURIComponent(s.slice(q + 6)).replace(/\/+$/, "");
        if (!name || !dir) return "";
        if (name.endsWith(".png") || name.endsWith(".svg") || name.endsWith(".xpm"))
            return "file://" + dir + "/" + name;
        return "file://" + dir + "/" + name + ".png";
    }

    function parseCustomSvg(rawIcon) {
        const p = root.parseCustomPng(rawIcon);
        return p.endsWith(".png") ? (p.slice(0, -4) + ".svg") : "";
    }

    function desktopFallback(item) {
        if (!item) return "";
        const rawIcon = String(item.icon || "");
        const q = rawIcon.indexOf("?path=");
        const iconName = rawIcon.startsWith("image://icon/") ? decodeURIComponent(rawIcon.slice(13, q >= 0 ? q : rawIcon.length)) : "";
        const candidates = [
            iconName,
            String(item.id || ""),
            String(item.id || "").toLowerCase(),
            String(item.title || "").toLowerCase().split(/\s+/)[0] || ""
        ];
        for (const c of candidates) {
            if (!c) continue;
            const resolved = Quickshell.iconPath(c, true);
            if (resolved) return resolved;
        }
        return "";
    }

    Timer {
        interval: 1800
        running: root.bar && root.bar.modelData === Quickshell.screens[0]
        repeat: false
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/superbar", "tray", "sync"])
    }

    Repeater {
        id: trayRep
        model: SystemTray.items

        Item {
            id: traySlot
            required property SystemTrayItem modelData
            readonly property string customPng: root.parseCustomPng(modelData.icon)
            readonly property string customSvg: root.parseCustomSvg(modelData.icon)
            readonly property string appIcon: root.desktopFallback(modelData)
            readonly property bool useCustomPng: customPng !== "" && customImg.status === Image.Ready
            readonly property bool useCustomSvg: !useCustomPng && customSvg !== "" && customSvgImg.status === Image.Ready
            readonly property bool useNative: !useCustomPng && !useCustomSvg && customPng === "" && nativeIcon.status === Image.Ready
            readonly property bool useAppFallback: !useCustomPng && !useCustomSvg && !useNative && appIcon !== "" && fallbackImg.status === Image.Ready
            width: root.vertical ? Theme.barHeight : 26
            height: root.vertical ? 26 : Theme.barHeight

            Rectangle {
                id: trayItem
                anchors.centerIn: parent
                width: root.vertical ? Theme.barHeight - 8 : 26
                height: root.vertical ? 26 : Theme.barHeight - 8
                radius: Theme.radiusSm
                color: trayMouse.pressed ? Theme.bgAlt : (trayMouse.containsMouse ? Theme.bgHover : "transparent")
                border.width: 0

                Image {
                    id: customImg
                    anchors.centerIn: parent
                    width: Theme.iconSize - 2
                    height: Theme.iconSize - 2
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: traySlot.useCustomPng
                    source: traySlot.customPng
                }

                Image {
                    id: customSvgImg
                    anchors.centerIn: parent
                    width: Theme.iconSize - 2
                    height: Theme.iconSize - 2
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: traySlot.useCustomSvg
                    source: traySlot.customPng !== "" && customImg.status === Image.Error ? traySlot.customSvg : ""
                }

                IconImage {
                    id: nativeIcon
                    anchors.centerIn: parent
                    implicitSize: Theme.iconSize - 2
                    visible: traySlot.useNative
                    source: traySlot.customPng === "" ? traySlot.modelData.icon : ""
                }

                IconImage {
                    id: fallbackImg
                    anchors.centerIn: parent
                    implicitSize: Theme.iconSize - 2
                    visible: traySlot.useAppFallback
                    source: (!traySlot.useCustomPng && !traySlot.useCustomSvg && !traySlot.useNative) ? traySlot.appIcon : ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !traySlot.useCustomPng && !traySlot.useCustomSvg && !traySlot.useNative && !traySlot.useAppFallback
                    text: String(traySlot.modelData.title || traySlot.modelData.id || "?").trim().charAt(0).toUpperCase()
                    color: Theme.blue
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: true
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: traySlot.modelData.menu
                    anchor.item: trayItem
                    anchor.edges: root.edgeAnchor
                    anchor.gravity: root.edgeAnchor
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (root.bar && root.bar.setBarTip) root.bar.setBarTip(traySlot, traySlot.modelData.title || traySlot.modelData.id || "Tray Item", containsMouse)
                    onClicked: e => {
                        if (root.bar && root.bar.setBarTip) root.bar.setBarTip(null, "", false);
                        if (e.button === Qt.MiddleButton)
                            traySlot.modelData.secondaryActivate();
                        else if (e.button === Qt.RightButton || traySlot.modelData.onlyMenu) {
                            if (traySlot.modelData.hasMenu) menuAnchor.open();
                        } else {
                            traySlot.modelData.activate();
                            if (traySlot.modelData.hasMenu) {
                                Quickshell.execDetached([
                                    Quickshell.env("HOME") + "/.local/bin/superbar",
                                    "tray",
                                    "activate",
                                    String(traySlot.modelData.id || ""),
                                    String(traySlot.modelData.title || "")
                                ]);
                            }
                        }
                    }
                }
            }
        }
    }
}
