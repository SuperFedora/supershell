import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."

// SuperFedora Launchpad App Grid (`Super + Shift + A` or Launcher Apps button).
// Displays all installed .desktop applications with type-to-filter, keyboard navigation,
// and a right-click context menu (Open / Uninstall WebApp).
PanelWindow {
    id: root
    property var targetScreen: Quickshell.screens[0]

    visible: Status.appGridOpen
    screen: root.targetScreen
    color: "transparent"
    WlrLayershell.namespace: "superfedora-appgrid"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Status.appGridOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    property string filterText: ""; property int selectedIndex: 0; property var menuEntry: null
    property point menuPoint: Qt.point(0, 0)
    Connections { target: Hyprland; function onRawEvent(ev) { const n = String(ev.name || ""), d = String(ev.data || "").trim(); if (n === "openlayer" && (d.startsWith("idlescreen") || d.startsWith("screensaver"))) root.close(); } }

    function normId(raw) { return String(raw || "").trim().replace(/\.desktop$/i, ""); }
    function iconUrl(iconName) { const s = String(iconName || ""); return !s ? "" : (s.startsWith("file://") || s.startsWith("image://")) ? s : s.startsWith("/") ? ("file://" + s) : (Quickshell.iconPath(s, true) || ""); }

    readonly property var apps: {
        const raw = (Status.localApps || []).concat((DesktopEntries.applications && DesktopEntries.applications.values) ? DesktopEntries.applications.values : []);
        const q = root.filterText.trim().toLowerCase(), list = [], seen = {};
        for (let i = 0; i < raw.length; i++) {
            const e = raw[i]; if (!e || e.noDisplay) continue;
            const id = root.normId(e.id), lowId = id.toLowerCase(), name = String(e.name || id || "").trim();
            if (!name || lowId === "superfedora-settings" || lowId === "org.gnome.settings" || lowId === "superfiles" || seen[name.toLowerCase()] || seen[lowId]) continue;
            const hay = (name + " " + String(e.genericName || "") + " " + String(e.comment || "") + " " + id).toLowerCase();
            if (q && !hay.includes(q)) continue;
            seen[name.toLowerCase()] = true; seen[lowId] = true;
            list.push({ id: id, name: name, icon: root.iconUrl(e.icon), entry: e });
        }
        list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        return list;
    }

    onVisibleChanged: if (visible) { root.filterText = ""; root.selectedIndex = 0; root.menuEntry = null; keyCatcher.forceActiveFocus(); }
    onFilterTextChanged: { root.selectedIndex = 0; root.menuEntry = null; }
    function close() { root.menuEntry = null; Status.appGridOpen = false; }

    function launchEntry(item) {
        if (!item) return; root.close(); const k = String(item.id || "").toLowerCase();
        if (k === "supersettings" || k === "superfedora-settings") Status.openSettings("home");
        else if (k === "superforge") Status.openForgeGui("");
        else if (k === "superbar") Status.openSuperBarGui("home");
        else if (k === Status.defFiles || k === Status.defEditor || k === Status.defMonitor || k === Status.defTerminal) Quickshell.execDetached(["sh", "-c", "~/.local/bin/xdg-terminal-exec" + (k === Status.defFiles ? " --files" : (k === Status.defEditor ? " --editor" : (k === Status.defMonitor ? " --monitor" : "")))]);
        else if (item.entry && typeof item.entry.execute === "function" && !item.entry.runInTerminal) item.entry.execute();
        else if (item.entry && item.entry.runInTerminal) Quickshell.execDetached(["sh", "-c", "~/.local/bin/xdg-terminal-exec --class floating-term --title '" + String(item.name || k).replace(/'/g, "") + "' -e " + (item.entry.execCmd || k)]);
        else Quickshell.execDetached(["sh", "-c", "gtk-launch '" + item.id + "' 2>/dev/null || " + k]);
    }

    Item {
        id: keyCatcher; anchors.fill: parent; focus: true
        Keys.onPressed: event => {
            const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
            if (event.key === Qt.Key_Escape) { if (root.menuEntry) root.menuEntry = null; else if (root.filterText.length > 0) root.filterText = ""; else root.close(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (root.apps.length > 0 && root.selectedIndex < root.apps.length) root.launchEntry(root.apps[root.selectedIndex]); event.accepted = true; }
            else if (event.key === Qt.Key_Backspace) { if (root.filterText.length > 0) root.filterText = root.filterText.slice(0, -1); event.accepted = true; }
            else if (event.key === Qt.Key_Right && root.apps.length > 0) { root.selectedIndex = (root.selectedIndex + 1) % root.apps.length; event.accepted = true; }
            else if (event.key === Qt.Key_Left && root.apps.length > 0) { root.selectedIndex = (root.selectedIndex - 1 + root.apps.length) % root.apps.length; event.accepted = true; }
            else if (event.key === Qt.Key_Down && root.apps.length > 0) { root.selectedIndex = Math.min(root.apps.length - 1, root.selectedIndex + cols); event.accepted = true; }
            else if (event.key === Qt.Key_Up && root.apps.length > 0) { root.selectedIndex = Math.max(0, root.selectedIndex - cols); event.accepted = true; }
            else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { root.filterText += event.text; event.accepted = true; }
        }
    }

    Item {
        anchors.fill: parent
        Rectangle {
            anchors { fill: parent }
            color: Qt.rgba(0.05, 0.06, 0.10, 0.86)
        }
        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: { if (root.menuEntry) root.menuEntry = null; else root.close(); }
        }

        ColumnLayout {
            width: Math.min(root.width - 150, 1080); height: Math.min(root.height - 170, 720)
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            spacing: 16

            Rectangle {
                Layout.alignment: Qt.AlignHCenter; width: 380; height: 42; radius: Theme.radius; color: Theme.bg
                border.width: 2; border.color: root.filterText.length > 0 ? Theme.cyan : Theme.blue
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 } spacing: 10
                    Text { text: "󰍉"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 18 }
                    Text { Layout.fillWidth: true; text: root.filterText.length > 0 ? root.filterText : "Search applications by name..."; color: root.filterText.length > 0 ? Theme.fg : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize; elide: Text.ElideRight }
                    Text { visible: root.filterText.length > 0; text: "[Esc]"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                }
            }

            GridView {
                id: grid; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; interactive: true
                cellWidth: 132; cellHeight: 118; model: root.apps

                delegate: Item {
                    id: cell; required property var modelData; required property int index
                    readonly property bool selected: index === root.selectedIndex
                    width: grid.cellWidth; height: grid.cellHeight

                    Rectangle {
                        anchors { fill: parent; margins: 6 } radius: Theme.radiusSm
                        color: cell.selected || cellMouse.containsMouse ? Theme.bgHover : "transparent"
                        border.width: cell.selected ? 2 : (cellMouse.containsMouse ? 1 : 0); border.color: cell.selected ? Theme.blue : Theme.cyan

                        ColumnLayout {
                            anchors { fill: parent; margins: 8 } spacing: 6
                            Item {
                                Layout.alignment: Qt.AlignHCenter; width: 48; height: 48
                                Image { id: cellIcon; anchors.fill: parent; sourceSize: Qt.size(96, 96); source: cell.modelData.icon; visible: status === Image.Ready; smooth: true; mipmap: true }
                                Text { anchors.centerIn: parent; visible: cellIcon.status !== Image.Ready; text: "󰣆"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 32 }
                            }
                            Text {
                                Layout.fillWidth: true; text: cell.modelData.name
                                color: cell.selected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: cell.selected
                                horizontalAlignment: Text.AlignHCenter; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: cellMouse; anchors.fill: parent; hoverEnabled: true; preventStealing: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = cell.index
                        onClicked: e => {
                            if (e.button === Qt.RightButton) { root.menuEntry = cell.modelData; root.menuPoint = cell.mapToItem(null, e.x, e.y); }
                            else root.launchEntry(cell.modelData);
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.menuEntry !== null
            width: 210; height: ctxCol.implicitHeight + 14
            x: Math.min(root.width - width - 12, Math.max(12, root.menuPoint.x))
            y: Math.min(root.height - height - 12, Math.max(12, root.menuPoint.y))
            radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: Theme.blue

            ColumnLayout {
                id: ctxCol; anchors { fill: parent; margins: 7 } spacing: 4
                Repeater {
                    model: root.menuEntry ? [
                        { label: "Open " + root.menuEntry.name, act: "open" },
                        { label: "Uninstall WebApp", act: "unforge", hide: !String(root.menuEntry.id || "").startsWith("sf-webapp-") }
                    ].filter(r => !r.hide) : []
                    Rectangle {
                        id: ctxRow; required property var modelData
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: cmMouse.containsMouse ? Theme.bgHover : "transparent"
                        Text { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 } text: ctxRow.modelData.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight; width: 190 }
                        MouseArea {
                            id: cmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const act = ctxRow.modelData.act, entry = root.menuEntry;
                                if (entry) {
                                    if (act === "open") root.launchEntry(entry);
                                    else if (act === "unforge") Status.removeForge(entry.id);
                                }
                                root.menuEntry = null;
                            }
                        }
                    }
                }
            }
        }
    }
}
