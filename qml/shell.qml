//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "panels"

// Entry point: Omarchy-style Top Bar + Dock per monitor + Launchpad AppGrid + SettingsWindow + Notifications + OSD + LockScreen.
ShellRoot {
    id: root
    property bool barVisible: true

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        Bar {}
    }

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        Dock {}
    }

    Variants {
        model: Quickshell.screens
        SettingsWindow { required property var modelData; targetScreen: modelData }
    }

    AppGrid {}
    Notifications {}
    Osd {}
    LockScreen {}

    // `qs ipc call bar toggle` (bound to SUPER+SHIFT+Space)
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
    }

    IpcHandler {
        target: "ai"
        function toggle(): void { Status.toggleSuperDeck("ai"); }
        function tty(): void { Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh toggle"]); }
        function setAgent(agent: string): void { Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh select-agent '" + agent + "'"]); }
    }
}
