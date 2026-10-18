import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import ".."

// 16-Bit TUI Session Lock Screen (matching tuigreet aesthetic) over dimmed active wallpaper (<=256 lines).
Scope {
    id: root
    property bool locked: false
    property string wallPath: Quickshell.env("HOME") + "/Pictures/Wallpapers/dark/01-super-blue.png"
    property string userName: Quickshell.env("USER") || "user"
    property string curDeId: "superfedora"
    property string curDeName: "SuperFedora"
    property var deList: [ { id: "superfedora", name: "SuperFedora" } ]
    property bool sysMenuOpen: false; property bool deMenuOpen: false
    property string authError: ""; property bool authBusy: false; property string pendingPass: ""
    property string confirmAct: ""; property string confirmTitle: ""; property string confirmBody: ""
    property string confirmBtn: ""; property string confirmCmd: ""; property bool confirmDanger: false
    property int countdown: 60
    property date now: new Date()

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "[ -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/superfedora.locked\" ] && for _ in $(seq 1 30); do qs ipc --any-display call lock activate >/dev/null 2>&1 && break; sleep 0.1; done || true"])
    onLockedChanged: {
        Quickshell.watchFiles = !root.locked;
        if ("sessionLocked" in Status) Status.sessionLocked = root.locked;
        if (root.locked) Quickshell.execDetached(["sh", "-c", "hyprctl keyword misc:allow_session_lock_restore 1 >/dev/null 2>&1 || true; touch \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/superfedora.locked\"; PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" idlescreen stop >/dev/null 2>&1 || true"]);
        else Quickshell.execDetached(["sh", "-c", "rm -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/superfedora.locked\""]);
    }

    FileView { id: wallFile; path: Quickshell.env("HOME") + "/.config/hypr/.current-wallpaper"; onLoaded: { const w = wallFile.text().trim(); if (w) root.wallPath = w; } }
    Timer { interval: 1000; running: root.locked; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    Process {
        id: deProc; command: ["sh", "-c", "~/.local/bin/superlock list 2>/dev/null || ~/.local/bin/superfedora session list 2>/dev/null"]
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
        onCompleted: res => { root.authBusy = false; if (res === PamResult.Success) { root.authError = ""; root.locked = false; if (Status.notifAction) Status.notifAction("banner", "ready"); } else { root.authError = "Authentication failed — access denied"; Qt.callLater(() => { if (root.locked && !pam.active) pam.start(); }); } }
        onError: err => { root.authBusy = false; root.authError = "PAM error — try again"; Qt.callLater(() => { if (root.locked && !pam.active) pam.start(); }); }
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
            Image { anchors.fill: parent; source: "file://" + (Status.currentWallpaper || root.wallPath); fillMode: Image.PreserveAspectCrop; cache: false }
            Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.76) }
            MouseArea { anchors.fill: parent; onClicked: { root.sysMenuOpen = false; root.deMenuOpen = false; passInput.forceActiveFocus(); } }

            // 1. Top TUI Clock Bar (tuigreet --time style)
            Text {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 36 }
                text: Qt.formatDateTime(root.now, "dddd, MMMM d, yyyy  ·  " + (Status.clock24h ? "HH:mm:ss" : "hh:mm:ss AP"))
                color: Theme.fg; font.family: Theme.font; font.pixelSize: 15; font.bold: true
            }

            // 2. Centered tuigreet-style 16-Bit TUI Container Box
            Rectangle {
                id: tuiBox; width: 520; implicitHeight: tuiCol.implicitHeight + 44
                anchors.centerIn: parent; radius: 0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                border.width: 2; border.color: root.authError !== "" ? Theme.red : Theme.blue
                MouseArea { anchors.fill: parent; onClicked: passInput.forceActiveFocus() }

                // Box Title Label intersecting top border like tuigreet/ratatui Block::title
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.top }
                    width: boxTitle.implicitWidth + 20; height: 22; color: Theme.bg
                    border.width: 1; border.color: root.authError !== "" ? Theme.red : Theme.blue
                    Text { id: boxTitle; anchors.centerIn: parent; text: "SUPER FEDORA"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                }

                ColumnLayout {
                    id: tuiCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24; topMargin: 28 } spacing: 14
                    Text {
                        Layout.alignment: Qt.AlignHCenter; color: Theme.cyan; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                        text: "── [ SESSION LOCKED · AUTHENTICATION REQUIRED ] ──"
                    }

                    // Username row (tuigreet aligned field)
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { Layout.preferredWidth: 104; text: "Username :"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            Layout.fillWidth: true; height: 34; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: root.userName + (Status.userFullName && Status.userFullName !== root.userName ? " (" + Status.userFullName + ")" : ""); color: Theme.fg; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
                        }
                    }

                    // Password row (tuigreet --asterisks field)
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { Layout.preferredWidth: 104; text: "Password :"; color: Theme.blue; font.family: Theme.font; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            Layout.fillWidth: true; height: 38; color: Theme.bgAlt
                            border.width: 2; border.color: root.authError !== "" ? Theme.red : (passInput.activeFocus ? Theme.cyan : Theme.blue)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                TextInput {
                                    id: passInput; Layout.fillWidth: true; focus: root.confirmAct === ""
                                    echoMode: TextInput.Password; passwordCharacter: "*"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 15; verticalAlignment: TextInput.AlignVCenter
                                    Keys.onReturnPressed: { const p = text; text = ""; root.submitPassword(p); }
                                    Keys.onEnterPressed:  { const p = text; text = ""; root.submitPassword(p); }
                                    Keys.onEscapePressed: { text = ""; root.authError = ""; root.sysMenuOpen = false; root.deMenuOpen = false; }
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_F1) { Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.local/bin/superlock dpms off"]); event.accepted = true; }
                                        else if (event.key === Qt.Key_F2) { root.askConfirm("suspend", "SUSPEND SYSTEM", "Enter low-power sleep mode?", "[Confirm Suspend]", "systemctl suspend", false); event.accepted = true; }
                                        else if (event.key === Qt.Key_F3) { root.askConfirm("logout", "LOG OUT SESSION", "Terminate session and return to login greeter?", "[Confirm Log Out]", "~/.local/bin/superlock switch || ~/.local/bin/superfedora session switch", true); event.accepted = true; }
                                        else if (event.key === Qt.Key_F4) { root.askConfirm("reboot", "RESTART SYSTEM", "Close all applications and reboot?", "[Confirm Restart]", "systemctl reboot", true); event.accepted = true; }
                                        else if (event.key === Qt.Key_F5) { root.askConfirm("power", "POWER OFF SYSTEM", "Close all applications and shut down?", "[Confirm Power Off]", "systemctl poweroff", true); event.accepted = true; }
                                    }
                                    Text { visible: parent.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: root.authBusy ? "Verifying credentials..." : "Enter password..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
                                }
                                Rectangle {
                                    width: 72; height: 26; color: goMouse.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.blue
                                    Text { anchors.centerIn: parent; text: "[Unlock]"; color: goMouse.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                                    MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const p = passInput.text; passInput.text = ""; root.submitPassword(p); } }
                                }
                            }
                        }
                    }

                    // Session / Notifications / Status line
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Session  : " + root.curDeName; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: Status.notifUnread > 0 || Status.dnd
                            color: Status.dnd ? Theme.yellow : Theme.cyan; font.family: Theme.font; font.pixelSize: 12; font.bold: true
                            text: (Status.dnd ? "[DND]" : "[!]") + (Status.notifUnread > 0 ? (" " + Status.notifUnread + " Unread") : " Do Not Disturb")
                        }
                    }

                    Text {
                        visible: root.authError !== ""
                        Layout.alignment: Qt.AlignHCenter; text: "[ERROR] " + root.authError; color: Theme.red; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                    }
                }
            }

            // 3. Bottom TUI Function Key Action Bar (tuigreet footer style)
            RowLayout {
                id: ftrBar; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 28 } spacing: 12
                Repeater {
                    model: [
                        { icon: "[F1]", label: "Screen Off", danger: false, direct: "sleep 0.2; ~/.local/bin/superlock dpms off" },
                        { icon: "[F2]", label: "Suspend",    danger: false, act: "suspend", title: "SUSPEND SYSTEM",   body: "Enter low-power sleep mode?", btn: "[Confirm Suspend]", cmd: "systemctl suspend" },
                        { icon: "[F3]", label: "Log Out",    danger: true,  act: "logout",  title: "LOG OUT SESSION",  body: "Terminate session and return to login greeter?", btn: "[Confirm Log Out]", cmd: "~/.local/bin/superlock switch || ~/.local/bin/superfedora session switch" },
                        { icon: "[F4]", label: "Restart",    danger: true,  act: "reboot",  title: "RESTART SYSTEM",   body: "Close all applications and reboot?", btn: "[Confirm Restart]", cmd: "systemctl reboot" },
                        { icon: "[F5]", label: "Power Off",  danger: true,  act: "power",   title: "POWER OFF SYSTEM", body: "Close all applications and shut down?", btn: "[Confirm Power Off]", cmd: "systemctl poweroff" }
                    ]
                    Rectangle {
                        required property var modelData
                        width: ftrRow.implicitWidth + 20; height: 32; color: ftrM.containsMouse ? Theme.bgHover : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
                        border.width: 1; border.color: ftrM.containsMouse ? (modelData.danger ? Theme.red : Theme.cyan) : Theme.blue
                        RowLayout {
                            id: ftrRow; anchors.centerIn: parent; spacing: 6
                            Text { text: parent.parent.modelData.icon; color: parent.parent.modelData.danger ? Theme.red : Theme.blue; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                            Text { text: parent.parent.modelData.label; color: parent.parent.modelData.danger ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                        }
                        MouseArea {
                            id: ftrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = parent.modelData;
                                if (d.direct) Quickshell.execDetached(["sh", "-c", d.direct]);
                                else root.askConfirm(d.act, d.title, d.body, d.btn, d.cmd, d.danger);
                            }
                        }
                    }
                }
            }

            // 4. Centered TUI Modal Confirmation Dialog
            Rectangle {
                visible: root.confirmAct !== ""; anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.72)
                MouseArea { anchors.fill: parent; onClicked: { root.confirmAct = ""; passInput.forceActiveFocus(); } }
                Rectangle {
                    width: 440; implicitHeight: modalCol.implicitHeight + 40; anchors.centerIn: parent; radius: 0; color: Theme.bg; border.width: 2; border.color: root.confirmDanger ? Theme.red : Theme.blue
                    MouseArea { anchors.fill: parent }
                    ColumnLayout {
                        id: modalCol; anchors.fill: parent; anchors.margins: 20; spacing: 14
                        Text { Layout.fillWidth: true; text: "── [ " + root.confirmTitle + " ] ──"; color: root.confirmDanger ? Theme.red : Theme.cyan; font.family: Theme.font; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                        Text { Layout.fillWidth: true; text: root.confirmBody + "\n\nAuto-executing in " + root.countdown + "s..."; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 13; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 34; color: canMouse.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
                                Text { anchors.centerIn: parent; text: "[Esc] Cancel"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                                MouseArea { id: canMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.confirmAct = ""; passInput.forceActiveFocus(); } }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 34; color: okMouse.containsMouse ? (root.confirmDanger ? Theme.red : Theme.blue) : Theme.bgHover; border.width: 2; border.color: root.confirmDanger ? Theme.red : Theme.blue
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
