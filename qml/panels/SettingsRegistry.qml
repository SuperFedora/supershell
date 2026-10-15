import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."

// Declarative Cross-Listed Windows-Style Settings Catalog (38 Settings across 10 First-Principles Pillars).
QtObject {
    id: reg
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var batDev: UPower.displayDevice
    readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 100
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    readonly property var categories: [
        { id: "system",          tag: "[SYS]", icon: "󰍹", title: "System & Display",         sub: "Display scale, GPU VA-API codecs, brightness, night light, sound & storage" },
        { id: "devices",         tag: "[DEV]", icon: "󰂯", title: "Bluetooth & Devices",      sub: "Printers, scanners, Bluetooth, touchpad, keyboard & camera" },
        { id: "network",         tag: "[NET]", icon: "󰤨", title: "Network & Internet",       sub: "Wi-Fi, Ethernet, VPN / Tailscale, firewall & DNS" },
        { id: "personalization", tag: "[UI]",  icon: "󰸉", title: "Personalization",          sub: "16-Bit palettes, Day/Night mode, bevels, OpenRGB & saver" },
        { id: "windowing",       tag: "[WM]",  icon: "󰕮", title: "Windowing & Docks",        sub: "Top bar icons, Quattro dock, workspace tiling & window gaps" },
        { id: "notifications",   tag: "[NTF]", icon: "󰂚", title: "Notifications & Banners",  sub: "Do Not Disturb, alert history, 16-bit banners, 10 Cast Specialists & clocks" },
        { id: "apps",            tag: "[APP]", icon: "󰀻", title: "Apps & Source Forge",      sub: "Chromeless Firefox WebApps, -march=native compiler & startup" },
        { id: "accounts",        tag: "[USR]", icon: "󰄽", title: "Accounts & Users",         sub: "User profile, lock screen, biometrics, SSH keys & workstation clone" },
        { id: "accessibility",   tag: "[ACC]", icon: "󰌌", title: "Accessibility",            sub: "UI & text size, screen zoom, contrast, motion, Orca & audio" },
        { id: "power",           tag: "[PWR]", icon: "󰁹", title: "Power, Modes & Vault",     sub: "Workstation modes, Battery tank, Coffee idle timer, updates & Btrfs Time-Machine" }
    ]

    readonly property var items: [
        // 1. SYSTEM & DISPLAY (also cross-listed in Accessibility / Devices / Power)
        { id: "disp-scale", cats: ["system", "accessibility"], tag: "[SYS]", title: "Monitor Resolution & HiDPI Scale",
          sub: "Wayland fractional & integer output scaling for sharp text and workstation ergonomics", kw: "display monitor screen resolution scale hidpi dpi 1x 1.25x 1.5x fractional",
          acts: [ { l: "[ 1.0x NATIVE ]", act: "cmd", v: "hyprctl keyword monitor ,preferred,auto,1" }, { l: "[ 1.25x BALANCED ]", act: "cmd", v: "hyprctl keyword monitor ,preferred,auto,1.25" }, { l: "[ 1.5x HI-DPI ]", act: "cmd", v: "hyprctl keyword monitor ,preferred,auto,1.5" } ] },
        { id: "sys-gpu", cats: ["system", "devices"], tag: "[SYS]", title: "GPU Hardware Video & Zero-Copy DMABUF (VA-API)",
          sub: Status.gpuArch + "  ·  Driver: " + Status.gpuDriver + "  ·  " + Status.gpuCodecs + "  ·  " + Status.gpuDmabuf, kw: "gpu video vaapi codecs ffmpeg dmabuf hardware acceleration amd intel nvidia firefox",
          acts: [ { l: "[ OPTIMIZE GPU / VA-API ]", act: "cmd", v: "~/.local/bin/supersettings apply hardware optimize || ~/.local/bin/sf hardware optimize", on: Status.gpuDmabuf.includes("Active") }, { l: "[ PROBE GPU ]", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/sf hardware status; echo; vainfo 2>/dev/null || true; read -n 1'" } ] },
        { id: "disp-bright", cats: ["system", "power"], tag: "[SYS]", title: "Display Panel Brightness",
          sub: "Current Backlight Level: " + Math.round(Status.brightness * 100) + "%  ·  Hardware ACPI / eDP Backlight", kw: "brightness backlight screen dim luminance",
          acts: [ { l: "[ - 10% ]", act: "bright", v: -0.1 }, { l: "[ 50% ]", act: "brightSet", v: 0.5, on: Math.abs(Status.brightness - 0.5) < 0.06 }, { l: "[ 100% ]", act: "brightSet", v: 1.0, on: Status.brightness >= 0.95 }, { l: "[ + 10% ]", act: "bright", v: 0.1 } ] },
        { id: "disp-night", cats: ["system", "personalization", "accessibility"], tag: "[SYS]", title: "Night Light & Eye Care Filter (wlsunset)",
          sub: Status.nightLightRunning ? "ACTIVE  ·  Warm color temperature filter reducing blue light" : "OFF  ·  Standard calibrated sRGB display temperature (6500K)", kw: "night light blue filter warm eye care wlsunset kelvin 4000k 3400k",
          acts: [ { l: "[ 4000K WARM ]", act: "cmd", v: "~/.local/bin/supersettings apply nightlight 4000 || ~/.local/bin/sf settings-apply nightlight 4000", on: Status.nightLightRunning }, { l: "[ 3400K EXTRA WARM ]", act: "cmd", v: "~/.local/bin/supersettings apply nightlight 3400 || ~/.local/bin/sf settings-apply nightlight 3400" }, { l: "[ OFF (6500K) ]", act: "cmd", v: "~/.local/bin/supersettings apply nightlight off || ~/.local/bin/sf settings-apply nightlight off", on: !Status.nightLightRunning } ] },
        { id: "snd-spk", cats: ["system", "devices"], tag: "[SYS]", title: "Output Speaker Volume & Mute",
          sub: (Status.spkMuted ? "MUTED  ·  " : "ACTIVE  ·  ") + "Output Level: " + Math.round(Status.spkVol * 100) + "%  ·  PipeWire Default Audio Sink", kw: "sound audio speaker volume output mute pipewire sink headphones",
          acts: [ { l: Status.spkMuted ? "[ UNMUTE ]" : "[ MUTE ]", act: "spkMute", on: Status.spkMuted, danger: Status.spkMuted }, { l: "[ - 10% ]", act: "spkStep", v: -0.1 }, { l: "[ 60% ]", act: "spkSet", v: 0.6 }, { l: "[ + 10% ]", act: "spkStep", v: 0.1 }, { l: "[ MIXER ]", act: "cmd", v: "pavucontrol || kitty --class floating-tui -e wiremix" } ] },
        { id: "snd-mic", cats: ["system", "devices"], tag: "[DEV]", title: "Input Microphone Gain & Privacy Kill-Switch",
          sub: (Status.micMuted ? "HARDWARE MUTED (LOCKED)  ·  " : "LIVE INPUT  ·  ") + "Gain: " + Math.round(Status.micVol * 100) + "%", kw: "sound audio microphone mic input gain mute privacy voice",
          acts: [ { l: Status.micMuted ? "[ MIC MUTED ]" : "[ MIC LIVE ]", act: "micMute", on: !Status.micMuted, danger: Status.micMuted }, { l: "[ - 10% ]", act: "micStep", v: -0.1 }, { l: "[ 100% ]", act: "micSet", v: 1.0 }, { l: "[ + 10% ]", act: "micStep", v: 0.1 } ] },
        { id: "sys-storage", cats: ["system", "power"], tag: "[SYS]", title: "Storage Volumes & Btrfs Filesystem Usage",
          sub: "Root (/): " + Status.diskRoot + "  ·  Home (/home): " + Status.diskHome + "  ·  CPU: " + Status.cpu + "%  ·  RAM: " + Status.mem + "% (" + Status.tempC + "°C)", kw: "storage disk drive space btrfs ssd nvme cpu ram memory temperature btop fastfetch",
          acts: [ { l: "[ LAUNCH BTOP++ ]", act: "cmd", v: "kitty --class floating-tui -e btop" }, { l: "[ DISK ANALYZER ]", act: "cmd", v: "baobab || kitty --class floating-tui -e sh -c 'df -h; echo; lsblk; read -n 1'" }, { l: "[ FASTFETCH ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'fastfetch; read -n 1'" } ] },

        // 2. BLUETOOTH & DEVICES (Printers, Scanners, Input, Camera)
        { id: "dev-printers", cats: ["devices", "system"], tag: "[DEV]", title: "Printers & Scanners (CUPS Print Spooler)",
          sub: Status.printerSummary + "  ·  Default Printer: " + Status.defaultPrinter, kw: "printer printers scanner scanners cups print queue paper lpstat usb network printer test page",
          acts: [ { l: "[ + ADD / MANAGE PRINTERS ]", act: "cmd", v: "system-config-printer || xdg-open http://localhost:631", on: Status.cupsActive }, { l: "[ CUPS WEB ADMIN (:631) ]", act: "cmd", v: "xdg-open http://localhost:631" }, { l: "[ PRINT TEST PAGE ]", act: "cmd", v: "lp /usr/share/cups/data/testprint && notify-send -a SuperFedora 'Printer Queue' 'Sent test page to default printer'" }, { l: Status.cupsActive ? "[ SPOOLER: ONLINE ]" : "[ ENABLE CUPS ]", act: "cmd", v: "pkexec systemctl enable --now cups && qs ipc call status refresh", on: Status.cupsActive } ] },
        { id: "dev-scanners", cats: ["devices"], tag: "[DEV]", title: "Document Scanners (SANE / Simple Scan)",
          sub: "USB & Network AirScan / eSCL document scanning via SANE backends", kw: "scanner scan document sane airscan pdf image",
          acts: [ { l: "[ OPEN DOCUMENT SCANNER ]", act: "cmd", v: "simple-scan || naps2 || notify-send -a SuperFedora 'Scanner' 'Install simple-scan via: sudo dnf install simple-scan'" }, { l: "[ DETECT SCANNERS ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'scanimage -L || sane-find-scanner; echo; read -n 1 -p \"Press any key...\"'" } ] },
        { id: "dev-bt", cats: ["devices", "network"], tag: "[DEV]", title: "Bluetooth Adapter & Peripheral Pairing",
          sub: reg.btEnabled ? "RADIO ON  ·  Discovering & managing wireless headphones, mice, and keyboards" : "RADIO OFF  ·  Bluetooth adapter disabled", kw: "bluetooth bt wireless pair headphones mouse keyboard controller bluez",
          acts: [ { l: reg.btEnabled ? "[ BLUETOOTH: ON ]" : "[ BLUETOOTH: OFF ]", act: "cmd", v: reg.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", on: reg.btEnabled }, { l: "[ SCAN 10s ]", act: "cmd", v: "bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &" }, { l: "[ BLUEMAN / TUI ]", act: "cmd", v: "blueman-manager || kitty --class floating-tui -e bluetuith || kitty --class floating-tui -e bluetoothctl" } ] },
        { id: "dev-touchpad", cats: ["devices", "accessibility"], tag: "[DEV]", title: "Touchpad, TrackPoint & Mouse Pointer",
          sub: (Status.touchpadEnabled ? "TOUCHPAD ENABLED" : "TOUCHPAD DISABLED") + "  ·  Natural scrolling, tap-to-click, and disable-while-typing active", kw: "touchpad trackpoint mouse pointer cursor natural scroll tap to click input",
          acts: [ { l: Status.touchpadEnabled ? "[ TOUCHPAD: ON ]" : "[ TOUCHPAD: OFF ]", act: "cmd", v: "~/.config/hypr/scripts/toggle-touchpad.sh touchpad && qs ipc call status refresh", on: Status.touchpadEnabled }, { l: "[ NATURAL SCROLL: ON ]", act: "cmd", v: "hyprctl keyword input:touchpad:natural_scroll true", on: true }, { l: "[ INVERT SCROLL ]", act: "cmd", v: "hyprctl keyword input:touchpad:natural_scroll false" } ] },
        { id: "dev-kbd", cats: ["devices", "accessibility"], tag: "[DEV]", title: "Keyboard Layout, Repeat Speed & ThinkPad Backlight",
          sub: "Backlight: " + (Status.kbdBacklight === 0 ? "OFF" : (Status.kbdBacklight === 1 ? "LOW" : "HIGH")) + "  ·  US Layout (CapsLock = Compose)  ·  40 chars/sec repeat", kw: "keyboard kbd backlight thinkpad layout xkb repeat rate shortcuts keybindings",
          acts: [ { l: "[ KBD LIGHT: " + (Status.kbdBacklight === 0 ? "OFF" : (Status.kbdBacklight === 1 ? "LOW" : "HIGH")) + " ]", act: "kbdLight", on: Status.kbdBacklight > 0 }, { l: "[ SWITCH XKB LAYOUT ]", act: "cmd", v: "hyprctl switchxkblayout all next" }, { l: "[ SHORTCUTS (SUPER+F1) ]", act: "cmd", v: "~/.config/hypr/scripts/keybindings.sh" } ] },
        { id: "dev-cam", cats: ["devices", "accounts"], tag: "[DEV]", title: "Camera Privacy Driver Lock (uvcvideo)",
          sub: Status.webcamEnabled ? "CAMERA DRIVER ENABLED  ·  Apps may request video stream" : "KERNEL MODULE UNLOADED  ·  Zero-Trust Hardware Driver Lock", kw: "camera webcam video uvcvideo privacy security lock",
          acts: [ { l: Status.webcamEnabled ? "[ CAMERA: ENABLED ]" : "[ CAMERA: LOCKED ]", act: "webcam", on: Status.webcamEnabled, danger: !Status.webcamEnabled } ] },

        // 3. NETWORK & INTERNET
        { id: "net-wifi", cats: ["network"], tag: "[NET]", title: "Wi-Fi Wireless Radio & Saved Networks",
          sub: !Status.wifiEnabled ? "RADIO OFF" : (Status.netType === "wifi" && Status.ssid ? ("CONNECTED TO: " + Status.ssid + " (" + Status.signal + "%)") : "DISCONNECTED  ·  Select a network below"), kw: "wifi wireless wlan internet ssid network scan radio",
          acts: [ { l: Status.wifiEnabled ? "[ WI-FI: ON ]" : "[ WI-FI: OFF ]", act: "wifiToggle", on: Status.wifiEnabled }, { l: "[ RESCAN NETWORKS ]", act: "cmd", v: "nmcli device wifi rescan; sleep 1 && qs ipc call status refresh" }, { l: "[ NMTUI MANAGER ]", act: "cmd", v: "kitty --class floating-tui -e nmtui" } ] },
        { id: "net-ip", cats: ["network", "system"], tag: "[NET]", title: "IPv4 Routing, Gateway & DNS Resolver",
          sub: "Interface: " + Status.netIface + "  ·  IPv4: " + Status.netIpv4 + "  ·  Gateway: " + Status.netGateway + "  ·  DNS: " + Status.netDns, kw: "ethernet ip ipv4 gateway dns resolv router lan mac address",
          acts: [ { l: "[ COPY IP ADDRESS ]", act: "cmd", v: "printf '%s' '" + Status.netIpv4.split("/")[0] + "' | wl-copy && notify-send -a SuperFedora 'Network' 'Copied IPv4 address to clipboard'" }, { l: "[ FLUSH DNS CACHE ]", act: "cmd", v: "resolvectl flush-caches && notify-send -a SuperFedora 'DNS Resolver' 'Flushed systemd-resolved DNS cache'" }, { l: "[ EDIT CONNECTIONS ]", act: "cmd", v: "nm-connection-editor || kitty --class floating-tui -e nmtui-edit" } ] },
        { id: "net-vpn", cats: ["network", "accounts"], tag: "[NET]", title: "VPN, Tailscale Mesh & Firewalld Security",
          sub: "Firewall: " + Status.firewallState + "  ·  Active Tunnel / VPN: " + Status.vpnState, kw: "vpn tailscale wireguard firewall firewalld security port zone",
          acts: [ { l: Status.vpnState !== "None" ? ("[ VPN: " + Status.vpnState.toUpperCase() + " ]") : "[ TAILSCALE STATUS ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'tailscale status || nmcli connection show --active; echo; read -n 1'", on: Status.vpnState !== "None" }, { l: "[ FIREWALL CONFIG ]", act: "cmd", v: "firewall-config || kitty --class floating-tui -e sh -c 'sudo firewall-cmd --list-all; echo; read -n 1'" } ] },

        // 4. PERSONALIZATION
        { id: "ui-mode", cats: ["personalization", "system", "accessibility"], tag: "[UI]", title: "Color Mode & Window Corner Geometry",
          sub: "Active Theme: " + Theme.themeName.toUpperCase() + "  ·  Mode: " + Theme.mode.toUpperCase() + "  ·  Bevels: " + (Theme.corners === "rounded" ? "ROUNDED" : "SQUARE 90°"), kw: "theme dark light day night mode corners square rounded bevel appearance palette",
          acts: [ { l: "[ MODE: " + (Theme.mode === "light" ? "DAY (LIGHT)" : "NIGHT (DARK)") + " ]", act: "cmd", v: "~/.local/bin/supertheme toggle || ~/.local/bin/sf theme toggle", on: Theme.mode === "dark" }, { l: "[ CORNERS: " + (Theme.corners === "rounded" ? "ROUNDED" : "SQUARE 90°") + " ]", act: "cmd", v: "~/.local/bin/supertheme corners toggle || ~/.local/bin/sf theme corners toggle", on: Theme.corners === "square" }, { l: "[ NEXT PALETTE ]", act: "cmd", v: "~/.config/hypr/scripts/wallpaper.sh next" } ] },
        { id: "ui-saver", cats: ["personalization", "power"], tag: "[UI]", title: "Wallpaper & 16-Bit IdleScreen Arcade Saver",
          sub: "Full-screen randomized 16-bit SNES pixel scenes with SUPER FEDORA badge", kw: "wallpaper background screensaver idlescreen arcade pixel retro lock",
          acts: [ { l: "[ CYCLE WALLPAPER ]", act: "cmd", v: "~/.config/hypr/scripts/wallpaper.sh next" }, { l: "[ LAUNCH SCREENSAVER NOW ]", act: "cmdClose", v: "sleep 0.2; idlescreen start >/dev/null 2>&1 || ~/.local/bin/idlescreen start >/dev/null 2>&1" } ] },
        { id: "ui-sfx", cats: ["personalization", "notifications", "accessibility"], tag: "[UI]", title: "16-Bit Retro UI Audio Feedback (SFX)",
          sub: Status.sfxEnabled ? "ENABLED  ·  Tactile 16-bit synth audio blips on dock, tab, and alert actions" : "MUTED  ·  Silent UI interaction", kw: "sfx sound effects audio beep blip retro 16-bit feedback",
          acts: [ { l: Status.sfxEnabled ? "[ 16-BIT SFX: ON ]" : "[ 16-BIT SFX: OFF ]", act: "sfxToggle", on: Status.sfxEnabled }, { l: "[ TEST SOUND ]", act: "cmd", v: "~/.local/bin/supertheme sfx play confirm || ~/.local/bin/sf sfx play confirm" } ] },

        // 5. WINDOWING & DOCKS
        { id: "wm-dock", cats: ["windowing", "personalization"], tag: "[WM]", title: "Quattro App Dock Position & Auto-Hide",
          sub: "Position: " + String((Status.dockConfig && Status.dockConfig.position) || "bottom").toUpperCase() + "  ·  Visibility: " + ((Status.dockConfig && Status.dockConfig.showAlways === false) ? "AUTO-HIDE" : "ALWAYS ON"), kw: "dock panel bottom left right top autohide always on quattro bar",
          acts: [ { l: "[ BOTTOM ]", act: "dock", v: "position bottom", on: String((Status.dockConfig && Status.dockConfig.position) || "bottom") === "bottom" }, { l: "[ LEFT ]", act: "dock", v: "position left", on: String((Status.dockConfig && Status.dockConfig.position) || "") === "left" }, { l: "[ RIGHT ]", act: "dock", v: "position right", on: String((Status.dockConfig && Status.dockConfig.position) || "") === "right" }, { l: "[ TOP ]", act: "dock", v: "position top", on: String((Status.dockConfig && Status.dockConfig.position) || "") === "top" }, { l: (Status.dockConfig && Status.dockConfig.showAlways === false) ? "[ AUTO-HIDE ]" : "[ ALWAYS ON ]", act: "dock", v: "always toggle", on: !(Status.dockConfig && Status.dockConfig.showAlways === false) } ] },
        { id: "wm-layout", cats: ["windowing", "system"], tag: "[WM]", title: "Workspace Tiling Engine & Window Gaps",
          sub: "Default Layout: " + Status.defaultWsMode.toUpperCase() + "  ·  Switch between Dwindle, Master, Scrolling, and Floating", kw: "tiling layout dwindle master scrolling floating gaps window workspace cosmic hyprland",
          acts: [ { l: "[ CYCLE LAYOUT (SUPER+Y) ]", act: "cmd", v: "~/.config/hypr/scripts/toggle-tiling.sh cycle" }, { l: "[ TOGGLE GAPS (0px / 10px) ]", act: "cmd", v: "~/.config/hypr/scripts/toggle-gaps.sh" }, { l: "[ BAR OPACITY ]", act: "barOpacity", on: Theme.barOpacity >= 0.99 } ] },

        // 6. NOTIFICATIONS & BANNERS
        { id: "ntf-dnd", cats: ["notifications", "system"], tag: "[NTF]", title: "Do Not Disturb (DND) & Notification Queue",
          sub: (Status.dnd ? "DO NOT DISTURB ACTIVE (Popups suppressed)" : "ALERTS ACTIVE") + "  ·  Unread Notifications: " + Status.notifUnread, kw: "notifications dnd do not disturb bell alerts history clear toast",
          acts: [ { l: Status.dnd ? "[ DND: ON (SILENT) ]" : "[ DND: OFF (LIVE) ]", act: "notif", v: "toggleDnd", on: Status.dnd }, { l: "[ MARK ALL READ ]", act: "notif", v: "markAllRead" }, { l: "[ CLEAR HISTORY ]", act: "notif", v: "clearAll", danger: true } ] },
        { id: "ntf-banners", cats: ["notifications", "personalization", "accessibility"], tag: "[NTF]", title: "16-Bit Full-Width Workstation Banners",
          sub: "Arcade overlay banners for login readiness, high-priority warnings, updates & checkpoints", kw: "banner banners ready warning update complete checkpoint overlay alert",
          acts: [ { l: "[ READY ]", act: "banner", v: "ready" }, { l: "[ WARNING ]", act: "banner", v: "warning", danger: true }, { l: "[ UPDATE COMPLETE ]", act: "banner", v: "update" }, { l: "[ CHECKPOINT SAVED ]", act: "banner", v: "checkpoint" } ] },
        { id: "ntf-cast", cats: ["notifications"], tag: "[NTF]", title: "16-Bit Cast Comms — Core Specialists (1–5)",
          sub: "Animated pixel-art comms: AI Agent, Security Guard, Forge Builder, System Engineer & App", kw: "cast character comms portrait popup ai security builder engineer app",
          acts: [ { l: "[ 1: AI ]", act: "cast", v: "ai" }, { l: "[ 2: SECURITY ]", act: "cast", v: "security", danger: true }, { l: "[ 3: FORGE ]", act: "cast", v: "builder" }, { l: "[ 4: ENGINEER ]", act: "cast", v: "engineer" }, { l: "[ 5: APP ]", act: "cast", v: "app" } ] },
        { id: "ntf-cast-ext", cats: ["notifications"], tag: "[NTF]", title: "16-Bit Cast Comms — Tactical & Fleet Specialists (6–0)",
          sub: "Animated pixel-art comms: Network Navigator, System Medic, Vault Archivist, Fleet Commander & Audio Synth", kw: "cast character comms portrait popup navigator medic archivist commander synth",
          acts: [ { l: "[ 6: NAVIGATOR ]", act: "cast", v: "navigator" }, { l: "[ 7: MEDIC ]", act: "cast", v: "medic" }, { l: "[ 8: ARCHIVIST ]", act: "cast", v: "archivist" }, { l: "[ 9: COMMANDER ]", act: "cast", v: "commander" }, { l: "[ 0: SYNTH ]", act: "cast", v: "synth" } ] },
        { id: "ntf-clock", cats: ["notifications", "system"], tag: "[NTF]", title: "Top Bar Clock Format & Timezone",
          sub: "Timezone: " + Status.localTz + "  ·  Format: " + (Status.clock24h ? "24-Hour" : "12-Hour AM/PM") + (Status.clockSeconds ? " (with seconds)" : ""), kw: "clock time date timezone 24h 12h seconds world clock calendar",
          acts: [ { l: Status.clock24h ? "[ 24-HOUR ]" : "[ 12-HOUR ]", act: "clock24", on: Status.clock24h }, { l: Status.clockSeconds ? "[ SECONDS: ON ]" : "[ SECONDS: OFF ]", act: "clockSec", on: Status.clockSeconds }, { l: Status.autoTz ? "[ AUTO TZ: ON ]" : "[ AUTO TZ: OFF ]", act: "cmd", v: "gsettings set org.gnome.desktop.datetime automatic-timezone " + (!Status.autoTz), on: Status.autoTz } ] },

        // 7. APPS & SOURCE FORGE
        { id: "app-defaults", cats: ["apps", "system"], tag: "[APP]", title: "Default Workstation Applications",
          sub: "Browser: Firefox  ·  Terminal: Kitty  ·  Files: Nautilus  ·  Editor: Neovim (nvim)", kw: "default apps browser firefox terminal kitty file manager nautilus editor neovim",
          acts: [ { l: "[ BROWSER ]", act: "cmdClose", v: "firefox" }, { l: "[ TERMINAL ]", act: "cmdClose", v: "kitty" }, { l: "[ FILES ]", act: "cmdClose", v: "nautilus" }, { l: "[ NEOVIM ]", act: "cmdClose", v: "kitty -e nvim" } ] },

        // 8. ACCOUNTS & USERS
        { id: "usr-profile", cats: ["accounts", "system"], tag: "[USR]", title: "Active Workstation User Account & Privileges",
          sub: Status.userAccount + " (" + Status.userUid + ")  ·  Shell: " + Status.userShell + "  ·  Groups: " + Status.userGroups, kw: "user account profile username hostname uid sudo wheel groups shell bash zsh",
          acts: [ { l: "[ CHANGE PASSWORD ]", act: "cmd", v: "kitty --class floating-tui -e passwd" }, { l: "[ USER GROUPS ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'id; echo; groups; echo; read -n 1 -p \"Press any key...\"'" }, { l: "[ SWITCH SESSION ]", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/superlock || ~/.local/bin/sf session'" } ] },
        { id: "usr-security", cats: ["accounts", "power"], tag: "[USR]", title: "Sign-In Options, Screen Lock & Biometrics (fprintd)",
          sub: Status.fprintStatus + "  ·  Instant Wayland Session Lock (Super + Escape)", kw: "lock screen password fingerprint fprintd biometric security sign in login pam",
          acts: [ { l: "[ LOCK SCREEN NOW ]", act: "cmdClose", v: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session" }, { l: "[ ENROLL FINGERPRINT ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'fprintd-enroll || echo \"No fingerprint reader detected\"; read -n 1'" } ] },
        { id: "usr-ssh", cats: ["accounts", "network"], tag: "[USR]", title: "SSH Cryptographic Identity & Public Key",
          sub: Status.sshStatus + "  ·  Used for GitHub, remote servers & Forge authentication", kw: "ssh key pubkey ed25519 rsa github git crypto agent",
          acts: [ { l: "[ COPY SSH PUBKEY ]", act: "cmd", v: "cat ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub 2>/dev/null | head -n1 | wl-copy && notify-send -a SuperFedora 'SSH Identity' 'Copied public key to clipboard'" }, { l: "[ GENERATE ED25519 KEY ]", act: "cmd", v: "kitty --class floating-tui -e sh -c '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519; ls -la ~/.ssh; read -n 1'; qs ipc call status refresh" } ] },

        // 9. ACCESSIBILITY
        { id: "acc-fontsize", cats: ["accessibility", "system", "personalization"], tag: "[ACC]", title: "Text & UI Scaling Size (Touch & Vision Ergonomics)",
          sub: "Current UI Font Size: " + Theme.fontSize + "px (Icon Size: " + Theme.iconSize + "px)  ·  Scales bars, docks & panels immediately", kw: "accessibility a11y vision font text size scale large small readable touch",
          acts: [ { l: "[ COMPACT (13px) ]", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 13 || ~/.local/bin/sf settings-apply ui-scale 13", on: Theme.fontSize === 13 }, { l: "[ DEFAULT (14px) ]", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 14 || ~/.local/bin/sf settings-apply ui-scale 14", on: Theme.fontSize === 14 }, { l: "[ LARGE (16px) ]", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 16 || ~/.local/bin/sf settings-apply ui-scale 16", on: Theme.fontSize === 16 }, { l: "[ EXTRA LARGE (18px) ]", act: "cmd", v: "~/.local/bin/supersettings apply ui-scale 18 || ~/.local/bin/sf settings-apply ui-scale 18", on: Theme.fontSize >= 18 } ] },
        { id: "acc-zoom", cats: ["accessibility", "system"], tag: "[ACC]", title: "Desktop Magnifier & Screen Zoom",
          sub: "Zoom in on any workspace region using Super + Equals (=) or Super + Minus (-)", kw: "accessibility zoom magnifier screen vision enlarge",
          acts: [ { l: "[ ZOOM IN (+) ]", act: "cmd", v: "~/.config/hypr/scripts/zoom.sh in" }, { l: "[ ZOOM OUT (-) ]", act: "cmd", v: "~/.config/hypr/scripts/zoom.sh out" }, { l: "[ RESET 1.0x ]", act: "cmd", v: "hyprctl keyword cursor:zoom_factor 1.0" } ] },
        { id: "acc-motion", cats: ["accessibility", "personalization", "windowing"], tag: "[ACC]", title: "Reduce Motion & High-Contrast 90° Bevels",
          sub: "Animations: " + (Status.animEnabled ? "ENABLED" : "REDUCED (INSTANT)") + "  ·  Corners: " + (Theme.corners === "square" ? "SHARP 90° CARTRIDGE" : "ROUNDED"), kw: "accessibility reduce motion animations high contrast borders bevels square",
          acts: [ { l: Status.animEnabled ? "[ MOTION: SMOOTH ]" : "[ MOTION: REDUCED ]", act: "cmd", v: "~/.local/bin/supersettings apply animations toggle || ~/.local/bin/sf settings-apply animations toggle", on: !Status.animEnabled }, { l: Theme.corners === "square" ? "[ 90° SHARP BEVELS ]" : "[ ROUNDED BEVELS ]", act: "cmd", v: "~/.local/bin/supertheme corners toggle || ~/.local/bin/sf theme corners toggle", on: Theme.corners === "square" } ] },
        { id: "acc-orca", cats: ["accessibility"], tag: "[ACC]", title: "Screen Reader (Orca Speech Synthesizer) & Mono Audio",
          sub: "Screen Reader: " + (Status.orcaRunning ? "ACTIVE (SPEAKING)" : "OFF") + "  ·  Audio Mode: " + (Status.monoAudio ? "MONO" : "STEREO"), kw: "accessibility screen reader orca speech blind hearing mono audio",
          acts: [ { l: Status.orcaRunning ? "[ ORCA READER: ON ]" : "[ ORCA READER: OFF ]", act: "cmd", v: "~/.local/bin/supersettings apply orca toggle || ~/.local/bin/sf settings-apply orca toggle", on: Status.orcaRunning }, { l: Status.monoAudio ? "[ AUDIO: MONO ]" : "[ AUDIO: STEREO ]", act: "cmd", v: "~/.local/bin/supersettings apply mono-audio toggle || ~/.local/bin/sf settings-apply mono-audio toggle", on: Status.monoAudio } ] },

        // 10. POWER, MODES & VAULT
        { id: "pwr-mode", cats: ["power", "system", "personalization"], tag: "[PWR]", title: "16-Bit Workstation Mode Profile (Tuned + Visual + Audio)",
          sub: "Active Profile: " + Status.workstationMode.toUpperCase() + "  ·  PackageKit: " + Status.pkgkitMode, kw: "mode profile stealth balanced forge arcade power performance governor",
          acts: [ { l: "[ STEALTH ]", act: "cmd", v: "~/.local/bin/supersettings apply mode stealth || ~/.local/bin/sf mode stealth", on: Status.workstationMode === "stealth" }, { l: "[ BALANCED ]", act: "cmd", v: "~/.local/bin/supersettings apply mode balanced || ~/.local/bin/sf mode balanced", on: Status.workstationMode === "balanced" }, { l: "[ FORGE ]", act: "cmd", v: "~/.local/bin/supersettings apply mode forge || ~/.local/bin/sf mode forge", on: Status.workstationMode === "forge" }, { l: "[ ARCADE ]", act: "cmd", v: "~/.local/bin/supersettings apply mode arcade || ~/.local/bin/sf mode arcade", on: Status.workstationMode === "arcade" } ] },
        { id: "pwr-battery", cats: ["power", "system"], tag: "[PWR]", title: "Battery Health & ThinkPad Charge Thresholds",
          sub: (reg.batPresent ? (reg.batPct + "% (" + (reg.batCharging ? "CHARGING" : "DISCHARGING") + ")") : "AC LINE POWER") + (Status.bat0Present ? ("  ·  BAT0: " + Status.bat0Threshold) : ""), kw: "power battery charge threshold thinkpad longevity travel ac energy tank",
          acts: [ { l: "[ 80% LONGEVITY ]", act: "cmd", v: "pkexec sh -c 'echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold' && qs ipc call status refresh" }, { l: "[ 100% TRAVEL ]", act: "cmd", v: "pkexec sh -c 'echo 0 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold' && qs ipc call status refresh" } ] },
        { id: "pwr-idle", cats: ["power", "personalization", "accounts"], tag: "[PWR]", title: "Coffee / Idle Timer Behavior (Screensaver, Lock & DPMS)",
          sub: Status.idleMode === "lock" ? "LOCK ONLY (2m Saver -> 5m Lock · Screen stays ON so background work continues)" : (Status.idleMode === "screensaver" ? "SCREENSAVER ONLY (2m Saver · Never locks or powers off)" : "FULL AUTO-IDLE (2m Saver -> 5m Lock -> 10m Screen Power Off)"), kw: "power coffee idle timer screensaver lock dpms screen off stay awake",
          acts: [ { l: "[ POWER OFF (10m) ]", act: "cmd", v: "~/.config/hypr/scripts/toggle-idle.sh poweroff && qs ipc call status refresh", on: Status.idleMode === "poweroff" }, { l: "[ LOCK ONLY (NO OFF) ]", act: "cmd", v: "~/.config/hypr/scripts/toggle-idle.sh lock && qs ipc call status refresh", on: Status.idleMode === "lock" }, { l: "[ SAVER ONLY ]", act: "cmd", v: "~/.config/hypr/scripts/toggle-idle.sh screensaver && qs ipc call status refresh", on: Status.idleMode === "screensaver" }, { l: "[ SCREEN OFF NOW ]", act: "cmdClose", v: "sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off" } ] },
        { id: "pwr-updates", cats: ["power", "system", "apps"], tag: "[PWR]", title: "System Packages (DNF), Firmware (fwupd) & SuperFedora Updates",
          sub: "Keep Fedora Linux packages, LVFS hardware firmware, and SuperFedora modules up to date", kw: "update updates upgrade dnf firmware fwupd bios system packages",
          acts: [ { l: "[ DNF SYSTEM UPGRADE ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'sudo dnf upgrade --refresh; (~/.local/bin/supernotify --banner update || ~/.local/bin/sf notify --banner update); read -n 1'" }, { l: "[ FIRMWARE (FWUPD) ]", act: "cmd", v: "kitty --class floating-tui -e sh -c 'fwupdmgr refresh && fwupdmgr get-updates; read -n 1'" }, { l: "[ SUPERFEDORA AUDIT ]", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/sf status; read -n 1'" } ] },
        { id: "pwr-btrfs", cats: ["power", "system"], tag: "[PWR]", title: "Btrfs Time-Machine Snapshots & Baseline Rollback",
          sub: "Create an instant root filesystem snapshot before risky changes or diff/restore from Vault", kw: "btrfs snapshot snapper checkpoint rollback recovery backup restore time machine vault",
          acts: [ { l: "[ + SAVE CHECKPOINT ]", act: "cmd", v: "(~/.local/bin/sf snapshot create 'Settings Checkpoint' || pkexec snapper -c root create -d 'Settings Checkpoint') && (~/.local/bin/supernotify --banner checkpoint >/dev/null 2>&1 || true)", on: true }, { l: "[ TIME-MACHINE TUI ]", act: "cmd", v: "kitty --class floating-tui -e ~/.local/bin/sf tui snapshot" } ] },
        { id: "pwr-clone", cats: ["power", "accounts"], tag: "[PWR]", title: "Declarative Workstation Backup & Clone (workstation.toml)",
          sub: "Export or import theme, dock, forged binaries, WebApps, and mode state via ~/.config/superfedora/workstation.toml", kw: "export import backup clone workstation toml config declarative",
          acts: [ { l: "[ EXPORT WORKSTATION.TOML ]", act: "cmd", v: "~/.local/bin/sf export && notify-send -a SuperFedora 'Workstation Export' 'Saved ~/.config/superfedora/workstation.toml'" }, { l: "[ APPLY WORKSTATION.TOML ]", act: "cmd", v: "kitty --class floating-tui -e sh -c '~/.local/bin/sf import ~/.config/superfedora/workstation.toml; echo; read -n 1'" } ] },
        { id: "pwr-session", cats: ["power", "accounts"], tag: "[PWR]", title: "Session Power Actions (Lock, Suspend, Reboot & Shutdown)",
          sub: "Hardware power states and session lifecycle controls", kw: "power off shutdown reboot restart sleep suspend lock session",
          acts: [ { l: "[ LOCK ]", act: "cmdClose", v: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session" }, { l: "[ SUSPEND ]", act: "cmdClose", v: "systemctl suspend" }, { l: "[ REBOOT ]", act: "cmdClose", v: "systemctl reboot", danger: true }, { l: "[ POWER OFF ]", act: "cmdClose", v: "systemctl poweroff", danger: true } ] }
    ]
}
