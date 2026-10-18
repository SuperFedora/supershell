// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/backlight.rs — Keyboard Backlight Driver Discovery & Level Control
// ==============================================================================

use crate::hardware::{read_brightness, refresh_status, set_brightness};
use crate::notify_send;
use std::fs;
use std::path::{Path, PathBuf};

/// Canonical ThinkPad LED class used when discovery finds nothing.
const FALLBACK_LED: &str = "tpacpi::kbd_backlight";
/// Number of discrete keyboard backlight levels exposed by SuperFedora.
const LEVELS: u32 = 3;

/// Discover the keyboard backlight LED class in `/sys/class/leds`.
///
/// Prefers any `*kbd_backlight*` directory (covering `dell::kbd_backlight`,
/// `asus-wmi:leds:kbd_backlight`, `tpacpi::kbd_backlight`, `apple::kbd_backlight`
/// and friends) and falls back to the canonical ThinkPad class. Sorted for a
/// deterministic pick when a driver exposes more than one match.
pub fn kbd_backlight_dir() -> Option<PathBuf> {
    let mut found: Vec<PathBuf> = fs::read_dir("/sys/class/leds")
        .ok()?
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.contains("kbd_backlight"))
        })
        .collect();
    found.sort();
    let fallback = Path::new("/sys/class/leds").join(FALLBACK_LED);
    found
        .into_iter()
        .next()
        .or_else(|| fallback.is_dir().then_some(fallback))
}

/// Clamp any requested level into the supported `0..=2` range.
pub fn clamp_level(value: i32) -> u32 {
    value.clamp(0, LEVELS as i32 - 1) as u32
}

/// Advance one step in the `0 -> 1 -> 2 -> 0` cycle.
pub fn cycle(current: u32) -> u32 {
    (clamp_level(current as i32) + 1) % LEVELS
}

/// Step one level up or down, saturating at the ends.
pub fn step(current: u32, up: bool) -> u32 {
    let delta = if up { 1 } else { -1 };
    clamp_level(current as i32 + delta)
}

/// Persisted keyboard backlight level (`~/.config/superfedora/kbd-backlight`).
pub fn stored_level(cfg_dir: &Path) -> u32 {
    fs::read_to_string(cfg_dir.join("kbd-backlight"))
        .ok()
        .and_then(|s| s.trim().parse::<u32>().ok())
        .map(|n| clamp_level(n as i32))
        .unwrap_or(0)
}

/// Current level, preferring the live driver and falling back to persisted state.
pub fn current_level(cfg_dir: &Path) -> u32 {
    kbd_backlight_dir()
        .map(|d| clamp_level(read_brightness(&d) as i32))
        .unwrap_or_else(|| stored_level(cfg_dir))
}

/// Apply `kbd-backlight|kbd <cycle|up|down|0|1|2|status>`.
pub fn apply(val: &str, cfg_dir: &Path) -> i32 {
    let dir = kbd_backlight_dir();
    let current = current_level(cfg_dir);
    let verb = val.trim().to_ascii_lowercase();
    let next = match verb.as_str() {
        "status" => {
            println!(
                "[OK] kbd-backlight {} (driver: {})",
                current,
                dir.as_ref().and_then(|d| d.file_name())
                    .and_then(|n| n.to_str())
                    .unwrap_or("none")
            );
            return 0;
        }
        "" | "cycle" | "toggle" => cycle(current),
        "up" | "increase" | "brighter" => step(current, true),
        "down" | "decrease" | "dimmer" => step(current, false),
        "0" | "1" | "2" => match verb.parse::<u32>() {
            Ok(n) => clamp_level(n as i32),
            Err(_) => cycle(current),
        },
        other => {
            eprintln!("[FAIL] kbd-backlight expects one of: cycle | up | down | 0 | 1 | 2 | status (got '{other}')");
            return 2;
        }
    };
    if let Some(ref d) = dir {
        set_brightness(d, next);
    }
    let _ = fs::write(cfg_dir.join("kbd-backlight"), format!("{next}\n"));
    notify_send(
        "Keyboard Backlight",
        &format!("Level {next} of {}", LEVELS - 1),
    );
    refresh_status();
    println!("[OK] kbd-backlight {next}");
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cycle_wraps_through_all_levels() {
        assert_eq!(cycle(0), 1);
        assert_eq!(cycle(1), 2);
        assert_eq!(cycle(2), 0);
    }

    #[test]
    fn step_saturates_at_the_ends() {
        assert_eq!(step(0, true), 1);
        assert_eq!(step(1, true), 2);
        assert_eq!(step(2, true), 2);
        assert_eq!(step(0, false), 0);
        assert_eq!(step(1, false), 0);
        assert_eq!(step(2, false), 1);
    }

    #[test]
    fn clamp_level_bounds_every_input() {
        assert_eq!(clamp_level(-5), 0);
        assert_eq!(clamp_level(0), 0);
        assert_eq!(clamp_level(2), 2);
        assert_eq!(clamp_level(99), 2);
    }

    #[test]
    fn stored_level_roundtrips_and_clamps() {
        let dir = crate::hardware::scratch("kbd-bl");
        let cfg = dir.join("cfg");
        fs::create_dir_all(&cfg).unwrap();
        assert_eq!(stored_level(&cfg), 0);
        fs::write(cfg.join("kbd-backlight"), "2\n").unwrap();
        assert_eq!(stored_level(&cfg), 2);
        fs::write(cfg.join("kbd-backlight"), "7\n").unwrap();
        assert_eq!(stored_level(&cfg), 2);
        fs::write(cfg.join("kbd-backlight"), "garbage\n").unwrap();
        assert_eq!(stored_level(&cfg), 0);
        let _ = fs::remove_dir_all(&dir);
    }
}