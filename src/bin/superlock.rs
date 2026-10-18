// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// superlock.rs — 16-Bit Lock Screen, Idle Policy & Desktop Session Manager
// ==============================================================================
// Idle policy is applied natively: there is no `toggle-idle.sh` shim. The mode
// lives in `~/.config/superfedora/idle-mode`, the derived stay-awake sentinel in
// `~/.config/superfedora/stay-awake`, and both the renderer and the DE session
// state live in the library so this file stays inside the 16-256 line Page Rule.

use std::env;
use std::fs;
use std::process;
use std::process::Command;
use supershell::lock_tui::LockUi;
use supershell::session_state::{current_session_id, discover_sessions, pick_session, set_session_id};
use supershell::{
    ShellEnv, notify_send, pgrep_exact, qs_call, run_quiet, settings_engine::apply_setting,
};

/// Idle policy values persisted in `~/.config/superfedora/idle-mode`.
const IDLE_MODES: [&str; 3] = ["poweroff", "lock", "screensaver"];

/// Resolve an idle-policy verb against the current mode. Pure: no I/O.
fn resolve_idle_mode(current: &str, sub: &str) -> String {
    let verb = sub.trim().to_ascii_lowercase();
    match verb.as_str() {
        "poweroff" | "normal" | "idle" | "off" => "poweroff".into(),
        "lock" | "lock-only" => "lock".into(),
        "screensaver" | "stay-awake" | "awake" | "on" => "screensaver".into(),
        "toggle" | "cycle" | "" => {
            let idx = IDLE_MODES.iter().position(|m| *m == current).unwrap_or(0);
            IDLE_MODES[(idx + 1) % IDLE_MODES.len()].into()
        }
        other => other.into(),
    }
}

/// Apply an idle policy natively and return the resulting mode.
///
/// `poweroff` runs the full idle chain (screensaver, lock, screen off), `lock`
/// locks without powering the display down, and `screensaver` never locks or
/// powers off. Keeps the stay-awake sentinel in sync, guarantees `hypridle` is
/// running, notifies the user and refreshes Quickshell.
fn set_idle_mode(env: &ShellEnv, sub: &str) -> String {
    let mode_file = env.cfg_dir.join("idle-mode");
    let stay_awake_file = env.cfg_dir.join("stay-awake");

    let current = fs::read_to_string(&mode_file)
        .map(|s| s.trim().to_string())
        .ok()
        .filter(|s| IDLE_MODES.contains(&s.as_str()))
        .unwrap_or_else(|| {
            if stay_awake_file.exists() {
                "screensaver".into()
            } else {
                "poweroff".into()
            }
        });

    let next = resolve_idle_mode(&current, sub);

    let _ = fs::write(&mode_file, format!("{next}\n"));
    if next == "screensaver" {
        let _ = fs::write(&stay_awake_file, "1\n");
    } else {
        let _ = fs::remove_file(&stay_awake_file);
    }

    if !pgrep_exact("hypridle") {
        run_quiet("hyprctl", &["dispatch", "exec", "hypridle"]);
    }

    match next.as_str() {
        "poweroff" => notify_send(
            "Idle Mode: Screen Power Off",
            "Screensaver (2m) -> Lock (5m) -> Screen Off (10m)",
        ),
        "lock" => notify_send(
            "Idle Mode: Lock Screen Only",
            "Screensaver (2m) -> Lock (5m) · Screen never powers off",
        ),
        "screensaver" => notify_send(
            "Idle Mode: Only Screensaver",
            "Screensaver (2m) · Never locks or powers off",
        ),
        _ => {}
    }

    let _ = qs_call("status", &["refresh"]);
    next.to_string()
}

/// Current idle policy, defaulting to the full power-off chain.
fn idle_mode(env: &ShellEnv) -> String {
    fs::read_to_string(env.cfg_dir.join("idle-mode"))
        .map(|s| s.trim().to_string())
        .ok()
        .filter(|s| IDLE_MODES.contains(&s.as_str()))
        .unwrap_or_else(|| "poweroff".into())
}

/// Lock the workstation through Quickshell, hyprlock, then logind.
fn activate_lock() {
    if !qs_call("lock", &["activate"]) && Command::new("hyprlock").status().is_err() {
        run_quiet("loginctl", &["lock-session"]);
    }
}

