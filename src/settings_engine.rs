// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// settings_engine.rs — Native Rust Settings Probe & Action Engine for SettingsDock
// ==============================================================================

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

fn run_out(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

fn pgrep_exact(proc_name: &str) -> bool {
    Command::new("pgrep").args(["-x", proc_name]).output().map(|o| o.status.success()).unwrap_or(false)
}

fn cfg_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let dir = PathBuf::from(home).join(".config/superfedora");
    let _ = fs::create_dir_all(&dir);
    dir
}

pub fn print_probe() {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let user = env::var("USER").unwrap_or_else(|_| "user".into());
    let host = fs::read_to_string("/etc/hostname").unwrap_or_else(|_| "fedora".into()).trim().to_string();
    let shell = env::var("SHELL").unwrap_or_else(|_| "/bin/bash".into());
    let uid = run_out("id", &["-u"]);
    let groups = run_out("id", &["-Gn"]);

    let ssh_ed = Path::new(&home).join(".ssh/id_ed25519.pub");
    let ssh_rsa = Path::new(&home).join(".ssh/id_rsa.pub");
    let ssh_status = if let Ok(k) = fs::read_to_string(&ssh_ed) {
        let p: Vec<&str> = k.split_whitespace().collect();
        format!("ED25519 Ready ({})", p.get(2).copied().unwrap_or("id_ed25519.pub"))
    } else if let Ok(k) = fs::read_to_string(&ssh_rsa) {
        let p: Vec<&str> = k.split_whitespace().collect();
        format!("RSA Ready ({})", p.get(2).copied().unwrap_or("id_rsa.pub"))
    } else {
        "No SSH keypair found (Click Generate)".into()
    };

    let fprint = if Path::new("/usr/bin/fprintd-list").exists() {
        "fprintd Ready (Biometric Auth)"
    } else {
        "Standard PAM Password Auth"
    };
    println!("USR|{}@{}|UID {}|{}|{}|{}|{}", user, host, if uid.is_empty() { "1000" } else { &uid }, shell, groups, ssh_status, fprint);

    let cups_active = Path::new("/run/cups/cups.sock").exists() || run_out("systemctl", &["is-active", "cups"]) == "active";
    let def_prn = run_out("lpstat", &["-d"])
        .split(':')
        .nth(1)
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "None configured".into());
    let prn_list: Vec<String> = run_out("lpstat", &["-p"])
        .lines()
        .filter_map(|l| l.strip_prefix("printer ")?.split_whitespace().next())
        .map(|s| s.to_string())
        .collect();
    let prn_summary = if prn_list.is_empty() {
        if cups_active { "CUPS Spooler Active · 0 queues configured".into() } else { "CUPS Spooler Inactive · Click Enable Spooler or Add Printer".into() }
    } else {
        format!("{} Queue(s): {}", prn_list.len(), prn_list.join(", "))
    };
    println!("PRN|{}|{}|{}|{}", if cups_active { "1" } else { "0" }, def_prn, prn_list.len(), prn_summary);

    let ip_route = run_out("ip", &["route", "show", "default"]);
    let gw = ip_route.split_whitespace().skip_while(|&w| w != "via").nth(1).unwrap_or("None");
    let iface = ip_route.split_whitespace().skip_while(|&w| w != "dev").nth(1).unwrap_or("lo");
    let ip_addr = run_out("ip", &["-4", "-o", "addr", "show", "dev", iface]);
    let ipv4 = ip_addr.split_whitespace().skip_while(|&w| w != "inet").nth(1).unwrap_or("Disconnected");
    let dns = fs::read_to_string("/etc/resolv.conf")
        .unwrap_or_default()
        .lines()
        .filter_map(|l| l.strip_prefix("nameserver")?.split_whitespace().next())
        .collect::<Vec<&str>>()
        .join(", ");
    let fw_active = run_out("systemctl", &["is-active", "firewalld"]) == "active";
    let vpn_active = ["tailscale0", "wg0", "tun0", "proton0"]
        .iter()
        .find(|&&n| Path::new(&format!("/sys/class/net/{n}")).exists())
        .copied()
        .unwrap_or("None");
    println!(
        "NETI|{}|{}|{}|{}|{}|{}",
        iface, ipv4, gw,
        if dns.is_empty() { "127.0.0.53" } else { &dns },
        if fw_active { "ACTIVE (firewalld)" } else { "INACTIVE" },
        vpn_active
    );

    let df_out = run_out("df", &["-h", "/", "/home"]);
    let (mut root_str, mut home_str) = ("Unknown".to_string(), "Unknown".to_string());
    for (i, line) in df_out.lines().skip(1).enumerate() {
        let c: Vec<&str> = line.split_whitespace().collect();
        if c.len() >= 5 {
            let s = format!("{} / {} ({})", c[2], c[1], c[4]);
            if i == 0 { root_str = s; } else { home_str = s; }
        }
    }
    println!("DSK|{}|{}", root_str, home_str);

    let cfg = cfg_dir();
    let ui_scale = fs::read_to_string(cfg.join("ui-scale")).ok().and_then(|s| s.trim().parse::<u32>().ok()).unwrap_or(14);
    let anim_off = fs::read_to_string(cfg.join("animations")).map(|s| s.trim() == "0" || s.trim() == "off").unwrap_or(false);
    let orca_on = pgrep_exact("orca");
    let night_on = pgrep_exact("wlsunset");
    let tpad_on = fs::read_to_string(cfg.join("touchpad-enabled")).map(|s| s.trim() != "0" && s.trim() != "off").unwrap_or(true);
    let mono_on = fs::read_to_string(cfg.join("mono-audio")).map(|s| s.trim() == "1" || s.trim() == "on").unwrap_or(false);
    let ws_mode = fs::read_to_string(cfg.join("workstation-mode"))
        .unwrap_or_else(|_| "balanced".into())
        .trim()
        .to_string();
    let mut gpu_arch = String::from("Generic KMS/DRM GPU");
    let mut va_drv = "radeonsi (Mesa Freeworld)";
    if let Ok(entries) = fs::read_dir("/sys/bus/pci/devices") {
        for e in entries.flatten() {
            let p = e.path();
            if fs::read_to_string(p.join("class")).unwrap_or_default().trim().starts_with("0x03") {
                match fs::read_to_string(p.join("vendor")).unwrap_or_default().trim() {
                    "0x1002" => { gpu_arch = "AMD RDNA / Radeon".into(); va_drv = "radeonsi (Mesa Freeworld)"; }
                    "0x8086" => { gpu_arch = "Intel Arc / Xe".into(); va_drv = "iHD (Intel Media Driver)"; }
                    "0x10de" => { gpu_arch = "NVIDIA RTX / GeForce".into(); va_drv = "nvidia (NVDEC VA-API)"; }
                    _ => {}
                }
                break;
            }
        }
    }
    let ff_ok = Path::new("/usr/bin/ffmpeg").exists();
    let dmabuf_ok = cfg.join("firefox-vaapi.js").is_file();
    let pk_idle = if Path::new("/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf").exists() {
        "On-Demand (30s ShutdownTimeout)"
    } else {
        "On-Demand (Socket)"
    };
    println!(
        "GPU|{}|{}|{}|{}",
        gpu_arch,
        va_drv,
        if ff_ok { "Full FFmpeg + VA-API" } else { "ffmpeg-free" },
        if dmabuf_ok { "Zero-Copy DMABUF Active" } else { "Standard" }
    );
    println!("MODE|{}|{}", ws_mode, pk_idle);
    println!(
        "A11Y|{}|{}|{}|{}|{}|{}",
        ui_scale,
        if anim_off { "0" } else { "1" },
        if orca_on { "1" } else { "0" },
        if night_on { "1" } else { "0" },
        if tpad_on { "1" } else { "0" },
        if mono_on { "1" } else { "0" }
    );
}

