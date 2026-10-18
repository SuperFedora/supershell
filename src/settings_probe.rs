// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// settings_probe.rs — System Telemetry Emitter for Quickshell
// ==============================================================================
// Emits the pipe-delimited records consumed by `qml/Status.qml`. This module is
// strictly read-only: it never mutates machine state, so it is safe to call
// from status bars, OSDs and tests.

use crate::settings_devices::{emit_defaults, emit_graphics, emit_session};
use crate::{cfg_dir, home_dir, run_out};
use std::env;
use std::fs;
use std::path::Path;

/// Emit the full SuperSettings telemetry block on stdout.
pub fn print_probe() {
    let cfg = cfg_dir();
    emit_user();
    emit_printers();
    emit_network();
    emit_storage();
    emit_session(&cfg);
    emit_graphics(&cfg);
    emit_defaults(&cfg);
}

/// Identity record: user, host, uid, shell, groups, SSH keypair and biometrics.
fn emit_user() {
    let user = env::var("USER").unwrap_or_else(|_| "user".into());
    let host = fs::read_to_string("/etc/hostname")
        .unwrap_or_else(|_| "fedora".into())
        .trim()
        .to_string();
    let shell = env::var("SHELL").unwrap_or_else(|_| "/bin/bash".into());
    let uid = run_out("id", &["-u"]);
    let groups = run_out("id", &["-Gn"]);

    let home = home_dir();
    let ed = home.join(".ssh/id_ed25519.pub");
    let rsa = home.join(".ssh/id_rsa.pub");
    let fingerprint = |key: &Path| -> String {
        let Ok(contents) = fs::read_to_string(key) else {
            return String::new();
        };
        contents
            .split_whitespace()
            .nth(2)
            .unwrap_or_default()
            .to_string()
    };
    let ssh_status = match fingerprint(&ed) {
        f if !f.is_empty() => format!("ED25519 Ready ({f})"),
        _ => match fingerprint(&rsa) {
            f if !f.is_empty() => format!("RSA Ready ({f})"),
            _ => "No SSH keypair found (Click Generate)".into(),
        },
    };

    let fprint = if Path::new("/usr/bin/fprintd-list").exists() {
        "fprintd Ready (Biometric Auth)"
    } else {
        "Standard PAM Password Auth"
    };
    println!(
        "USR|{user}@{host}|UID {}|{shell}|{groups}|{ssh_status}|{fprint}",
        if uid.is_empty() { "1000" } else { &uid }
    );
}

/// CUPS spooler state, default queue and the configured printer list.
fn emit_printers() {
    let cups_active = Path::new("/run/cups/cups.sock").exists()
        || run_out("systemctl", &["is-active", "cups"]) == "active";
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
    let summary = match (prn_list.is_empty(), cups_active) {
        (true, true) => "CUPS Spooler Active · 0 queues configured".into(),
        (true, false) => {
            "CUPS Spooler Inactive · Click Enable Spooler or Add Printer".into()
        }
        (false, _) => format!("{} Queue(s): {}", prn_list.len(), prn_list.join(", ")),
    };
    println!(
        "PRN|{}|{def_prn}|{}|{summary}",
        if cups_active { "1" } else { "0" },
        prn_list.len()
    );
}

/// Default route, IPv4 address, DNS servers, firewalld and VPN interfaces.
fn emit_network() {
    let ip_route = run_out("ip", &["route", "show", "default"]);
    let gw = ip_route
        .split_whitespace()
        .skip_while(|&w| w != "via")
        .nth(1)
        .unwrap_or("None");
    let iface = ip_route
        .split_whitespace()
        .skip_while(|&w| w != "dev")
        .nth(1)
        .unwrap_or("lo");
    let ip_addr = if iface == "lo" {
        String::new()
    } else {
        run_out("ip", &["-4", "-o", "addr", "show", "dev", iface])
    };
    let ipv4 = ip_addr
        .split_whitespace()
        .skip_while(|&w| w != "inet")
        .nth(1)
        .unwrap_or("Disconnected");
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
        "NETI|{iface}|{ipv4}|{gw}|{}|{}|{vpn_active}",
        if dns.is_empty() { "127.0.0.53" } else { &dns },
        if fw_active { "ACTIVE (firewalld)" } else { "INACTIVE" }
    );
}

/// Capacity and utilisation of the root and home filesystems.
fn emit_storage() {
    let df_out = run_out("df", &["-h", "/", "/home"]);
    let (mut root_str, mut home_str) = ("Unknown".to_string(), "Unknown".to_string());
    for (i, line) in df_out.lines().skip(1).enumerate() {
        let c: Vec<&str> = line.split_whitespace().collect();
        if c.len() >= 5 {
            let s = format!("{} / {} ({})", c[2], c[1], c[4]);
            if i == 0 {
                root_str = s;
            } else {
                home_str = s;
            }
        }
    }
    if home_str == "Unknown" {
        home_str = root_str.clone();
    }
    println!("DSK|{root_str}|{home_str}");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn probe_emits_every_record_without_panicking() {
        // Exercises the real machine read-only: no mutation, no dispatch.
        print_probe();
    }
}