fn main() {
    let env = ShellEnv::load();
    let args: Vec<String> = env::args().skip(1).collect();
    let cmd = args.first().map(|s| s.as_str()).unwrap_or("status");
    let sessions = discover_sessions();
    let cur_id = current_session_id(&env);
    let cur_idx = sessions.iter().position(|(id, _)| *id == cur_id).unwrap_or(0);

    match cmd {
        "tui" => process::exit(
            LockUi {
                env: &env,
                sessions,
                current: cur_id,
                set_session: &|id| set_session_id(&env, id),
                idle_mode: &|| idle_mode(&env),
                cycle_idle: &|sub| set_idle_mode(&env, sub),
                lock_now: &|| activate_lock(),
            }
            .run(),
        ),
        "version" | "--version" | "-V" => {
            println!("superlock {} (SuperFedora/supershell)", env!("CARGO_PKG_VERSION"))
        }
        "lock" | "activate" => activate_lock(),
        "status" => println!("<b>\u{f0493} DE: {}</b>", sessions[cur_idx].1),
        "idle" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("status");
            if sub == "status" {
                println!("{}", idle_mode(&env));
            } else {
                println!("[OK] idle-mode: {}", set_idle_mode(&env, sub));
            }
        }
        "dpms" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("off");
            process::exit(apply_setting(&["dpms".into(), sub.into()]));
        }
        "list" => {
            for (i, (id, name)) in sessions.iter().enumerate() {
                let mark = if i == cur_idx { "[*]" } else { "   " };
                println!("{mark} {id:<20} ({name})");
            }
        }
        "next" => {
            let next_idx = (cur_idx + 1) % sessions.len();
            set_session_id(&env, &sessions[next_idx].0);
            println!("<b>\u{f0493} DE: {}</b>", sessions[next_idx].1);
        }
        "set" => {
            let target = args.get(1).map(|s| s.as_str()).unwrap_or("hyprland");
            set_session_id(&env, target);
        }
        "switch" => switch_session(),
        "pick" => pick_session(&env, &sessions),
        "-h" | "--help" | "help" => println!(
            "Usage: superlock [lock|status|list|next|set <id>|switch|pick|idle [poweroff|lock|screensaver]|tui|dpms [off|on|sync]]"
        ),
        other => {
            eprintln!("[FAIL] unknown superlock command: {other}");
            process::exit(2);
        }
    }
}

/// Hand the greeter a transient display and tear the current session down.
fn switch_session() {
    run_quiet(
        "gdbus",
        &[
            "call",
            "--system",
            "--dest",
            "org.gnome.DisplayManager",
            "--object-path",
            "/org/gnome/DisplayManager/LocalDisplayFactory",
            "--method",
            "org.gnome.DisplayManager.LocalDisplayFactory.CreateTransientDisplay",
        ],
    );
    run_quiet("systemctl", &["--user", "stop", "hyprland-session.target"]);
    run_quiet("systemctl", &["--user", "reset-failed"]);
    run_quiet("hyprctl", &["dispatch", "exit"]);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn idle_modes_are_the_documented_three() {
        assert_eq!(IDLE_MODES, ["poweroff", "lock", "screensaver"]);
    }

    #[test]
    fn explicit_idle_verbs_resolve_and_are_idempotent() {
        for verb in ["poweroff", "lock", "screensaver"] {
            assert_eq!(resolve_idle_mode("lock", verb), verb);
            assert_eq!(resolve_idle_mode(verb, verb), verb);
        }
        assert_eq!(resolve_idle_mode("lock", "LOCK-ONLY"), "lock");
        assert_eq!(resolve_idle_mode("lock", "screensaver"), "screensaver");
    }

    #[test]
    fn toggle_cycles_through_all_three_modes() {
        let mut mode = String::from("poweroff");
        for expected in ["lock", "screensaver", "poweroff"] {
            mode = resolve_idle_mode(&mode, "toggle");
            assert_eq!(mode, expected);
        }
        // A bare invocation and "cycle" behave identically to "toggle".
        assert_eq!(resolve_idle_mode("poweroff", ""), "lock");
        assert_eq!(resolve_idle_mode("poweroff", "cycle"), "lock");
    }

    #[test]
    fn toggle_recovers_from_an_unknown_persisted_mode() {
        assert_eq!(resolve_idle_mode("nonsense", "toggle"), "lock");
    }
}