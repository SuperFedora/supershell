// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/mod.rs — Sysfs Primitives & Native Hardware Toggle Sub-Modules
// ==============================================================================
// This module tree owns every *hardware* control: touchpad, webcam, mic and
// speaker, keyboard backlight, battery charge limit and DPMS. Theme, palette
// and corner geometry are NOT hardware; they belong exclusively to `supertheme`.
// Every action is idempotent: re-running it yields identical machine state
// and exit code 0.

pub mod audio;
pub mod backlight;
pub mod battery;
pub mod dpms;
pub mod touchpad;
pub mod webcam;

use crate::qs_call;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

/// Push freshly applied hardware state back into the Quickshell Status model.
pub fn refresh_status() {
    let _ = qs_call("status", &["refresh"]);
}

/// Read a sysfs attribute, trimmed. `None` when missing or empty.
pub fn read_sysfs(path: &Path) -> Option<String> {
    fs::read_to_string(path)
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

/// Write a sysfs attribute directly. `true` when the write succeeded.
pub fn write_sysfs(path: &Path, value: &str) -> bool {
    fs::write(path, value).is_ok()
}

/// Write a privileged sysfs attribute through a *non-interactive* `sudo -n`.
/// Fails fast instead of blocking on a password prompt when no credential is
/// cached. Values are restricted to an unambiguous safe character set before
/// being interpolated into the `sh -c` script.
pub fn write_sysfs_sudo(path: &Path, value: &str) -> bool {
    let path_str = path.to_string_lossy().to_string();
    let safe_path = path_str.starts_with('/');
    let safe_value = !value.is_empty()
        && value
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-' | ':' | '%'));
    if !safe_path || !safe_value {
        return false;
    }
    let script = format!("printf %s {value} > {path_str}");
    Command::new("sudo")
        .args(["-n", "sh", "-c", &script])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Read an LED class brightness, clamped to the driver's `max_brightness`.
pub fn read_brightness(dir: &Path) -> u32 {
    let max = read_sysfs(&dir.join("max_brightness"))
        .and_then(|m| m.parse::<u32>().ok())
        .unwrap_or(u32::MAX);
    read_sysfs(&dir.join("brightness"))
        .and_then(|b| b.parse::<u32>().ok())
        .unwrap_or(0)
        .min(max)
}

/// Set an LED class brightness: `brightnessctl`, then sysfs, then sudo sysfs.
pub fn set_brightness(dir: &Path, value: u32) -> bool {
    let led = dir
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    let val = value.to_string();
    let via_ctld = Command::new("brightnessctl")
        .args(["--device", &led, "set", &val])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    via_ctld
        || write_sysfs(&dir.join("brightness"), &val)
        || write_sysfs_sudo(&dir.join("brightness"), &val)
}

/// Resolve an on/off/toggle verb against the current state. `None` = invalid.
pub fn resolve_bool(val: &str, current: bool) -> Option<bool> {
    match val.trim().to_ascii_lowercase().as_str() {
        "on" | "enable" | "enabled" | "true" | "1" => Some(true),
        "off" | "disable" | "disabled" | "false" | "0" => Some(false),
        "" | "toggle" | "flip" => Some(!current),
        _ => None,
    }
}

#[cfg(test)]
pub fn scratch(tag: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("supershell-test-{tag}-{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).expect("scratch dir");
    dir
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolve_bool_maps_verbs() {
        assert_eq!(resolve_bool("on", false), Some(true));
        assert_eq!(resolve_bool("OFF", true), Some(false));
        assert_eq!(resolve_bool("1", false), Some(true));
        assert_eq!(resolve_bool("", false), Some(true));
        assert_eq!(resolve_bool("toggle", false), Some(true));
        assert_eq!(resolve_bool("toggle", true), Some(false));
        assert_eq!(resolve_bool("maybe", true), None);
    }

    #[test]
    fn write_sysfs_sudo_rejects_unsafe_input() {
        let dir = scratch("sudo-guard");
        assert!(!write_sysfs_sudo(Path::new("relative/path"), "1"));
        assert!(!write_sysfs_sudo(&dir.join("x"), "1; rm -rf /"));
        assert!(!write_sysfs_sudo(&dir.join("x"), ""));
        assert!(!write_sysfs_sudo(&dir.join("x"), "$(id)"));
    }

    #[test]
    fn sysfs_roundtrip_and_clamp() {
        let dir = scratch("sysfs");
        let led = dir.join("led");
        fs::create_dir_all(&led).unwrap();
        fs::write(led.join("brightness"), "7").unwrap();
        fs::write(led.join("max_brightness"), "3").unwrap();
        assert_eq!(read_sysfs(&led.join("brightness")).as_deref(), Some("7"));
        assert_eq!(read_brightness(&led), 3);
        assert!(set_brightness(&led, 2));
        assert_eq!(read_brightness(&led), 2);
        let _ = fs::remove_dir_all(&dir);
    }
}