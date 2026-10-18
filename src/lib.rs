// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// lib.rs — SuperShell Shared Runtime: ShellEnv, Process & Config Primitives
// ==============================================================================

pub mod hardware;
pub mod lock_tui;
pub mod session_state;
pub mod settings_devices;
pub mod settings_engine;
pub mod settings_probe;

use ratatui::style::Color;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};

#[derive(Clone, Debug)]
pub struct ShellEnv {
    pub home: PathBuf,
    pub cfg_dir: PathBuf,
    pub state_dir: PathBuf,
    pub theme_color: String,
    pub theme_mode: String,
    pub corners: String,
}

impl ShellEnv {
    pub fn load() -> Self {
        let cfg_dir = cfg_dir();
        let read_trimmed = |name: &str, def: &str| -> String {
            fs::read_to_string(cfg_dir.join(name))
                .map(|s| s.trim().to_string())
                .ok()
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| def.to_string())
        };
        Self {
            home: home_dir(),
            cfg_dir: cfg_dir.clone(),
            state_dir: runtime_dir(),
            theme_color: read_trimmed("theme-color", "blue"),
            theme_mode: read_trimmed("theme-mode", "dark"),
            corners: read_trimmed("theme-corners", "rounded"),
        }
    }

    pub fn pri(&self) -> Color {
        match self.theme_color.as_str() {
            "red" => Color::Rgb(243, 139, 168),
            "orange" | "peach" => Color::Rgb(250, 179, 135),
            "yellow" | "gold" => Color::Rgb(249, 226, 175),
            "green" | "emerald" => Color::Rgb(166, 227, 161),
            "teal" | "cyan" => Color::Rgb(148, 226, 213),
            "purple" | "mauve" => Color::Rgb(203, 166, 247),
            "pink" => Color::Rgb(245, 194, 231),
            "mono" | "slate" => Color::Rgb(186, 194, 222),
            _ => Color::Rgb(137, 180, 250),
        }
    }

    pub fn sec(&self) -> Color {
        Color::Rgb(148, 226, 213)
    }
}

// --- Process primitives -----------------------------------------------------
// Every helper is deliberately non-fatal: a workstation shell must degrade
// gracefully when an optional tool is not installed.

/// Run a command and capture its trimmed stdout. Empty string on any failure.
pub fn run_out(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

/// Run a command to completion, discarding all output.
pub fn run_quiet(program: &str, args: &[&str]) {
    let _ = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

/// Spawn a detached background process, discarding all output.
pub fn spawn_quiet(program: &str, args: &[&str]) {
    let _ = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

/// True when an exact process name is currently running.
pub fn pgrep_exact(proc_name: &str) -> bool {
    Command::new("pgrep")
        .args(["-x", proc_name])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Send a desktop notification through the standard notification daemon.
pub fn notify_send(summary: &str, body: &str) {
    let _ = Command::new("notify-send")
        .args(["-a", "SuperFedora", "-t", "1500", summary, body])
        .status();
}

// --- Path primitives --------------------------------------------------------

/// User home directory, derived from `HOME` then `USER` then `/tmp`.
pub fn home_dir() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| env::var("USER").map(|u| PathBuf::from(format!("/home/{u}"))))
        .unwrap_or_else(|_| PathBuf::from("/tmp"))
}

/// Managed user configuration root, created on demand.
pub fn cfg_dir() -> PathBuf {
    let dir = home_dir().join(".config/superfedora");
    let _ = fs::create_dir_all(&dir);
    dir
}

/// Volatile per-session state root, created on demand.
pub fn runtime_dir() -> PathBuf {
    let dir = PathBuf::from(env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into()));
    let _ = fs::create_dir_all(&dir);
    dir
}

// --- Compositor primitives --------------------------------------------------

/// Invoke the Quickshell IPC. `true` when the daemon accepted the call.
pub fn qs_call(target: &str, args: &[&str]) -> bool {
    let mut cmd = Command::new("qs");
    cmd.args(["ipc", "call", target]);
    for a in args {
        cmd.arg(a);
    }
    cmd.status().map(|s| s.success()).unwrap_or(false)
}

/// Invoke a Hyprland dispatcher. `true` when the compositor accepted it.
pub fn hypr_dispatch(args: &[&str]) -> bool {
    let mut cmd = Command::new("hyprctl");
    cmd.arg("dispatch");
    for a in args {
        cmd.arg(a);
    }
    cmd.status().map(|s| s.success()).unwrap_or(false)
}

/// Play a packaged 16-bit UI sound effect.
pub fn play_sfx(name: &str) {
    let _ = Command::new("paplay")
        .args(["/usr/share/sounds/superfedora/click.wav"])
        .status();
    let _ = Command::new("paplay")
        .args([format!("/usr/share/sounds/superfedora/{name}.wav")])
        .status();
}