// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// supersettings.rs — Win11 Style Wayland Settings GUI Launcher & Apply CLI
// ==============================================================================

use std::env;
use std::process;
use supershell::{
    play_sfx, qs_call,
    settings_engine::{DOMAINS, apply_setting, print_probe},
};

/// GUI pages offered by the Quickshell Settings window.
const PAGES: &[(&str, &str, &str)] = &[
    ("home", "00 Home", "Device overview, live display preview, quick controls, Bluetooth & storage"),
    ("system", "01 System", "Display, Sound, Power & Battery, Storage & About"),
    ("devices", "02 Bluetooth & Devices", "Bluetooth controllers, Printers & Scanners, Camera, Mouse, Touchpad & Keyboard"),
    ("network", "03 Network & Internet", "Wi-Fi SSIDs, Ethernet, DNS, Firewalld & WireGuard/Tailscale VPN"),
    ("ai", "04 AI & LLM Vault", "Universal AI Endpoints, API Key Vault, LAN Discovery & CLI Agent Harnesses"),
    ("apps", "05 Apps", "Installed App Suites (GNOME/KDE/COSMIC), 12 Default App Roles, File Extensions & Startup"),
    ("accounts", "06 Accounts", "Your Info, Avatar, Sign-in Options, Fingerprint, SSH Keys & Workstation Backup"),
    ("time", "07 Time & Language", "Date & Time, World Clocks, Language & Region, Typing & Keyboard Layout"),
    ("gaming", "08 Gaming", "Game Mode & Performance Profiles, Screen Captures, Graphics & GPU VA-API"),
    ("accessibility", "09 Accessibility", "Text Size, Visual Effects, Magnifier, Narrator (Orca) & Mono Audio"),
    ("security", "10 Privacy & Security", "Firewall & Network Protection, Camera & Mic Privacy Locks, Biometrics & SSH"),
    ("update", "11 System Update", "System & Firmware Updates (DNF5 / Flatpak / LVFS) & Btrfs Restore Points"),
];

/// Applyable setting sections owned by this engine.
///
/// Theme, palette, corners and nightlight are deliberately absent: `supertheme` is
/// their single source of truth. Hardware controls (webcam, mic mute and
/// keyboard backlight) live here as native Rust toggles.
const SECTIONS: &[(&str, &[&str], &str)] = &[
    ("Hardware", &["touchpad", "webcam", "mic", "speaker", "kbd-backlight"], "Touchpad, Webcam, Mic Mute, Speaker & Keyboard Backlight"),
    ("Power & Display", &["dpms", "battery-limit", "mode", "hardware"], "DPMS Screen Power, Battery Charge Limit, Workstation Mode & VA-API"),
    ("Accessibility", &["ui-scale", "animations", "orca", "mono-audio"], "Text Size, Visual Effects, Narrator & Mono Audio"),
    ("System", &["default", "default-ext", "default-preset", "default-reset"], "12 Default App Roles, File Extensions & Desktop Presets"),
];

/// True when `name` is an applyable setting domain handled by the engine.
fn is_domain(name: &str) -> bool {
    DOMAINS.contains(&name)
}

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
        "system" | "sys" | "display" | "displays" | "audio" | "sound" | "power" | "multitasking" | "1" | "01" => "system",
        "devices" | "bluetooth" | "bt" | "printers" | "printer" | "input" | "keyboard" | "mouse" | "webcam" | "mic" | "speaker" | "2" | "02" => "devices",
        "network" | "net" | "wifi" | "3" | "03" => "network",
        "ai" | "llm" | "ollama" | "superagent" | "ai-providers" | "ai-endpoints" | "ai-cluster" | "ai-harness" | "4" | "04" | "12" => "ai",
        "apps" | "startup" | "autostart" | "default-apps" | "5" | "05" => "apps",
        "accounts" | "users" | "user" | "6" | "06" => "accounts",
        "profile" => "profile",
        "time" | "language" | "clock" | "region" | "locale" | "7" | "07" => "time",
        "gaming" | "game" | "captures" | "arcade" | "8" | "08" => "gaming",
        "accessibility" | "a11y" | "acc" | "9" | "09" => "accessibility",
        "security" | "privacy" | "firewall" | "ssh" | "10" => "security",
        "update" | "updates" | "recovery" | "btrfs" | "state" | "11" => "update",
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
        "SuperSettings v{} — Windows 11 Style Wayland GUI Settings & Native Rust Hardware Engine",
        env!("CARGO_PKG_VERSION")
    );
    println!("Usage:");
    println!("  supersettings                       Open the GUI Settings window on the Home dashboard");
    println!("  supersettings open [page]           Open the GUI Settings window to a specific page");
    println!("  supersettings toggle [page]         Toggle the GUI Settings window (or open page)");
    println!("  supersettings close                 Close the GUI Settings window");
    println!("  supersettings probe                 Emit pipe-delimited system telemetry for Quickshell");
    println!("  supersettings apply <dom> [val]     Apply a hardware, power, a11y or default-app setting");
    println!("  supersettings list                  List all Settings pages and current hardware status");
    println!("  supersettings sections              List applyable setting domains by section");
    println!("Applyable domains (theme/palette/corners/nightlight are owned by `supertheme`):");
    for (title, domains, desc) in SECTIONS {
        println!("  {:<17} {:<40} {}", title, domains.join(", "), desc);
    }
}

