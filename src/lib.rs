// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

pub mod settings_engine;

use ratatui::style::Color;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};

pub const PALETTES: &[(&str, (u8, u8, u8), (u8, u8, u8))] = &[
    ("01-crimson", (247, 118, 142), (255, 158, 100)),
    ("02-scarlet", (255, 95, 110), (247, 118, 142)),
    ("03-ember", (255, 122, 89), (224, 175, 104)),
    ("04-amber", (255, 158, 100), (224, 175, 104)),
    ("05-topaz", (224, 175, 104), (158, 206, 106)),
    ("06-citrine", (240, 208, 104), (115, 218, 202)),
    ("07-peridot", (180, 224, 108), (115, 218, 202)),
    ("08-emerald", (158, 206, 106), (115, 218, 202)),
    ("09-verdant", (115, 218, 202), (125, 207, 255)),
    ("10-lagoon", (42, 195, 222), (122, 162, 247)),
    ("11-glacier", (125, 207, 255), (187, 154, 247)),
    ("12-cobalt", (122, 162, 247), (187, 154, 247)),
    ("13-indigo", (130, 140, 255), (125, 207, 255)),
    ("14-violet", (187, 154, 247), (122, 162, 247)),
    ("15-orchid", (211, 134, 247), (247, 118, 142)),
    ("16-fuchsia", (255, 117, 195), (125, 207, 255)),
];

#[derive(Clone, Serialize, Deserialize)]
pub struct DockConfig {
    pub position: String,
    pub autohide: bool,
    #[serde(rename = "showAlways")]
    pub show_always: bool,
    pub pinned: Vec<String>,
}

impl Default for DockConfig {
    fn default() -> Self {
        Self {
            position: "bottom".into(),
            autohide: false,
            show_always: true,
            pinned: ["kitty", "org.mozilla.firefox", "com.google.Chrome", "org.gnome.Nautilus", "nvim", "btop"]
                .iter()
                .map(|s| s.to_string())
                .collect(),
        }
    }
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct WorkspaceModes {
    #[serde(default = "default_mode")]
    pub default: String,
    #[serde(default)]
    pub workspaces: BTreeMap<String, String>,
}
fn default_mode() -> String { "dwindle".into() }

#[derive(Clone)]
pub struct ShellEnv {
    pub home: PathBuf,
    pub state_dir: PathBuf,
    pub theme_color: String,
    pub pri_rgb: (u8, u8, u8),
    pub sec_rgb: (u8, u8, u8),
}

impl ShellEnv {
    pub fn load() -> Self {
        let home = PathBuf::from(env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into()));
        let state_dir = env::var("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| home.join(".config"))
            .join("superfedora");
        let _ = fs::create_dir_all(&state_dir);
        let mut theme_color = String::from("12-cobalt");
        if let Ok(txt) = fs::read_to_string(state_dir.join("theme.env")) {
            for line in txt.lines() {
                if let Some((k, v)) = line.split_once('=')
                    && k.trim() == "THEME_COLOR"
                {
                    theme_color = v.trim().trim_matches('"').trim_matches('\'').to_string();
                }
            }
        }
        let (pri_rgb, sec_rgb) = PALETTES
            .iter()
            .find(|(id, _, _)| *id == theme_color)
            .map(|(_, p, s)| (*p, *s))
            .unwrap_or(((122, 162, 247), (187, 154, 247)));
        Self { home, state_dir, theme_color, pri_rgb, sec_rgb }
    }

    pub fn pri(&self) -> Color {
        Color::Rgb(self.pri_rgb.0, self.pri_rgb.1, self.pri_rgb.2)
    }

    pub fn sec(&self) -> Color {
        Color::Rgb(self.sec_rgb.0, self.sec_rgb.1, self.sec_rgb.2)
    }
}

pub fn qs_running() -> bool {
    Command::new("pgrep")
        .args(["-x", "quickshell"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
        || Command::new("pgrep")
            .args(["-x", "qs"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
}

pub fn qs_call(target: &str, args: &[&str]) -> bool {
    if !qs_running() {
        return false;
    }
    for bin in ["qs", "quickshell"] {
        let mut c = Command::new(bin);
        c.args(["ipc", "--any-display", "call", target]).args(args).stdout(Stdio::null()).stderr(Stdio::null());
        if let Ok(st) = c.status() && st.success() {
            return true;
        }
    }
    false
}

pub fn notify_dock() {
    let _ = qs_call("dock", &["reload"]);
    let _ = qs_call("workspaces", &["reload"]);
}

pub fn play_sfx(chime: &str) {
    let _ = Command::new("supertheme")
        .args(["sfx", "play", chime])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

pub fn run_quiet(cmd: &str, args: &[&str]) {
    let _ = Command::new(cmd).args(args).stdout(Stdio::null()).stderr(Stdio::null()).status();
}
