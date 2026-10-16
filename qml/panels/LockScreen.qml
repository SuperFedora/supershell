import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import ".."

// GNOME-style (GDM) Wayland Session Lock Screen with top-right system menu,
// bottom-right DE gear menu, and modal confirmation dialogs (<=256 lines).
Scope {
    id: root
    property bool locked: false
    property string wallPath: Quickshell.env("HOME") + "/Pictures/Wallpapers/dark/01-super-blue.png"
    property string userName: Quickshell.env("USER") || "user"
    property string curDeId: "hyprland"
    property string curDeName: "Hyprland"
    property var deList: [
        { id: "hyprland", name: "Hyprland" }, { id: "hyprland-uwsm", name: "Hyprland (uwsm-managed)" },
        { id: "gnome", name: "GNOME" },       { id: "gnome-classic", name: "GNOME Classic" }
    ]
    property bool sysMenuOpen: false; property bool deMenuOpen: false
    property string authError: ""; property bool authBusy: false; property string pendingPass: ""
    property string confirmAct: ""; property string confirmTitle: ""; property string confirmBody: ""
    property string confirmBtn: ""; property string confirmCmd: ""; property bool confirmDanger: false
    property int countdown: 60

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "[ -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/superfedora.locked\" ] && for _ in $(seq 1 30); do qs ipc --any-display call lock activate >/dev/null 2>&1 && break; sleep 0.1; done || true"])
    onLockedChanged: {
        Quickshell.watchFiles = !root.locked;
        if ("sessionLocked" in Status) Status.sessionLocked = root.locked;
        if (root.locked) Quickshell.execDetached(["sh", "-c", "hyprctl keyword misc:allow_session_lock_restore 1 >/dev/null 2>&1 || true; touch \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/superfedora.locked\"; PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" idlescreen stop >/dev/null 2>&1 || true"]);
        else Quickshell.execDetached(["sh", "-c", "rm -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/superfedora.locked\""]);
    }

    FileView { id: wallFile; path: Quickshell.env("HOME") + "/.config/hypr/.current-wallpaper" }
    Process {
        id: deProc; command: ["sh", "-c", "~/.local/bin/superlock list 2>/dev/null || ~/.local/bin/sf session list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.trim().split("\n")) {
                    const m = line.match(/^(\[\*\]|\s+)\s+(\S+)\s+\((.+)\)$/);
                    if (m) { list.push({ id: m[2], name: m[3] }); if (m[1] === "[*]") { root.curDeId = m[2]; root.curDeName = m[3]; } }
                }
                if (list.length > 0) root.deList = list;
            }
        }
    }
    PamContext {
        id: pam; config: "password-auth"; user: root.userName
        onResponseRequiredChanged: { if (pam.responseRequired && root.pendingPass !== "") { const p = root.pendingPass; root.pendingPass = ""; pam.respond(p); } }
        onCompleted: res => { root.authBusy = false; if (res === PamResult.Success) { root.authError = ""; root.locked = false; if (Status.notifAction) Status.notifAction("banner", "ready"); } else { root.authError = "Incorrect password — please try again"; Qt.callLater(() => { if (root.locked && !pam.active) pam.start(); }); } }
        onError: err => { root.authBusy = false; root.authError = "Authentication error — try again"; Qt.callLater(() => { if (root.locked && !pam.active) pam.start(); }); }
    }
    Timer { id: countTimer; interval: 1000; repeat: true; running: root.confirmAct !== ""; onTriggered: { if (root.countdown > 1) root.countdown -= 1; else root.executeConfirm(); } }

    function activateLock() {
        if (root.locked) return;
        wallFile.reload(); const w = wallFile.text().trim(); if (w) root.wallPath = w;
        deProc.running = true; root.sysMenuOpen = false; root.deMenuOpen = false; root.confirmAct = "";
        root.authError = ""; root.authBusy = false; root.pendingPass = ""; root.locked = true;
        if (!pam.active) pam.start();
    }
    function submitPassword(pw) {
        if (!pw || root.authBusy) return;
        root.authError = ""; root.authBusy = true;
        if (pam.active && pam.responseRequired) pam.respond(pw); else { root.pendingPass = pw; if (!pam.active) pam.start(); }
    }
    function askConfirm(act, title, body, btn, cmd, danger) {
        root.sysMenuOpen = false; root.deMenuOpen = false; root.countdown = 60; root.confirmAct = act;
        root.confirmTitle = title; root.confirmBody = body; root.confirmBtn = btn; root.confirmCmd = cmd; root.confirmDanger = danger;
    }
    function executeConfirm() {
        const cmd = root.confirmCmd; const act = root.confirmAct; root.confirmAct = "";
        if (act === "de" || act === "logout") root.locked = false;
        if (cmd) Quickshell.execDetached(["sh", "-c", cmd]);
    }
    IpcHandler { target: "lock"; function activate(): void { root.activateLock(); } function unlock(): void { root.locked = false; if (Status.notifAction) Status.notifAction("banner", "ready"); } }

    WlSessionLock {
        id: sessionLock; locked: root.locked
        WlSessionLockSurface {
            id: surface; color: Theme.bg
            Image { anchors.fill: parent; source: "file://" + root.wallPath; fillMode: Image.PreserveAspectCrop }
            MouseArea { anchors.fill: parent; onClicked: { root.sysMenuOpen = false; root.deMenuOpen = false; passInput.forceActiveFocus(); } }

            // 1. GNOME Top-Right System Pill & Popover Menu
            Rectangle {
                id: sysPill; anchors { top: parent.top; right: parent.right; topMargin: 18; rightMargin: 24 }
                width: sysRow.implicitWidth + 28; height: 38; radius: Theme.radius
                color: (sysMouse.containsMouse || root.sysMenuOpen) ? Theme.bgHover : Theme.bg; border.width: 2; border.color: root.sysMenuOpen ? Theme.cyan : Theme.blue
                RowLayout {
                    id: sysRow; anchors.centerIn: parent; spacing: 12
                    Text { text: "󰍹"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 15 }
                    Text { text: "󰤄"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 15 }
                    Text { text: "󰜉"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 15 }
                    Text { text: "󰐥"; color: Theme.red; font.family: Theme.font; font.pixelSize: 15 }
                    Text { text: "▾"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 12 }
                }
                MouseArea { id: sysMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.deMenuOpen = false; root.sysMenuOpen = !root.sysMenuOpen; } }
            }

            Rectangle {
                visible: root.sysMenuOpen; anchors { top: sysPill.bottom; right: sysPill.right; topMargin: 8 }
                width: 230; implicitHeight: sysMenuCol.implicitHeight + 20; radius: Theme.radius; color: Theme.bg; border.width: 2; border.color: Theme.blue
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    id: sysMenuCol; anchors.fill: parent; anchors.margins: 10; spacing: 4
                    Text { text: "SYSTEM & POWER"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                    Repeater {
                        model: [
                            { icon: "󰍹", label: "Turn Screen Off", danger: false, direct: "sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off" },
                            { icon: "󰤄", label: "Suspend...",      danger: false, act: "suspend", title: "Suspend System?",     body: "The system will enter low-power sleep mode.", btn: "Suspend",   cmd: "systemctl suspend" },
                            { icon: "󰍃", label: "Log Out...",      danger: true,  act: "logout",  title: "Log Out of Session?", body: "Close your current session and return to the login screen.", btn: "Log Out", cmd: "~/.local/bin/superlock switch || ~/.local/bin/sf session switch" },
                            { icon: "󰜉", label: "Restart...",      danger: true,  act: "reboot",  title: "Restart System?",     body: "All open applications will close and the system will reboot.", btn: "Restart", cmd: "systemctl reboot" },
                            { icon: "󰐥", label: "Power Off...",    danger: true,  act: "power",   title: "Power Off System?",   body: "All open applications will close and the system will shut down.", btn: "Power Off", cmd: "systemctl poweroff" }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; color: smMouse.containsMouse ? Theme.bgHover : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 10
                                Text { text: parent.parent.modelData.icon; color: parent.parent.modelData.danger ? Theme.red : Theme.blue; font.family: Theme.font; font.pixelSize: 14 }
                                Text { Layout.fillWidth: true; text: parent.parent.modelData.label; color: parent.parent.modelData.danger ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: 13 }
                            }
                            MouseArea {
                                id: smMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = parent.modelData;
                                    if (d.direct) { root.sysMenuOpen = false; Quickshell.execDetached(["sh", "-c", d.direct]); }
                                    else root.askConfirm(d.act, d.title, d.body, d.btn, d.cmd, d.danger);
                                }
                            }
                        }
                    }
                }
            }

            // 2. GNOME Lower-Third Floating User Stack (Avatar + Username + Unread Badge + Password Input)
            ColumnLayout {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 42; spacing: 10
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter; width: 84; height: 84; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                    Image { anchors.fill: parent; anchors.margins: 4; source: "file://" + (Status.userAvatar || (Quickshell.env("HOME") + "/Pictures/Wallpapers/avatar.jpg")); fillMode: Image.PreserveAspectCrop; cache: false }
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: Status.userFullName || root.userName; color: Theme.fg; font.family: Theme.font; font.pixelSize: 17; font.bold: true }
                Rectangle {
                    visible: Status.notifUnread > 0 || Status.dnd
                    Layout.alignment: Qt.AlignHCenter; width: lockNotifTxt.implicitWidth + 24; height: 26; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Status.dnd ? Theme.yellow : Theme.cyan
                    Text {
                        id: lockNotifTxt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: 12; font.bold: true; color: Status.dnd ? Theme.yellow : Theme.cyan
                        text: (Status.dnd ? "󰂛  Do Not Disturb" : "󰂞") + (Status.notifUnread > 0 ? ((Status.dnd ? " · " : "  ") + Status.notifUnread + (Status.notifUnread === 1 ? " Unread Notification" : " Unread Notifications")) : "")
                    }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter; width: 300; height: 44; radius: Theme.radius; color: Theme.bg
                    border.width: 2; border.color: root.authError !== "" ? Theme.red : (passInput.activeFocus ? Theme.cyan : Theme.blue)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 8
                        TextInput {
                            id: passInput; Layout.fillWidth: true; focus: root.confirmAct === ""
                            echoMode: TextInput.Password; passwordCharacter: "●"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 14; verticalAlignment: TextInput.AlignVCenter
                            Keys.onReturnPressed: { const p = text; text = ""; root.submitPassword(p); }
                            Keys.onEnterPressed:  { const p = text; text = ""; root.submitPassword(p); }
                            Keys.onEscapePressed: { text = ""; root.authError = ""; root.sysMenuOpen = false; root.deMenuOpen = false; }
                            Text { visible: parent.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: root.authBusy ? "Verifying..." : "Password"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                        }
                        Rectangle {
                            width: 30; height: 30; radius: Theme.radiusSm; color: goMouse.containsMouse ? Theme.blue : Theme.bgAlt
                            Text { anchors.centerIn: parent; text: "→"; color: goMouse.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: 15; font.bold: true }
                            MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const p = passInput.text; passInput.text = ""; root.submitPassword(p); } }
                        }
                    }
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: root.authError !== "" ? root.authError : " "; color: Theme.red; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
            }

            // 3. GNOME Bottom-Right Gear (Desktop Environment) Pill & Popover Menu
            Rectangle {
                id: dePill; anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 24; rightMargin: 24 }
                width: deRow.implicitWidth + 28; height: 38; radius: Theme.radius
                color: (deMouse.containsMouse || root.deMenuOpen) ? Theme.bgHover : Theme.bg; border.width: 2; border.color: root.deMenuOpen ? Theme.cyan : Theme.blue
                RowLayout {
                    id: deRow; anchors.centerIn: parent; spacing: 8
                    Text { text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 15 }
                    Text { text: root.curDeName; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                    Text { text: "▴"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 12 }
                }
                MouseArea { id: deMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.sysMenuOpen = false; root.deMenuOpen = !root.deMenuOpen; } }
            }

            Rectangle {
                visible: root.deMenuOpen; anchors { bottom: dePill.top; right: dePill.right; bottomMargin: 8 }
                width: 260; implicitHeight: deMenuCol.implicitHeight + 20; radius: Theme.radius; color: Theme.bg; border.width: 2; border.color: Theme.blue
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    id: deMenuCol; anchors.fill: parent; anchors.margins: 10; spacing: 4
                    Text { text: "DESKTOP ENVIRONMENT"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                    Repeater {
                        model: root.deList
                        Rectangle {
                            required property var modelData
                            readonly property bool isCur: modelData.id === root.curDeId
                            Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; color: dmMouse.containsMouse ? Theme.bgHover : (isCur ? Theme.bgAlt : "transparent")
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                Text { text: parent.parent.isCur ? "●" : "○"; color: parent.parent.isCur ? Theme.cyan : Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
                                Text { Layout.fillWidth: true; text: parent.parent.modelData.name; color: parent.parent.isCur ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.bold: parent.parent.isCur }
                            }
                            MouseArea {
                                id: dmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = parent.modelData; root.curDeId = d.id; root.curDeName = d.name;
                                    Quickshell.execDetached(["sh", "-c", "~/.local/bin/superlock set '" + d.id + "' || ~/.local/bin/sf session set '" + d.id + "'"]);
                                    root.askConfirm("de", "Switch Desktop to " + d.name + "?", "Save '" + d.name + "' as your session and return to the login screen to launch it?", "Switch to " + d.name, "(~/.local/bin/superlock set '" + d.id + "' && ~/.local/bin/superlock switch) || (~/.local/bin/sf session set '" + d.id + "' && ~/.local/bin/sf session switch)", false);
                                }
                            }
                        }
                    }
                }
            }

            // 4. Centered GNOME Modal Confirmation Dialog
            Rectangle {
                visible: root.confirmAct !== ""; anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.65)
                MouseArea { anchors.fill: parent; onClicked: { root.confirmAct = ""; passInput.forceActiveFocus(); } }
                Rectangle {
                    width: 420; implicitHeight: modalCol.implicitHeight + 36; anchors.centerIn: parent; radius: Theme.radius; color: Theme.bg; border.width: 2; border.color: root.confirmDanger ? Theme.red : Theme.blue
                    MouseArea { anchors.fill: parent }
                    ColumnLayout {
                        id: modalCol; anchors.fill: parent; anchors.margins: 18; spacing: 12
                        Text { Layout.fillWidth: true; text: root.confirmTitle; color: root.confirmDanger ? Theme.red : Theme.cyan; font.family: Theme.font; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                        Text { Layout.fillWidth: true; text: root.confirmBody + "\n\nAuto-confirming in " + root.countdown + " seconds."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 13; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: canMouse.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                                MouseArea { id: canMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.confirmAct = ""; passInput.forceActiveFocus(); } }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: okMouse.containsMouse ? (root.confirmDanger ? Theme.red : Theme.blue) : Theme.bgHover; border.width: 2; border.color: root.confirmDanger ? Theme.red : Theme.blue
                                Text { anchors.centerIn: parent; text: root.confirmBtn; color: okMouse.containsMouse ? Theme.bg : (root.confirmDanger ? Theme.red : Theme.cyan); font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                                MouseArea { id: okMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.executeConfirm() }
                            }
                        }
                    }
                }
            }
        }
    }
}
