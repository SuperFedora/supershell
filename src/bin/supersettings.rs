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

fn resolve_page(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Some("home".into());
    }
    if let Some((cat, rest)) = trimmed.split_once(':') {
        let norm_cat = resolve_page(cat)?;
        return Some(format!("{norm_cat}:{rest}"));
    }
    let page = match trimmed.to_ascii_lowercase().as_str() {
        "home" | "overview" | "dashboard" | "main" | "0" | "00" => "home",
        "system" | "sys" | "display" | "displays" | "audio" | "sound" | "1" | "01" => "system",
        "devices" | "bluetooth" | "bt" | "printers" | "printer" | "input" | "keyboard" | "mouse" | "2" | "02" => "devices",
        "network" | "net" | "wifi" | "3" | "03" => "network",
        "ai" | "llm" | "ollama" | "models" | "openclaw" | "agents" | "4" | "04" => "ai",
        "personalization" | "theme" | "appearance" | "5" | "05" => "personalization",
        "wallpaper" | "wallpapers" | "background" => "wallpaper",
        "windowing" | "shell" | "multitasking" | "dock" | "bar" | "6" | "06" => "windowing",
        "notifications" | "notifs" | "banners" | "clock" | "7" | "07" => "notifications",
        "apps" | "forge" | "startup" | "autostart" | "8" | "08" => "apps",
        "accounts" | "users" | "user" | "9" | "09" => "accounts",
        "profile" => "profile",
        "accessibility" | "a11y" | "acc" | "10" => "accessibility",
        "power" | "state" | "updates" | "recovery" | "11" => "power",
        _ => return None,
    };
    Some(page.into())
}

fn open_gui(target: &str) {
    let _ = qs_call("settings", &["open", target]);
    play_sfx("click");
}

fn print_help() {
    println!(
        "SuperSettings v{} — Windows 11 Style Wayland GUI Settings & Native Rust Probe Engine",
        env!("CARGO_PKG_VERSION")
    );
    println!("Usage:");
    println!("  supersettings                       Open the GUI Settings window on the Home dashboard");
    println!("  supersettings open [page]           Open the GUI Settings window to a specific page");
    println!("  supersettings toggle [page]         Toggle the GUI Settings window (or open page)");
    println!("  supersettings close                 Close the GUI Settings window");
    println!("  supersettings probe                 Emit pipe-delimited system telemetry for Quickshell");
    println!("  supersettings apply <dom> <val>     Apply a hardware, mode, theme, or a11y setting");
    println!("  supersettings list                  List all Settings pages and current hardware status");
}

fn open_or_exit(raw: &str, announce: bool) {
    match resolve_page(raw) {
        Some(target) => {
            open_gui(&target);
            if announce {
                println!("[OK] Opened SuperSettings GUI page: {target}");
            }
        }
        None => {
            eprintln!("[FAIL] Unknown SuperSettings command or page: {raw}");
            print_help();
            process::exit(2);
        }
    }
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
            open_or_exit(page, false);
        }
        "version" | "--version" | "-V" => {
            println!("supersettings {} (SuperFedora/supershell)", env!("CARGO_PKG_VERSION"));
        }
        "probe" | "--probe" | "settings-probe" => print_probe(),
        "apply" | "--apply" | "settings-apply" => process::exit(apply_setting(&args[1..])),
        "profile" | "theme" if args.len() > 1 => process::exit(apply_setting(&args)),
        "mode" | "hardware" | "vaapi" | "palette" | "corners" | "ui-scale"
        | "animations" | "nightlight" | "orca" | "mono-audio" | "touchpad" => {
            process::exit(apply_setting(&args))
        }
        "open" | "--open" | "item" | "--item" => {
            let page = if args.len() > 1 { args[1..].join(":") } else { "home".to_string() };
            open_or_exit(&page, true);
        }
        "toggle" | "--toggle" => {
            if args.len() > 1 {
                open_or_exit(&args[1..].join(":"), false);
            } else {
                let _ = qs_call("settings", &["toggle"]);
                play_sfx("click");
            }
        }
        "close" | "--close" => {
            let _ = qs_call("settings", &["close"]);
        }
        "list" | "--list" | "status" | "--status" => {
            for &(id, title, desc) in PAGES {
                println!("  {:<16} {:<26} {}", id, title, desc);
            }
            print_probe();
        }
        "-h" | "--help" | "help" => print_help(),
        other => open_or_exit(other, false),
    }
}
