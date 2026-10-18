// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/dpms.rs — Screen Power Dispatch with LED Brightness Snapshotting
// ==============================================================================

use crate::hardware::{refresh_status, read_sysfs, set_brightness};
use crate::{hypr_dispatch, notify_send};
use std::fs;
use std::path::Path;

/// Root of the kernel LED class.
const LEDS: &str = "/sys/class/leds";
/// Snapshot of LED brightnesses taken before the screen is powered off.
pub const LED_STATE_FILE: &str = "sf-dpms-leds.state";

/// Snapshot every LED class brightness before the screen powers off.
///
/// Idempotent by design: an existing snapshot is never overwritten, because a
/// second `dpms off` would otherwise capture the all-zero post-off state and
/// permanently lose the user's brightness levels.
pub fn save_leds(leds_root: &Path, rt_dir: &Path) -> usize {
    let state = rt_dir.join(LED_STATE_FILE);
    if state.exists() {
        return 0;
    }
    let mut snapshot: Vec<(String, String)> = fs::read_dir(leds_root)
        .map(|rd| {
            rd.flatten()
                .filter_map(|e| {
                    let path = e.path();
                    let name = path.file_name()?.to_str()?.to_string();
                    let value = read_sysfs(&path.join("brightness"))?;
                    Some((name, value))
                })
                .collect()
        })
        .unwrap_or_default();
    snapshot.sort();
    if snapshot.is_empty() {
        return 0;
    }
    let body = snapshot
        .iter()
        .map(|(n, v)| format!("{n} {v}"))
        .collect::<Vec<_>>()
        .join("\n");
    if fs::write(&state, format!("{body}\n")).is_ok() {
        snapshot.len()
    } else {
        0
    }
}

/// Restore a previously saved LED snapshot and clear it. Returns LED count.
pub fn restore_leds(leds_root: &Path, rt_dir: &Path) -> usize {
    let state = rt_dir.join(LED_STATE_FILE);
    let Ok(body) = fs::read_to_string(&state) else {
        return 0;
    };
    let mut restored = 0;
    for line in body.lines() {
        let Some((name, value)) = line.split_once(' ') else {
            continue;
        };
        if name.is_empty() || value.is_empty() || !value.chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        if set_brightness(&leds_root.join(name), value.parse().unwrap_or(0)) {
            restored += 1;
        }
    }
    let _ = fs::remove_file(&state);
    restored
}

/// Read-only DPMS state query used by probes and tests. Never dispatches.
pub fn snapshot_count(rt_dir: &Path) -> usize {
    fs::read_to_string(rt_dir.join(LED_STATE_FILE))
        .map(|b| b.lines().filter(|l| !l.trim().is_empty()).count())
        .unwrap_or(0)
}

/// Apply `dpms <off|on|sync>`.
///
/// `off` snapshots the LED brightnesses then powers the screen down, `on`
/// powers it back up, and `sync` powers up *and* restores the snapshot taken by
/// `off`, so keyboard and status LEDs come back exactly as the user left them.
pub fn apply(val: &str, rt_dir: &Path) -> i32 {
    let leds = Path::new(LEDS);
    let verb = val.trim().to_ascii_lowercase();
    let action = if verb.is_empty() { "off" } else { verb.as_str() };
    if !matches!(action, "off" | "on" | "sync") {
        eprintln!("[FAIL] dpms expects one of: off | on | sync (got '{action}')");
        return 2;
    }
    if action == "off" {
        let saved = save_leds(leds, rt_dir);
        if hypr_dispatch(&["dpms", "off"]) {
            notify_send(
                "Display Power",
                &format!("Screen off · {saved} LED level(s) saved"),
            );
            refresh_status();
            println!("[--] dpms off ({saved} LED level(s) saved)");
            return 0;
        }
    } else if hypr_dispatch(&["dpms", "on"]) {
        let restored = if action == "sync" {
            restore_leds(leds, rt_dir)
        } else {
            0
        };
        notify_send(
            "Display Power",
            &format!("Screen on · {restored} LED level(s) restored"),
        );
        refresh_status();
        println!("[OK] dpms {action} ({restored} LED level(s) restored)");
        return 0;
    }
    eprintln!("[FAIL] hyprctl dispatch dpms {action} failed (no compositor?)");
    1
}

#[cfg(test)]
mod tests {
    use super::*;

    /// LED classes are named `test::*` on purpose: `set_brightness` prefers
    /// `brightnessctl`, so a real name like `tpacpi::kbd_backlight` would drive
    /// the actual keyboard backlight during a unit test.
    fn fake_leds(dir: &Path, name: &str, value: u32, max: u32) {
        let led = dir.join(name);
        fs::create_dir_all(&led).unwrap();
        fs::write(led.join("brightness"), value.to_string()).unwrap();
        fs::write(led.join("max_brightness"), max.to_string()).unwrap();
    }

    #[test]
    fn snapshot_roundtrip_is_idempotent() {
        let dir = crate::hardware::scratch("dpms");
        let leds = dir.join("leds");
        let rt = dir.join("rt");
        fs::create_dir_all(&rt).unwrap();
        fake_leds(&leds, "test::kbd_backlight", 2, 3);
        fake_leds(&leds, "test::micmute", 0, 1);

        assert_eq!(save_leds(&leds, &rt), 2);
        assert_eq!(snapshot_count(&rt), 2);
        // Screen is now off: every LED reads zero.
        fs::write(leds.join("test::kbd_backlight/brightness"), "0").unwrap();
        fs::write(leds.join("test::micmute/brightness"), "0").unwrap();
        // A second `dpms off` must not overwrite the good snapshot.
        assert_eq!(save_leds(&leds, &rt), 0);
        assert_eq!(restore_leds(&leds, &rt), 2);
        assert_eq!(
            fs::read_to_string(leds.join("test::kbd_backlight/brightness")).unwrap(),
            "2"
        );
        assert_eq!(
            fs::read_to_string(leds.join("test::micmute/brightness")).unwrap(),
            "0"
        );
        // State file cleared, so the next cycle starts clean.
        assert_eq!(snapshot_count(&rt), 0);
        assert_eq!(restore_leds(&leds, &rt), 0);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn save_leds_ignores_leds_without_brightness() {
        let dir = crate::hardware::scratch("dpms-empty");
        let leds = dir.join("leds");
        let rt = dir.join("rt");
        fs::create_dir_all(&rt).unwrap();
        fs::create_dir_all(leds.join("some::led")).unwrap();
        assert_eq!(save_leds(&leds, &rt), 0);
        assert!(!rt.join(LED_STATE_FILE).exists());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn restore_ignores_corrupt_state_lines() {
        let dir = crate::hardware::scratch("dpms-corrupt");
        let leds = dir.join("leds");
        let rt = dir.join("rt");
        fs::create_dir_all(&rt).unwrap();
        fake_leds(&leds, "test::good", 1, 3);
        fs::write(
            rt.join(LED_STATE_FILE),
            "test::good 3\nmalformed\nbad::led rm -rf /\n",
        )
        .unwrap();
        assert_eq!(restore_leds(&leds, &rt), 1);
        assert!(!rt.join(LED_STATE_FILE).exists());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn rejects_unknown_verbs_without_dispatching() {
        assert_eq!(apply("sideways", Path::new("/nonexistent")), 2);
    }
}