fn print_sections() {
    for (title, domains, desc) in SECTIONS {
        println!("  {:<17} {:<40} {}", title, domains.join(", "), desc);
    }
    println!("\n  Usage: supersettings apply <domain> <value>");
    println!("    toggle verbs     : touchpad, webcam, mic, speaker, mode, orca, mono-audio, animations");
    println!("    dpms             : off | on | sync");
    println!("    kbd-backlight    : cycle | up | down | 0 | 1 | 2 | status");
    println!("    battery-limit    : 80 | 100 | <20-100> | status");
    println!("    ui-scale         : compact | default | large | xlarge | <12-22>");
    println!("    hardware/vaapi   : optimize");
    println!("    default*         : <role> <app> | <ext> <app> | <preset> | reset");
    println!("\n  Theme, palette, corner geometry & nightlight: run `supertheme` instead.");
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
        "sections" | "--sections" => print_sections(),
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
        domain if is_domain(domain) => process::exit(apply_setting(&args)),
        other => open_or_exit(other, false),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sections_cover_every_hardware_control() {
        let hardware = SECTIONS
            .iter()
            .find(|(t, _, _)| *t == "Hardware")
            .expect("Hardware section");
        for domain in ["touchpad", "webcam", "mic", "speaker", "kbd-backlight"] {
            assert!(hardware.1.contains(&domain), "missing {domain}");
        }
        let power = SECTIONS
            .iter()
            .find(|(t, _, _)| *t == "Power & Display")
            .expect("Power & Display section");
        for domain in ["dpms", "battery-limit"] {
            assert!(power.1.contains(&domain), "missing {domain}");
        }
    }

    #[test]
    fn sections_never_claim_theme_domains() {
        for (title, domains, _) in SECTIONS {
            for domain in *domains {
                assert!(
                    !matches!(*domain, "theme" | "palette" | "corners" | "nightlight" | "profile"),
                    "{title} must not own the supertheme domain '{domain}'"
                );
            }
        }
    }

    #[test]
    fn every_section_domain_is_engine_dispatchable() {
        for (_, domains, _) in SECTIONS {
            for domain in *domains {
                assert!(is_domain(domain), "{domain} is listed but not dispatchable");
            }
        }
    }

    #[test]
    fn is_domain_accepts_requested_hardware_domains() {
        for domain in ["touchpad", "webcam", "mic", "speaker", "kbd-backlight", "dpms", "battery-limit"] {
            assert!(is_domain(domain), "{domain} must be applyable");
        }
        assert!(!is_domain("theme"));
        assert!(!is_domain("corners"));
        assert!(!is_domain("nightlight"));
        assert!(!is_domain("nonsense"));
    }

    #[test]
    fn page_resolution_handles_aliases_and_deep_links() {
        assert_eq!(resolve_page(""), Some("home".into()));
        assert_eq!(resolve_page("DEVICES"), Some("devices".into()));
        assert_eq!(resolve_page("webcam"), Some("devices".into()));
        assert_eq!(resolve_page("0"), Some("home".into()));
        assert_eq!(resolve_page("12"), Some("ai".into()));
        assert_eq!(resolve_page("system:pwr-battery"), Some("system:pwr-battery".into()));
        assert_eq!(resolve_page("nope"), None);
    }
}