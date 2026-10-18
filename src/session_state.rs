// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// session_state.rs — Installed DE Discovery, Selection & Publication
// ==============================================================================

use crate::{ShellEnv, run_quiet};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// Directories scanned for installed session desktop entries.
const SESSION_DIRS: [&str; 2] = ["/usr/share/wayland-sessions", "/usr/share/xsessions"];
/// Session id used whenever the login manager offers no SuperFedora entry.
const DEFAULT_SESSION: &str = "superfedora";

/// Enumerate installed Wayland and X11 sessions as `(id, display name)`.
///
/// Entries flagged `NoDisplay=true` or `Hidden=true` are suppressed. When the
/// SuperFedora session exists the raw Hyprland aliases are dropped so the
/// picker never offers the same desktop twice.
pub fn discover_sessions() -> Vec<(String, String)> {
    let mut out = Vec::new();
    for dir in SESSION_DIRS {
        let Ok(entries) = fs::read_dir(dir) else { continue };
        let mut paths: Vec<_> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.extension().and_then(|x| x.to_str()) == Some("desktop"))
            .collect();
        paths.sort();
        out.extend(paths.into_iter().filter_map(read_session));
    }
    if out.iter().any(|(id, _)| id == DEFAULT_SESSION) {
        out.retain(|(id, _)| id != "hyprland" && id != "hyprland-uwsm");
    }
    if out.is_empty() {
        out.push((DEFAULT_SESSION.into(), "SuperFedora".into()));
    }
    out
}

/// Parse one session desktop entry into `(id, display name)`.
fn read_session(path: PathBuf) -> Option<(String, String)> {
    let id = path.file_stem()?.to_str()?.to_string();
    let txt = fs::read_to_string(&path).unwrap_or_default();
    let hidden = txt.lines().any(|l| {
        l.trim().eq_ignore_ascii_case("NoDisplay=true")
            || l.trim().eq_ignore_ascii_case("Hidden=true")
    });
    if hidden {
        return None;
    }
    let name = txt
        .lines()
        .find_map(|l| l.strip_prefix("Name=").map(|s| s.trim().to_string()))
        .unwrap_or_else(|| id.clone());
    Some((id, name))
}

/// Session id currently selected by the login manager, normalised to SuperFedora.
pub fn current_session_id(env: &ShellEnv) -> String {
    if let Ok(txt) = fs::read_to_string(env.state_dir.join("session.env")) {
        for line in txt.lines() {
            let Some((key, value)) = line.split_once('=') else { continue };
            if key.trim() != "SELECTED_SESSION" {
                continue;
            }
            let val = value.trim().trim_matches('"').trim_matches('\'');
            if !val.is_empty() {
                return normalise(val);
            }
        }
    }
    DEFAULT_SESSION.into()
}

/// Map raw Hyprland aliases onto the SuperFedora session when it exists.
fn normalise(val: &str) -> String {
    let is_alias = val == "hyprland" || val == "hyprland-uwsm";
    let superfedora = Path::new("/usr/share/wayland-sessions/superfedora.desktop").exists();
    if is_alias && superfedora {
        DEFAULT_SESSION.into()
    } else {
        val.to_string()
    }
}

/// Publish the selected session to the shell state file and AccountsService.
pub fn set_session_id(env: &ShellEnv, target: &str) {
    let _ = fs::write(
        env.state_dir.join("session.env"),
        format!("SELECTED_SESSION=\"{target}\"\n"),
    );
    let uid = Command::new("id")
        .arg("-u")
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "1000".into());
    let obj = format!("/org/freedesktop/Accounts/User{uid}");
    for method in ["SetSession", "SetXSession"] {
        run_quiet(
            "gdbus",
            &[
                "call",
                "--system",
                "--dest",
                "org.freedesktop.Accounts",
                "--object-path",
                &obj,
                "--method",
                &format!("org.freedesktop.Accounts.User.{method}"),
                target,
            ],
        );
    }
}

/// Fuzzy-select a session with fuzzel and publish the chosen entry.
pub fn pick_session(env: &ShellEnv, sessions: &[(String, String)]) {
    let input: String = sessions
        .iter()
        .map(|(id, name)| format!("{id}: {name}\n"))
        .collect();
    let Ok(mut child) = Command::new("fuzzel")
        .args([
            "--dmenu",
            "--prompt",
            "Select DE > ",
            "--lines",
            "6",
            "--width",
            "38",
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
    else {
        return;
    };
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(input.as_bytes());
    }
    let Ok(out) = child.wait_with_output() else { return };
    if !out.status.success() {
        return;
    }
    let choice = String::from_utf8_lossy(&out.stdout);
    if let Some((sel_id, _)) = choice.trim().split_once(':')
        && !sel_id.is_empty()
    {
        set_session_id(env, sel_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn scratch(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("supershell-{tag}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).expect("scratch dir");
        dir
    }

    #[test]
    fn session_discovery_never_returns_empty_or_duplicated() {
        let sessions = discover_sessions();
        assert!(!sessions.is_empty(), "must always expose one selectable DE");
        let mut sorted = sessions.clone();
        sorted.sort();
        sorted.dedup();
        assert_eq!(sorted.len(), sessions.len(), "no duplicate session ids");
    }

    #[test]
    fn current_session_defaults_to_superfedora() {
        let dir = scratch("session-state");
        let env = ShellEnv {
            home: dir.clone(),
            cfg_dir: dir.join("cfg"),
            state_dir: dir.join("rt"),
            theme_color: "blue".into(),
            theme_mode: "dark".into(),
            corners: "rounded".into(),
        };
        fs::create_dir_all(&env.state_dir).unwrap();
        assert_eq!(current_session_id(&env), DEFAULT_SESSION);
        fs::write(
            env.state_dir.join("session.env"),
            "SELECTED_SESSION=\"plasma\"\n",
        )
        .unwrap();
        assert_eq!(current_session_id(&env), "plasma");
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn current_session_ignores_malformed_state() {
        let dir = scratch("session-bad");
        let env = ShellEnv {
            home: dir.clone(),
            cfg_dir: dir.join("cfg"),
            state_dir: dir.join("rt"),
            theme_color: "blue".into(),
            theme_mode: "dark".into(),
            corners: "rounded".into(),
        };
        fs::create_dir_all(&env.state_dir).unwrap();
        fs::write(env.state_dir.join("session.env"), "GARBAGE\nSELECTED_SESSION=\"\"\n").unwrap();
        assert_eq!(current_session_id(&env), DEFAULT_SESSION);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn session_entry_parsing_skips_hidden() {
        let dir = scratch("session-hidden");
        let hidden = dir.join("kde.desktop");
        fs::write(&hidden, "[Desktop Entry]\nName=KDE\nNoDisplay=true\n").unwrap();
        assert!(read_session(hidden).is_none());
        let visible = dir.join("gnome.desktop");
        fs::write(&visible, "[Desktop Entry]\nName=GNOME\n").unwrap();
        assert_eq!(
            read_session(visible),
            Some(("gnome".to_string(), "GNOME".to_string()))
        );
        let _ = fs::remove_dir_all(&dir);
    }
}