pub fn apply_setting(args: &[String]) -> i32 {
    let act = args.first().map(|s| s.as_str()).unwrap_or("");
    let val = args.get(1).map(|s| s.as_str()).unwrap_or("");
    let cfg = cfg_dir();

    match act {
        "mode" | "profile" => {
            let next = if val.is_empty() { "cycle" } else { val };
            let _ = Command::new("superfedora").args(["mode", next]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "hardware" | "vaapi" => {
            let _ = Command::new("superfedora").args(["hardware", "optimize"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "theme" | "palette" => {
            let sub = if val.is_empty() { "toggle" } else { val };
            let _ = Command::new("supertheme").arg(sub).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "corners" => {
            let sub = if val.is_empty() { "toggle" } else { val };
            let _ = Command::new("supertheme").args(["corners", sub]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "ui-scale" => {
            let sz: u32 = match val {
                "compact" | "small" | "13" => 13,
                "default" | "normal" | "14" => 14,
                "large" | "16" | "17" => 16,
                "xlarge" | "xl" | "18" | "20" => 18,
                _ => val.parse::<u32>().unwrap_or(14).clamp(12, 22),
            };
            let _ = fs::write(cfg.join("ui-scale"), format!("{sz}\n"));
            let _ = Command::new("qs").args(["ipc", "call", "theme", "reload"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "animations" => {
            let cur_off = fs::read_to_string(cfg.join("animations")).map(|s| s.trim() == "0" || s.trim() == "off").unwrap_or(false);
            let enable = match val { "on" | "1" => true, "off" | "0" => false, _ => cur_off };
            let _ = fs::write(cfg.join("animations"), if enable { "1\n" } else { "0\n" });
            let _ = Command::new("hyprctl").args(["keyword", "animations:enabled", if enable { "true" } else { "false" }]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "nightlight" => {
            let running = pgrep_exact("wlsunset");
            let _ = Command::new("pkill").args(["-x", "wlsunset"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            if val == "on" || (val == "toggle" && !running) || val == "4000" || val == "3400" {
                let temp = if val == "3400" { "3400" } else { "4000" };
                let _ = Command::new("sh").args(["-c", &format!("nohup wlsunset -T {temp} -t 3000 >/dev/null 2>&1 &")]).status();
            }
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "orca" => {
            if pgrep_exact("orca") && val != "on" {
                let _ = Command::new("pkill").args(["-x", "orca"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            } else {
                let _ = Command::new("sh").args(["-c", "nohup orca >/dev/null 2>&1 &"]).status();
            }
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        "mono-audio" => {
            let cur = fs::read_to_string(cfg.join("mono-audio")).map(|s| s.trim() == "1").unwrap_or(false);
            let next = match val { "on" | "1" => true, "off" | "0" => false, _ => !cur };
            let _ = fs::write(cfg.join("mono-audio"), if next { "1\n" } else { "0\n" });
            let _ = Command::new("qs").args(["ipc", "call", "status", "refresh"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
            0
        }
        _ => {
            print_probe();
            0
        }
    }
}
