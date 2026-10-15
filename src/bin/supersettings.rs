// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use std::env;
use std::process;
use supershell::{
    play_sfx, qs_call,
    settings_engine::{apply_setting, print_probe},
};

const PAGES: &[(&str, &str, &str)] = &[
    ("home", "00 Home", "Device overview, live wallpaper preview, quick controls, personalization, Bluetooth & storage"),
    ("system", "01 System & Display", "Monitors, GPU VA-API Codecs, Audio, Brightness, Nightlight"),
    ("devices", "02 Devices & Bluetooth", "Bluetooth controllers, On-Demand CUPS Socket, Touchpad & Input"),
    ("network", "03 Network & VPN", "Wi-Fi SSIDs, Ethernet, DNS, Firewalld & WireGuard/Tailscale"),
    ("ai", "04 AI & LLM Servers", "Self-hosted GPU cluster, Ollama & vLLM endpoints, OpenClaw & CLI harnesses"),
    ("personalization", "05 Personalization", "16-Bit Rainbow Palettes, Day/Night Mode, Corners, Wallpapers"),
    ("windowing", "06 Windowing & Shell", "SuperDock Edge/Autohide, SuperBar HUD, VFR & Direct Scanout"),
    ("notifications", "07 Notifications & Clock", "Do Not Disturb, 10 Cast Specialists, 24h Clock & Overlay"),
    ("apps", "08 Apps & SuperForge", "2-Tier Binary Cache, -march=native Builds, Firefox WebApps"),
    ("accounts", "09 Accounts & Security", "User Groups, Shell, SSH ED25519 Keys, PAM & Fingerprint"),
    ("accessibility", "10 Accessibility", "UI Font Scale, Animations, Screen Reader (Orca), Mono Audio"),
    ("power", "11 Power, Mode & Vault", "Workstation Modes (Stealth/Balanced/Forge/Arcade) & Btrfs Vault"),
];

fn normalize_page(raw: &str) -> &'static str {
    match raw.trim().to_ascii_lowercase().as_str() {
        "" | "home" | "overview" | "dashboard" | "0" => "home",
        "ai" | "llm" | "ollama" | "models" | "openclaw" | "agents" => "ai",
        "system" | "sys" | "display" | "displays" | "audio" | "sound" | "1" => "system",
        "devices" | "bluetooth" | "bt" | "printers" | "printer" | "input" | "2" => "devices",
        "network" | "net" | "wifi" | "3" => "network",
        "personalization" | "theme" | "appearance" | "4" => "personalization",
        "windowing" | "shell" | "multitasking" | "dock" | "bar" | "5" => "windowing",
        "notifications" | "notifs" | "banners" | "clock" | "6" => "notifications",
        "apps" | "forge" | "startup" | "autostart" | "7" => "apps",
        "accounts" | "users" | "user" | "8" => "accounts",
        "accessibility" | "a11y" | "acc" | "9" => "accessibility",
        "power" | "state" | "updates" | "recovery" | "10" => "power",
        _ => "home",
    }
}

fn open_gui(page: &str) {
    let target = normalize_page(page);
    let _ = qs_call("settings", &["open", target]);
    play_sfx("click");
}

fn print_help() {
    println!("SuperSettings v0.4.2 — Windows 11 Style Wayland GUI Settings & Native Rust Probe Engine");
    println!("Usage:");
    println!("  supersettings                       Open the GUI Settings window on the Home dashboard");
    println!("  supersettings open [page]           Open the GUI Settings window to a specific page");
    println!("  supersettings toggle [page]         Toggle the GUI Settings window (or open page)");
    println!("  supersettings close                 Close the GUI Settings window");
    println!("  supersettings probe                 Emit pipe-delimited system telemetry for Quickshell");
    println!("  supersettings apply <dom> <val>     Apply a hardware, mode, theme, or a11y setting");
    println!("  supersettings list                  List all Settings pages and current hardware status");
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        open_gui("home");
        return;
    }

    let cmd = args[0].as_str();
    match cmd {
        "gui" | "tui" | "home" => {
            let page = args.get(1).map(|s| s.as_str()).unwrap_or("home");
            open_gui(page);
        }
        "version" | "--version" | "-V" => {
            println!("supersettings 0.4.2 (SuperFedora/supershell)");
        }
        "probe" | "settings-probe" => print_probe(),
        "apply" | "settings-apply" => process::exit(apply_setting(&args[1..])),
        "mode" | "profile" | "hardware" | "vaapi" | "theme" | "palette" | "corners"
        | "ui-scale" | "animations" | "nightlight" | "orca" | "mono-audio" => {
            process::exit(apply_setting(&args))
        }
        "open" => {
            let page = args.get(1).map(|s| s.as_str()).unwrap_or("home");
            let target = normalize_page(page);
            open_gui(target);
            println!("[OK] Opened SuperSettings GUI page: {target}");
        }
        "toggle" => {
            if let Some(p) = args.get(1) {
                open_gui(p);
            } else {
                let _ = qs_call("settings", &["toggle"]);
                play_sfx("click");
            }
        }
        "close" => {
            let _ = qs_call("settings", &["close"]);
        }
        "list" | "status" => {
            for &(id, title, desc) in PAGES {
                println!("  {:<16} {:<26} {}", id, title, desc);
            }
            print_probe();
        }
        "-h" | "--help" | "help" => print_help(),
        other => open_gui(other),
    }
}
