// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/battery.rs — Kernel Charge Threshold Discovery & Longevity Limits
// ==============================================================================

use crate::hardware::{refresh_status, read_sysfs, write_sysfs_sudo};
use crate::notify_send;
use std::fs;
use std::path::{Path, PathBuf};

/// Root of the kernel power supply class.
const POWER_SUPPLY: &str = "/sys/class/power_supply";
/// Margin between the start and stop thresholds, preserving Li-ion headroom.
const HEADROOM: u32 = 5;

/// Discover every battery pack that exposes a kernel charge threshold control.
///
/// Replaces the historical hardcoded `BAT0` path: dual-battery ThinkPads,
/// multi-cell chassis and USB-C PD machines all report their packs under
/// different `BAT*` names. Only packs actually advertising
/// `charge_control_end_threshold` are returned, sorted for determinism.
pub fn threshold_batteries() -> Vec<PathBuf> {
    let mut found: Vec<PathBuf> = fs::read_dir(POWER_SUPPLY)
        .ok()
        .map(|rd| {
            rd.flatten()
                .map(|e| e.path())
                .filter(|p| {
                    p.file_name()
                        .and_then(|n| n.to_str())
                        .is_some_and(|n| n.starts_with("BAT"))
                        && p.join("charge_control_end_threshold").exists()
                })
                .collect()
        })
        .unwrap_or_default();
    found.sort();
    found
}

/// Read the `(start, end)` charge thresholds of a battery pack.
///
/// Kernels before the `charge_control_*` rename exposed `charge_start_threshold`
/// and `charge_stop_threshold`; both spellings are accepted.
pub fn thresholds(bat: &Path) -> (u32, u32) {
    let read = |preferred: &str, legacy: &str| -> u32 {
        read_sysfs(&bat.join(preferred))
            .or_else(|| read_sysfs(&bat.join(legacy)))
            .and_then(|v| v.parse::<u32>().ok())
            .unwrap_or(0)
    };
    (
        read("charge_control_start_threshold", "charge_start_threshold"),
        read("charge_control_end_threshold", "charge_stop_threshold"),
    )
}

/// Resolve a battery-limit request into `(start_threshold, end_threshold)`.
///
/// The start threshold trails the stop threshold by five percent, preserving the
/// standard Li-ion longevity profile; a full charge request zeroes the start
/// threshold so the pack cycles normally. Pure: unit tested without touching a
/// real battery.
pub fn parse_limit(val: &str) -> Option<(u32, u32)> {
    let end = match val.trim().trim_end_matches('%').to_ascii_lowercase().as_str() {
        "80" | "longevity" | "limit" | "protected" => 80,
        "100" | "full" | "off" | "default" => 100,
        other => other.parse::<u32>().ok()?.clamp(20, 100),
    };
    Some((
        if end >= 100 { 0 } else { end.saturating_sub(HEADROOM) },
        end,
    ))
}

/// Apply `battery-limit <80|100|N|status>` across every capable battery pack.
pub fn apply(val: &str) -> i32 {
    let batteries = threshold_batteries();
    if batteries.is_empty() {
        eprintln!("[FAIL] No battery pack exposes charge_control_end_threshold");
        return 1;
    }
    let verb = val.trim().to_ascii_lowercase();
    if verb == "status" {
        for bat in &batteries {
            let (start, end) = thresholds(bat);
            let name = bat.file_name().unwrap_or_default().to_string_lossy();
            println!("[OK] {name} start={start}% end={end}%");
        }
        return 0;
    }
    let Some((start, end)) = parse_limit(&verb) else {
        eprintln!("[FAIL] battery-limit expects one of: 80 | 100 | <20-100> | status");
        return 2;
    };
    let mut applied = 0;
    for bat in &batteries {
        if write_sysfs_sudo(&bat.join("charge_control_start_threshold"), &start.to_string())
            && write_sysfs_sudo(&bat.join("charge_control_end_threshold"), &end.to_string())
        {
            applied += 1;
        }
    }
    if applied == 0 {
        eprintln!(
            "[FAIL] Charge thresholds are root-owned; re-run with a cached sudo credential or via pkexec"
        );
        return 1;
    }
    refresh_status();
    notify_send("Battery Charge Limit", &format!("{start}% - {end}%"));
    println!("[OK] battery-limit {start}%-{end}% on {applied} pack(s)");
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_limit_named_presets() {
        assert_eq!(parse_limit("80"), Some((75, 80)));
        assert_eq!(parse_limit("longevity"), Some((75, 80)));
        assert_eq!(parse_limit("100"), Some((0, 100)));
        assert_eq!(parse_limit("FULL"), Some((0, 100)));
    }

    #[test]
    fn parse_limit_numeric_and_bounds() {
        assert_eq!(parse_limit("65"), Some((60, 65)));
        assert_eq!(parse_limit("60%"), Some((55, 60)));
        // Below the 20% floor the stop threshold clamps up; the start trails it
        // by the five percent longevity margin.
        assert_eq!(parse_limit("5"), Some((15, 20)));
        assert_eq!(parse_limit("95"), Some((90, 95)));
        assert_eq!(parse_limit("bogus"), None);
    }

    #[test]
    fn thresholds_fall_back_to_legacy_knobs() {
        let dir = crate::hardware::scratch("battery-thresholds");
        let bat = dir.join("BAT0");
        fs::create_dir_all(&bat).unwrap();
        fs::write(bat.join("charge_start_threshold"), "70\n").unwrap();
        fs::write(bat.join("charge_stop_threshold"), "85\n").unwrap();
        assert_eq!(thresholds(&bat), (70, 85));
        fs::write(bat.join("charge_control_start_threshold"), "75\n").unwrap();
        fs::write(bat.join("charge_control_end_threshold"), "80\n").unwrap();
        assert_eq!(thresholds(&bat), (75, 80));
        let _ = fs::remove_dir_all(&dir);
    }
}