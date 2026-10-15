import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."

// Windows 11 WinUI 3 Style Settings Catalog: Natural case, per-setting icons, sliders, pill toggles & segmented controls.
QtObject {
    id: reg
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var batDev: UPower.displayDevice
    readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 100
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    readonly property var aiAgents: [
        { id: "agy", l: "AGY" }, { id: "mcode", l: "MCode" }, { id: "grok", l: "Grok" },
        { id: "vibe", l: "Vibe" }, { id: "claude", l: "Claude" }, { id: "chatgpt", l: "Codex" }, { id: "ollama", l: "Ollama (Pi)" }
    ]
    function matchesQuery(item, q) {
        if (!q) return true;
        const hay = (item.title + " " + item.sub + " " + item.kw + " " + item.cats.join(" ")).toLowerCase();
        for (const w of q.split(/\s+/)) if (w && !hay.includes(w)) return false;
        return true;
    }
    function matchCountFor(catId, qStr) {
        const q = String(qStr || "").trim().toLowerCase(); let n = 0;
        for (const it of reg.items) if (it.cats.indexOf(catId) >= 0 && reg.matchesQuery(it, q)) n++;
        return n;
    }
    function escSh(s) { return String(s || "").replace(/'/g, "'\\''"); }

    readonly property var categories: [
        { id: "system",          icon: "󰍹", title: "System",               sub: "Display, sound, night light, GPU acceleration, storage" },
        { id: "devices",         icon: "󰂯", title: "Bluetooth & devices",  sub: "Bluetooth, printers, scanners, mouse, touchpad, keyboard, camera" },
        { id: "network",         icon: "󰤨", title: "Network & internet",   sub: "Wi-Fi, Ethernet, VPN, Tailscale, firewall, DNS" },
        { id: "personalization", icon: "󰸉", title: "Personalization",      sub: "Color themes, dark mode, window corners, wallpaper, screensaver" },
        { id: "windowing",       icon: "󰕮", title: "Multitasking & docks", sub: "App dock position, workspace tiling, window gaps, top bar" },
        { id: "notifications",   icon: "󰂚", title: "Notifications",        sub: "Do Not Disturb, alert banners, specialist comms, clock & region" },
        { id: "apps",            icon: "󰀻", title: "Apps & Forge",         sub: "Default apps, web apps, native source compiler, startup apps" },
        { id: "accounts",        icon: "󰄽", title: "Accounts",             sub: "Your info, sign-in options, fingerprint, SSH keys, workstation backup" },
        { id: "accessibility",   icon: "󰌌", title: "Accessibility",        sub: "Text size, magnifier, visual effects, screen reader, mono audio" },
        { id: "power",           icon: "󰁹", title: "Power & battery",      sub: "Power mode, battery levels, sleep & screen timeout, Btrfs snapshots" }
    ]

    readonly property var items: [
        // 1. SYSTEM
        { id: "disp-bright", cats: ["system", "power"], icon: "󰃠", title: "Brightness",
          sub: "Adjust built-in display backlight luminance", kw: "brightness backlight screen dim luminance display",
          slider: "bright", val: Status.brightness },
        { id: "disp-night", cats: ["system", "personalization", "accessibility"], icon: "󰖔", title: "Night light",
          sub: Status.nightLightRunning ? "Warm color filter active to reduce blue light" : "Use warmer colors to help block blue light", kw: "night light blue filter warm eye care wlsunset kelvin",
          toggle: { on: Status.nightLightRunning, act: "cmd", v: Status.nightLightRunning ? "~/.local/bin/supersettings apply nightlight off" : "~/.local/bin/supersettings apply nightlight 4000" },
          acts: [ { l: "4000K Warm", act: "cmd", v: "~/.local/bin/supersettings apply nightlight 4000", on: Status.nightLightRunning }, { l: "3400K Extra warm", act: "cmd", v: "~/.local/bin/supersettings apply nightlight 3400" } ] },
        { id: "disp-scale", cats: ["system", "accessibility"], icon: "󰍹", title: "Scale & layout",
          sub: "Change the size of text, apps, and other items on the display", kw: "display monitor screen resolution scale hidpi dpi 100 125 150 fractional",
          acts: [ { l: "100%", act: "cmd", v: "hyprctl keyword monitor ,preferred,auto,1" }, { l: "125%", act: "cmd", v: "hyprctl keyword monitor ,preferred,auto,1.25" }, { l: "150%", act: "cmd", v: "hyprctl keyword monitor ,preferred,auto,1.5" } ] },
        { id: "snd-spk", cats: ["system", "devices"], icon: Status.spkMuted ? "󰝟" : "󰕾", title: "Volume",
          sub: (Status.spkMuted ? "Muted  ·  " : "") + "PipeWire default output speaker & headphones", kw: "sound audio speaker volume output mute pipewire sink headphones",
          slider: "spk", val: Status.spkVol, muted: Status.spkMuted,
          acts: [ { l: "Sound mixer", act: "cmd", v: "pavucontrol || kitty --class floating-tui -e wiremix" } ] },
        { id: "snd-mic", cats: ["system", "devices"], icon: Status.micMuted ? "󰍭" : "󰍬", title: "Microphone input",
          sub: Status.micMuted ? "Microphone muted (hardware privacy lock)" : "Live input gain for voice and calls", kw: "sound audio microphone mic input gain mute privacy voice",
          slider: "mic", val: Status.micVol, muted: Status.micMuted },
        { id: "sys-gpu", cats: ["system", "devices"], icon: "󰢮", title: "Graphics & hardware acceleration",
          sub: Status.gpuArch + "  ·  " + Status.gpuDriver + "  ·  " + Status.gpuCodecs + " (" + Status.gpuDmabuf + ")", kw: "gpu video vaapi codecs ffmpeg dmabuf hardware acceleration amd intel nvidia firefox",
          acts: [ { l: "Optimize VA-API", act: "cmd", v: "~/.local/bin/supersettings apply hardware optimize || ~/.local/bin/sf hardware optimize", on: Status.gpuDmabuf.includes("Active") }, { l: "Diagnostics", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/sf hardware status; echo; vainfo 2>/dev/null || true; read -n 1'" } ] },
        { id: "sys-storage", cats: ["system", "power"], icon: "󰋊", title: "Storage",
          sub: "Root (/): " + Status.diskRoot + "  ·  Home (/home): " + Status.diskHome + "  ·  CPU " + Status.cpu + "%  ·  RAM " + Status.mem + "%", kw: "storage disk drive space btrfs ssd nvme cpu ram memory temperature btop fastfetch",
          acts: [ { l: "Task monitor", act: "cmd", v: "kitty --class floating-tui -e btop" }, { l: "Disk usage", act: "cmd", v: "baobab || kitty --class floating-tui -e sh -c 'df -h; echo; lsblk; read -n 1'" }, { l: "System info", act: "cmd", v: "kitty --class floating-tui -e sh -c 'fastfetch; read -n 1'" } ] },

        // 2. BLUETOOTH & DEVICES
        { id: "dev-bt", cats: ["devices", "network"], icon: "󰂯", title: "Bluetooth",
          sub: reg.btEnabled ? "Discoverable  ·  Manage wireless audio, mice, and keyboards" : "Bluetooth is turned off", kw: "bluetooth bt wireless pair headphones mouse keyboard controller bluez",
          toggle: { on: reg.btEnabled, act: "cmd", v: reg.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on" },
          acts: [ { l: "Scan nearby", act: "cmd", v: "bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &" }, { l: "Devices manager", act: "cmd", v: "blueman-manager || kitty --class floating-tui -e bluetuith || kitty --class floating-tui -e bluetoothctl" } ] },
        { id: "dev-printers", cats: ["devices", "system"], icon: "󰐪", title: "Printers & scanners",
          sub: Status.printerSummary + "  ·  Default: " + Status.defaultPrinter, kw: "printer printers scanner scanners cups print queue paper lpstat usb network printer test page",
          toggle: { on: Status.cupsActive, act: "cmd", v: "pkexec systemctl enable --now cups && qs ipc call status refresh" },
          acts: [ { l: "Add or manage", act: "cmd", v: "system-config-printer || xdg-open http://localhost:631" }, { l: "CUPS web (:631)", act: "cmd", v: "xdg-open http://localhost:631" }, { l: "Print test page", act: "cmd", v: "lp /usr/share/cups/data/testprint && notify-send -a SuperFedora 'Printer Queue' 'Sent test page to default printer'" } ] },
        { id: "dev-scanners", cats: ["devices"], icon: "󰚫", title: "Document scanner",
          sub: "USB and network AirScan / eSCL document scanning (SANE)", kw: "scanner scan document sane airscan pdf image",
          acts: [ { l: "Open scanner", act: "cmd", v: "simple-scan || naps2 || notify-send -a SuperFedora 'Scanner' 'Install simple-scan via: sudo dnf install simple-scan'" }, { l: "Detect scanners", act: "cmd", v: "kitty --class floating-tui -e sh -c 'scanimage -L || sane-find-scanner; echo; read -n 1 -p \"Press any key...\"'" } ] },
        { id: "dev-touchpad", cats: ["devices", "accessibility"], icon: "󰟸", title: "Touchpad & mouse",
          sub: "Natural scrolling, tap-to-click, and disable-while-typing", kw: "touchpad trackpoint mouse pointer cursor natural scroll tap to click input",
          toggle: { on: Status.touchpadEnabled, act: "cmd", v: "~/.config/hypr/scripts/toggle-touchpad.sh touchpad && qs ipc call status refresh" },
          acts: [ { l: "Natural scroll", act: "cmd", v: "hyprctl keyword input:touchpad:natural_scroll true", on: true }, { l: "Standard scroll", act: "cmd", v: "hyprctl keyword input:touchpad:natural_scroll false" } ] },
        { id: "dev-kbd", cats: ["devices", "accessibility"], icon: "󰌌", title: "Keyboard & shortcuts",
          sub: "Backlight: " + (Status.kbdBacklight === 0 ? "Off" : (Status.kbdBacklight === 1 ? "Low" : "High")) + "  ·  US layout (CapsLock = Compose)", kw: "keyboard kbd backlight thinkpad layout xkb repeat rate shortcuts keybindings",
          acts: [ { l: "Backlight: " + (Status.kbdBacklight === 0 ? "Off" : (Status.kbdBacklight === 1 ? "Low" : "High")), act: "kbdLight", on: Status.kbdBacklight > 0 }, { l: "Switch layout", act: "cmd", v: "hyprctl switchxkblayout all next" }, { l: "Keyboard shortcuts", act: "cmd", v: "~/.config/hypr/scripts/keybindings.sh" } ] },
        { id: "dev-cam", cats: ["devices", "accounts"], icon: "󰄀", title: "Camera privacy",
          sub: Status.webcamEnabled ? "Camera driver enabled for video calls" : "Kernel uvcvideo driver unloaded (hardware lock)", kw: "camera webcam video uvcvideo privacy security lock",
          toggle: { on: Status.webcamEnabled, act: "webcam" } },

        // 3. NETWORK & INTERNET
        { id: "net-wifi", cats: ["network"], icon: "󰤨", title: "Wi-Fi",
          sub: !Status.wifiEnabled ? "Wi-Fi is turned off" : (Status.netType === "wifi" && Status.ssid ? ("Connected to " + Status.ssid + " (" + Status.signal + "%)") : "Not connected  ·  Select a network below"), kw: "wifi wireless wlan internet ssid network scan radio",
          toggle: { on: Status.wifiEnabled, act: "wifiToggle" },
          acts: [ { l: "Rescan", act: "cmd", v: "nmcli device wifi rescan; sleep 1 && qs ipc call status refresh" }, { l: "Network TUI", act: "cmd", v: "kitty --class floating-tui -e nmtui" } ] },
        { id: "net-ip", cats: ["network", "system"], icon: "󰈀", title: "Ethernet, IP & DNS",
          sub: Status.netIface + "  ·  IPv4: " + Status.netIpv4 + "  ·  Gateway: " + Status.netGateway + "  ·  DNS: " + Status.netDns, kw: "ethernet ip ipv4 gateway dns resolv router lan mac address",
          acts: [ { l: "Copy IP", act: "cmd", v: "printf '%s' '" + Status.netIpv4.split("/")[0] + "' | wl-copy && notify-send -a SuperFedora 'Network' 'Copied IPv4 address'" }, { l: "Flush DNS", act: "cmd", v: "resolvectl flush-caches && notify-send -a SuperFedora 'DNS Resolver' 'Flushed DNS cache'" }, { l: "Advanced network", act: "cmd", v: "nm-connection-editor || kitty --class floating-tui -e nmtui-edit" } ] },
        { id: "net-vpn", cats: ["network", "accounts"], icon: "󰒃", title: "VPN & firewall",
          sub: "Firewall: " + Status.firewallState + "  ·  Active tunnel: " + Status.vpnState, kw: "vpn tailscale wireguard firewall firewalld security port zone",
          acts: [ { l: Status.vpnState !== "None" ? ("VPN: " + Status.vpnState) : "Tailscale status", act: "cmd", v: "kitty --class floating-tui -e sh -c 'tailscale status || nmcli connection show --active; echo; read -n 1'", on: Status.vpnState !== "None" }, { l: "Firewall settings", act: "cmd", v: "firewall-config || kitty --class floating-tui -e sh -c 'sudo firewall-cmd --list-all; echo; read -n 1'" } ] },

        // 4. PERSONALIZATION
        { id: "ui-mode", cats: ["personalization", "system", "accessibility"], icon: "󰸉", title: "Colors & window geometry",
          sub: "Theme: " + Theme.themeName + "  ·  Mode: " + (Theme.mode === "light" ? "Light" : "Dark") + "  ·  Corners: " + (Theme.corners === "rounded" ? "Rounded" : "Square"), kw: "theme dark light day night mode corners square rounded bevel appearance palette",
          acts: [ { l: "Dark", act: "cmd", v: "~/.local/bin/supertheme night || ~/.local/bin/sf theme night", on: Theme.mode === "dark" }, { l: "Light", act: "cmd", v: "~/.local/bin/supertheme day || ~/.local/bin/sf theme day", on: Theme.mode === "light" }, { l: "Rounded", act: "cmd", v: "~/.local/bin/supertheme corners rounded || ~/.local/bin/sf theme corners rounded", on: Theme.corners === "rounded" }, { l: "Square", act: "cmd", v: "~/.local/bin/supertheme corners square || ~/.local/bin/sf theme corners square", on: Theme.corners === "square" } ] },
        { id: "ui-saver", cats: ["personalization", "power"], icon: "󰸉", title: "Background & screensaver",
          sub: "Cycle desktop wallpaper or launch the IdleScreen screensaver", kw: "wallpaper background screensaver idlescreen arcade pixel retro lock",
          acts: [ { l: "Next wallpaper", act: "cmd", v: "~/.config/hypr/scripts/wallpaper.sh next" }, { l: "Preview screensaver", act: "cmdClose", v: "sleep 0.2; idlescreen start >/dev/null 2>&1 || ~/.local/bin/idlescreen start >/dev/null 2>&1" } ] },
        { id: "ui-sfx", cats: ["personalization", "notifications", "accessibility"], icon: "󰓃", title: "System sound effects",
          sub: Status.sfxEnabled ? "Play subtle audio feedback on UI actions and notifications" : "UI sound effects are muted", kw: "sfx sound effects audio beep blip feedback",
          toggle: { on: Status.sfxEnabled, act: "sfxToggle" },
          acts: [ { l: "Test sound", act: "cmd", v: "~/.local/bin/supertheme sfx play confirm || ~/.local/bin/sf sfx play confirm" } ] },

        // 5. MULTITASKING & DOCKS
        { id: "wm-dock", cats: ["windowing", "personalization"], icon: "󰘔", title: "Taskbar & app dock",
          sub: "Edge: " + String((Status.dockConfig && Status.dockConfig.position) || "bottom") + "  ·  Behavior: " + ((Status.dockConfig && Status.dockConfig.showAlways === false) ? "Auto-hide" : "Always visible"), kw: "dock panel bottom left right top autohide always on quattro bar",
          acts: [ { l: "Bottom", act: "dock", v: "position bottom", on: String((Status.dockConfig && Status.dockConfig.position) || "bottom") === "bottom" }, { l: "Left", act: "dock", v: "position left", on: String((Status.dockConfig && Status.dockConfig.position) || "") === "left" }, { l: "Right", act: "dock", v: "position right", on: String((Status.dockConfig && Status.dockConfig.position) || "") === "right" }, { l: "Top", act: "dock", v: "position top", on: String((Status.dockConfig && Status.dockConfig.position) || "") === "top" }, { l: "Auto-hide", act: "dock", v: "always toggle", on: Boolean(Status.dockConfig && Status.dockConfig.showAlways === false) } ] },
        { id: "wm-layout", cats: ["windowing", "system"], icon: "󰕮", title: "Snap & workspace tiling",
          sub: "Active layout: " + Status.defaultWsMode + "  ·  Manage window tiling and outer gaps", kw: "tiling layout dwindle master scrolling floating gaps window workspace cosmic hyprland",
          acts: [ { l: "Cycle layout", act: "cmd", v: "~/.config/hypr/scripts/toggle-tiling.sh cycle" }, { l: "Toggle gaps", act: "cmd", v: "~/.config/hypr/scripts/toggle-gaps.sh" }, { l: "Translucent bar", act: "barOpacity", on: Theme.barOpacity < 0.99 } ] },

        // 6. NOTIFICATIONS
        { id: "ntf-dnd", cats: ["notifications", "system"], icon: "󰂚", title: "Do not disturb",
          sub: (Status.dnd ? "Notifications are silenced" : "Notifications appear as banners") + "  ·  " + Status.notifUnread + " unread", kw: "notifications dnd do not disturb bell alerts history clear toast",
          toggle: { on: Status.dnd, act: "notif", v: "toggleDnd" },
          acts: [ { l: "Clear all", act: "notif", v: "clearAll" } ] },
        { id: "ntf-banners", cats: ["notifications", "personalization"], icon: "󰀨", title: "System status banners",
          sub: "Preview full-width overlay alerts for readiness, warnings, updates, and checkpoints", kw: "banner banners ready warning update complete checkpoint overlay alert",
          acts: [ { l: "Ready", act: "banner", v: "ready" }, { l: "Warning", act: "banner", v: "warning", danger: true }, { l: "Update", act: "banner", v: "update" }, { l: "Checkpoint", act: "banner", v: "checkpoint" } ] },
        { id: "ntf-cast", cats: ["notifications"], icon: "󰭹", title: "Specialist notifications (Core 1–5)",
          sub: "Test toast notifications for AI Agent, Security, Forge Builder, Engineer, and Apps", kw: "cast character comms portrait popup ai security builder engineer app",
          acts: [ { l: "AI Agent", act: "cast", v: "ai" }, { l: "Security", act: "cast", v: "security", danger: true }, { l: "Builder", act: "cast", v: "builder" }, { l: "Engineer", act: "cast", v: "engineer" }, { l: "App", act: "cast", v: "app" } ] },
        { id: "ntf-cast-ext", cats: ["notifications"], icon: "󰭹", title: "Specialist notifications (Fleet 6–0)",
          sub: "Test toast notifications for Navigator, Medic, Archivist, Commander, and Audio Synth", kw: "cast character comms portrait popup navigator medic archivist commander synth",
          acts: [ { l: "Navigator", act: "cast", v: "navigator" }, { l: "Medic", act: "cast", v: "medic" }, { l: "Archivist", act: "cast", v: "archivist" }, { l: "Commander", act: "cast", v: "commander" }, { l: "Synth", act: "cast", v: "synth" } ] },
        { id: "ntf-clock", cats: ["notifications", "system"], icon: "󰥔", title: "Date & time",
          sub: "Timezone: " + Status.localTz + "  ·  " + (Status.clock24h ? "24-hour clock" : "12-hour clock"), kw: "clock time date timezone 24h 12h seconds world clock calendar",
          toggle: { on: Status.clock24h, act: "clock24" },
          acts: [ { l: "Show seconds", act: "clockSec", on: Status.clockSeconds }, { l: "Auto timezone", act: "cmd", v: "gsettings set org.gnome.desktop.datetime automatic-timezone " + (!Status.autoTz), on: Status.autoTz } ] },

        // 7. APPS & FORGE
        { id: "app-defaults", cats: ["apps", "system"], icon: "󰀻", title: "Default apps",
          sub: "Web browser: Firefox  ·  Terminal: Kitty  ·  File Explorer: Nautilus  ·  Editor: Neovim", kw: "default apps browser firefox terminal kitty file manager nautilus editor neovim",
          acts: [ { l: "Firefox", act: "cmdClose", v: "firefox" }, { l: "Terminal", act: "cmdClose", v: "kitty" }, { l: "Files", act: "cmdClose", v: "nautilus" }, { l: "Neovim", act: "cmdClose", v: "kitty -e nvim" } ] },

        // 8. ACCOUNTS
        { id: "usr-profile", cats: ["accounts", "system"], icon: "󰄽", title: "Your account",
          sub: Status.userAccount + " (" + Status.userUid + ")  ·  Shell: " + Status.userShell + "  ·  Groups: " + Status.userGroups, kw: "user account profile username hostname uid sudo wheel groups shell bash zsh",
          acts: [ { l: "Change password", act: "cmd", v: "kitty --class floating-tui -e passwd" }, { l: "Group permissions", act: "cmd", v: "kitty --class floating-tui -e sh -c 'id; echo; groups; echo; read -n 1 -p \"Press any key...\"'" }, { l: "Desktop session", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/superlock || ~/.local/bin/sf session'" } ] },
        { id: "usr-security", cats: ["accounts", "power"], icon: "󰌾", title: "Sign-in options & biometrics",
          sub: Status.fprintStatus + "  ·  Session lock shortcut: Super + Escape", kw: "lock screen password fingerprint fprintd biometric security sign in login pam",
          acts: [ { l: "Lock screen", act: "cmdClose", v: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session" }, { l: "Fingerprint setup", act: "cmd", v: "kitty --class floating-tui -e sh -c 'fprintd-enroll || echo \"No fingerprint reader detected\"; read -n 1'" } ] },
        { id: "usr-ssh", cats: ["accounts", "network"], icon: "󰌆", title: "SSH cryptographic keys",
          sub: Status.sshStatus + "  ·  Used for GitHub, remote hosts, and Forge", kw: "ssh key pubkey ed25519 rsa github git crypto agent",
          acts: [ { l: "Copy public key", act: "cmd", v: "cat ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub 2>/dev/null | head -n1 | wl-copy && notify-send -a SuperFedora 'SSH Identity' 'Copied public key to clipboard'" }, { l: "Generate ED25519 key", act: "cmd", v: "kitty --class floating-tui -e sh -c '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519; ls -la ~/.ssh; read -n 1'; qs ipc call status refresh" } ] },

        // 9. ACCESSIBILITY
        { id: "acc-fontsize", cats: ["accessibility", "system", "personalization"], icon: "󰊄", title: "Text size",
          sub: "Current UI font size: " + Theme.fontSize + "px  ·  Resizes bars, docks, and settings immediately", kw: "accessibility a11y vision font text size scale large small readable",
          acts: [ { l: "Small (13px)", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 13 || ~/.local/bin/sf settings-apply ui-scale 13", on: Theme.fontSize === 13 }, { l: "Default (14px)", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 14 || ~/.local/bin/sf settings-apply ui-scale 14", on: Theme.fontSize === 14 }, { l: "Large (16px)", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 16 || ~/.local/bin/sf settings-apply ui-scale 16", on: Theme.fontSize === 16 }, { l: "Extra large (18px)", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 18 || ~/.local/bin/sf settings-apply ui-scale 18", on: Theme.fontSize >= 18 } ] },
        { id: "acc-zoom", cats: ["accessibility", "system"], icon: "󰍉", title: "Magnifier",
          sub: "Zoom in on any workspace area (Super + Plus / Super + Minus)", kw: "accessibility zoom magnifier screen vision enlarge",
          acts: [ { l: "Zoom in", act: "cmd", v: "~/.config/hypr/scripts/zoom.sh in" }, { l: "Zoom out", act: "cmd", v: "~/.config/hypr/scripts/zoom.sh out" }, { l: "Reset 100%", act: "cmd", v: "hyprctl keyword cursor:zoom_factor 1.0" } ] },
        { id: "acc-motion", cats: ["accessibility", "personalization", "windowing"], icon: "󰔟", title: "Animation effects",
          sub: Status.animEnabled ? "Smooth window and workspace transitions enabled" : "Animations disabled for instant response", kw: "accessibility reduce motion animations high contrast borders",
          toggle: { on: Status.animEnabled, act: "cmd", v: "~/.local/bin/supersettings apply animations toggle || ~/.local/bin/sf settings-apply animations toggle" } },
        { id: "acc-orca", cats: ["accessibility"], icon: "󰔊", title: "Narrator & mono audio",
          sub: "Orca screen reader: " + (Status.orcaRunning ? "On" : "Off") + "  ·  Audio output: " + (Status.monoAudio ? "Mono" : "Stereo"), kw: "accessibility screen reader orca speech blind hearing mono audio",
          toggle: { on: Status.orcaRunning, act: "cmd", v: "~/.local/bin/supersettings apply orca toggle || ~/.local/bin/sf settings-apply orca toggle" },
          acts: [ { l: Status.monoAudio ? "Mono audio: On" : "Mono audio: Off", act: "cmd", v: "~/.local/bin/supersettings apply mono-audio toggle || ~/.local/bin/sf settings-apply mono-audio toggle", on: Status.monoAudio } ] },

        // 10. POWER & BATTERY
        { id: "pwr-mode", cats: ["power", "system", "personalization"], icon: "󰓅", title: "Power mode",
          sub: "Optimize your workstation based on power use and performance (" + Status.workstationMode + ")", kw: "mode profile stealth balanced forge arcade power performance governor",
          acts: [ { l: "Best power efficiency", act: "cmd", v: "~/.local/bin/supersettings apply mode stealth || ~/.local/bin/sf mode stealth", on: Status.workstationMode === "stealth" }, { l: "Balanced", act: "cmd", v: "~/.local/bin/supersettings apply mode balanced || ~/.local/bin/sf mode balanced", on: Status.workstationMode === "balanced" }, { l: "Best performance", act: "cmd", v: "~/.local/bin/supersettings apply mode forge || ~/.local/bin/sf mode forge", on: Status.workstationMode === "forge" }, { l: "Arcade", act: "cmd", v: "~/.local/bin/supersettings apply mode arcade || ~/.local/bin/sf mode arcade", on: Status.workstationMode === "arcade" } ] },
        { id: "pwr-battery", cats: ["power", "system"], icon: "󰁹", title: "Battery saver & charge limit",
          sub: (reg.batPresent ? (reg.batPct + "% (" + (reg.batCharging ? "Charging" : "On battery") + ")") : "Plugged in (AC)") + (Status.bat0Present ? ("  ·  Threshold: " + Status.bat0Threshold) : ""), kw: "power battery charge threshold thinkpad longevity travel ac energy",
          acts: [ { l: "80% Longevity limit", act: "cmd", v: "pkexec sh -c 'echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold' && qs ipc call status refresh" }, { l: "100% Full charge", act: "cmd", v: "pkexec sh -c 'echo 0 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold' && qs ipc call status refresh" } ] },
        { id: "pwr-idle", cats: ["power", "personalization", "accounts"], icon: "󰒲", title: "Screen & sleep timeouts",
          sub: Status.idleMode === "lock" ? "Lock after 5m · Never turn off screen" : (Status.idleMode === "screensaver" ? "Screensaver only · Stay awake" : "Screensaver 2m · Lock 5m · Screen off 10m"), kw: "power coffee idle timer screensaver lock dpms screen off stay awake",
          acts: [ { l: "10m Screen off", act: "cmd", v: "~/.config/hypr/scripts/toggle-idle.sh poweroff && qs ipc call status refresh", on: Status.idleMode === "poweroff" }, { l: "Lock only", act: "cmd", v: "~/.config/hypr/scripts/toggle-idle.sh lock && qs ipc call status refresh", on: Status.idleMode === "lock" }, { l: "Stay awake", act: "cmd", v: "~/.config/hypr/scripts/toggle-idle.sh screensaver && qs ipc call status refresh", on: Status.idleMode === "screensaver" }, { l: "Turn screen off now", act: "cmdClose", v: "sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off" } ] },
        { id: "pwr-updates", cats: ["power", "system", "apps"], icon: "󰚰", title: "System & firmware updates",
          sub: "Check for Fedora DNF packages, LVFS hardware firmware, and SuperFedora updates", kw: "update updates upgrade dnf firmware fwupd bios system packages",
          acts: [ { l: "Check for updates", act: "cmd", v: "kitty --class floating-tui -e sh -c 'sudo dnf upgrade --refresh; (~/.local/bin/supernotify --banner update || ~/.local/bin/sf notify --banner update); read -n 1'" }, { l: "Device firmware", act: "cmd", v: "kitty --class floating-tui -e sh -c 'fwupdmgr refresh && fwupdmgr get-updates; read -n 1'" }, { l: "System health", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/sf status; read -n 1'" } ] },
        { id: "pwr-btrfs", cats: ["power", "system"], icon: "󰁯", title: "System recovery & Btrfs snapshots",
          sub: "Create an instant root filesystem restore point or roll back to a previous state", kw: "btrfs snapshot snapper checkpoint rollback recovery backup restore time machine vault",
          acts: [ { l: "Create restore point", act: "cmd", v: "(~/.local/bin/sf snapshot create 'Settings Checkpoint' || pkexec snapper -c root create -d 'Settings Checkpoint') && (~/.local/bin/supernotify --banner checkpoint >/dev/null 2>&1 || true)", on: true }, { l: "Open recovery manager", act: "cmd", v: "kitty --class floating-tui -e ~/.local/bin/sf tui snapshot" } ] },
        { id: "pwr-clone", cats: ["power", "accounts"], icon: "󰆓", title: "Workstation backup & clone (workstation.toml)",
          sub: "Export or import your theme, dock, forged apps, and settings to workstation.toml", kw: "export import backup clone workstation toml config declarative",
          acts: [ { l: "Export config", act: "cmd", v: "~/.local/bin/sf export && notify-send -a SuperFedora 'Workstation Export' 'Saved ~/.config/superfedora/workstation.toml'" }, { l: "Import config", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/sf import ~/.config/superfedora/workstation.toml; echo; read -n 1'" } ] },
        { id: "pwr-session", cats: ["power", "accounts"], icon: "󰐥", title: "Session power",
          sub: "Lock, suspend, restart, or shut down your workstation", kw: "power off shutdown reboot restart sleep suspend lock session",
          acts: [ { l: "Lock", act: "cmdClose", v: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session" }, { l: "Sleep", act: "cmdClose", v: "systemctl suspend" }, { l: "Restart", act: "cmdClose", v: "systemctl reboot", danger: true }, { l: "Shut down", act: "cmdClose", v: "systemctl poweroff", danger: true } ] }
    ]
}
