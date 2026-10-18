// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/touchpad.rs — Native Hyprland Touchpad Gate (no shell script)
// ==============================================================================

use crate::hardware::{refresh_status, resolve_bool};
use crate::{notify_send, run_out, run_quiet};
use serde_json::Value;
use std::fs;
use std::path::Path;

/// `HYPRLAND_DEVICE_CAPABILITY_TOUCHPAD` bit from Hyprland's device capability enum.
const CAP_TOUCHPAD: u64 = 1 << 5;
/// `HYPRLAND_DEVICE_CAPABILITY_MOUSE` bit.
const CAP_MOUSE: u64 = 1 << 0;
/// Device name assumed when Hyprland reports nothing usable.
const FALLBACK_DEVICE: &str = "elan-touchpad";
/// Name fragments identifying a trackpad that Hyprland failed to flag.
const NAME_HINTS: [&str; 6] = ["touchpad", "trackpad", "elan", "synaptics", "cypress", "alps"];

/// Extract touchpad device names from raw `hyprctl devices -j` output.
///
/// Pure function: exercised by unit tests against a captured JSON fixture, so
/// no live compositor is required. Devices are only selected when Hyprland
/// reports the touchpad capability bit, or reports a mouse whose name carries a
/// known trackpad fragment; plain pointing mice are never disabled. Falls back
/// to `elan-touchpad` so the gate still works before Hyprland enumerates input.
pub fn parse_touchpad_devices(json: &str) -> Vec<String> {
    let Ok(Value::Array(devices)) = serde_json::from_str::<Value>(json) else {
        return vec![FALLBACK_DEVICE.to_string()];
    };
    let mut out: Vec<String> = Vec::new();
    for dev in devices {
        let Some(name) = dev.get("name").and_then(Value::as_str) else { continue };
        let caps = dev.get("capabilities").and_then(Value::as_u64).unwrap_or(0);
        let lower = name.to_ascii_lowercase();
        let is_touchpad = caps & CAP_TOUCHPAD != 0
            || (caps & CAP_MOUSE != 0 && NAME_HINTS.iter().any(|h| lower.contains(h)));
        if is_touchpad && !out.iter().any(|n| n == name) {
            out.push(name.to_string());
        }
    }
    if out.is_empty() {
        out.push(FALLBACK_DEVICE.to_string());
    }
    out
}

/// Live touchpad device names reported by the running compositor.
pub fn touchpad_devices() -> Vec<String> {
    parse_touchpad_devices(&run_out("hyprctl", &["devices", "-j"]))
}

/// Persisted touchpad intent (`~/.config/superfedora/touchpad-enabled`).
pub fn enabled(cfg_dir: &Path) -> bool {
    fs::read_to_string(cfg_dir.join("touchpad-enabled"))
        .map(|s| !matches!(s.trim(), "0" | "off" | "false"))
        .unwrap_or(true)
}

/// Apply `touchpad <on|off|toggle>` natively.
///
/// Sets `device[<name>]:enabled` through the Hyprland config socket, persists
/// the intent to `~/.config/superfedora/touchpad-enabled`, mirrors it into the
/// `$XDG_RUNTIME_DIR/touchpad-disabled` sentinel consumed by the Quickshell
/// Status probe, notifies the user and refreshes Quickshell.
pub fn apply(val: &str, cfg_dir: &Path, rt_dir: &Path) -> i32 {
    let Some(want) = resolve_bool(val, enabled(cfg_dir)) else {
        eprintln!("[FAIL] touchpad expects one of: on | off | toggle");
        return 2;
    };
    let devices = touchpad_devices();
    for name in &devices {
        let keyword = format!("device[{name}]:enabled");
        run_quiet("hyprctl", &["keyword", &keyword, if want { "true" } else { "false" }]);
    }
    let _ = fs::write(
        cfg_dir.join("touchpad-enabled"),
        if want { "1\n" } else { "0\n" },
    );
    let sentinel = rt_dir.join("touchpad-disabled");
    if want {
        let _ = fs::remove_file(&sentinel);
    } else {
        let _ = fs::write(&sentinel, "1\n");
    }
    notify_send(
        if want { "Touchpad Enabled" } else { "Touchpad Disabled" },
        &format!("{} device(s): {}", devices.len(), devices.join(", ")),
    );
    refresh_status();
    println!(
        "[{}] touchpad {} ({})",
        if want { "OK" } else { "--" },
        if want { "on" } else { "off" },
        devices.join(", ")
    );
    0
}

/// Query live Hyprland device state without mutating anything. Read-only.
pub fn query_enabled(cfg_dir: &Path, rt_dir: &Path) -> bool {
    enabled(cfg_dir) && !rt_dir.join("touchpad-disabled").exists()
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = r#"[
      {"name":"kbd","capabilities":17},
      {"name":"mouse","capabilities":1},
      {"name":"elan-touchpad","capabilities":33},
      {"name":"synPS/2_Synaptics_TouchPad","capabilities":33}
    ]"#;

    #[test]
    fn selects_touchpads_not_mice() {
        assert_eq!(
            parse_touchpad_devices(FIXTURE),
            vec!["elan-touchpad", "synPS/2_Synaptics_TouchPad"]
        );
    }

    #[test]
    fn falls_back_when_no_touchpad_present() {
        assert_eq!(parse_touchpad_devices("[]"), vec![FALLBACK_DEVICE]);
        assert_eq!(parse_touchpad_devices("[{\"name\":\"mouse\",\"capabilities\":1}]"), vec![FALLBACK_DEVICE]);
        assert_eq!(parse_touchpad_devices("not json at all"), vec![FALLBACK_DEVICE]);
    }

    #[test]
    fn detects_capability_bit_without_name_hint() {
        let json = r#"[{"name":"PS/2 Generic Mouse","capabilities":32}]"#;
        assert_eq!(parse_touchpad_devices(json), vec!["PS/2 Generic Mouse"]);
    }

    #[test]
    fn persisted_state_roundtrips() {
        let dir = crate::hardware::scratch("touchpad-state");
        let cfg = dir.join("cfg");
        fs::create_dir_all(&cfg).unwrap();
        assert!(enabled(&cfg));
        fs::write(cfg.join("touchpad-enabled"), "0\n").unwrap();
        assert!(!enabled(&cfg));
        fs::write(cfg.join("touchpad-enabled"), "1\n").unwrap();
        assert!(enabled(&cfg));
        let _ = fs::remove_dir_all(&dir);
    }
}