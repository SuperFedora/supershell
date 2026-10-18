// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// settings_engine.rs — Settings Domain Dispatcher for SuperSettings
// ==============================================================================
// This dispatcher owns system, session and *hardware* settings only.
// Theme, palette and corner geometry are owned exclusively by `supertheme` and
// are deliberately absent here: routing them through this engine would create
// two sources of truth for the same files.
//
// Every domain honours the idempotency invariant: re-running an action yields
// identical machine state, no duplicated artefacts, no spurious errors and
// exit code 0.

use crate::hardware::{audio, backlight, battery, dpms, resolve_bool, touchpad, webcam};
use crate::{cfg_dir, home_dir, pgrep_exact, run_out, run_quiet, runtime_dir, spawn_quiet};
use std::fs;

pub use crate::settings_probe::print_probe;

/// Process exit code for an unrecognised setting domain.
const EXIT_UNKNOWN_DOMAIN: i32 = 2;

/// Every domain this engine accepts, grouped for `supersettings` help output.
pub const DOMAINS: &[&str] = &[
    "default",
    "default-ext",
    "default-preset",
    "default-reset",
    "mode",
    "hardware",
    "vaapi",
    "ui-scale",
    "animations",
    "orca",
    "mono-audio",
    "touchpad",
    "webcam",
    "mic",
    "speaker",
    "kbd-backlight",
    "kbd",
    "battery-limit",
    "dpms",
];

/// Apply a single setting. `args[0]` is the domain, `args[1]` the value.
pub fn apply_setting(args: &[String]) -> i32 {
    let act = args.first().map(|s| s.as_str()).unwrap_or("");
    let val = args.get(1).map(|s| s.as_str()).unwrap_or("");
    let cfg = cfg_dir();

    match act {
        "default" | "default-app" => {
            let sub = args.get(2).map(|s| s.as_str()).unwrap_or("");
            run_quiet("xdg-terminal-exec", &["--set", val, sub]);
            refresh();
            0
        }
        "default-preset" | "preset" => {
            run_quiet(
                "xdg-terminal-exec",
                &["--preset", if val.is_empty() { "superfedora" } else { val }],
            );
            refresh();
            0
        }
        "default-ext" => {
            let sub = args.get(2).map(|s| s.as_str()).unwrap_or("");
            run_quiet("xdg-terminal-exec", &["--set-ext", val, sub]);
            refresh();
            0
        }
        "default-reset" => {
            run_quiet("xdg-terminal-exec", &["--reset"]);
            refresh();
            0
        }
        "mode" | "profile" => {
            run_quiet(
                "superfedora",
                &["mode", if val.is_empty() { "cycle" } else { val }],
            );
            refresh();
            0
        }
        "hardware" | "vaapi" => {
            run_quiet("superfedora", &["hardware", "optimize"]);
            refresh();
            0
        }
        "ui-scale" => {
            let sz: u32 = match val {
                "compact" | "small" | "13" => 13,
                "default" | "normal" | "14" => 14,
                "large" | "16" | "17" => 16,
                "xlarge" | "xl" | "18" | "20" => 18,
                _ => val.parse::<u32>().unwrap_or(14).clamp(12, 22),
            };
            let _ = fs::write(cfg.join("ui-scale"), format!("{sz}\n"));
            run_quiet("qs", &["ipc", "call", "theme", "reload"]);
            refresh();
            0
        }
        "animations" => {
            let cur = fs::read_to_string(cfg.join("animations"))
                .map(|s| !matches!(s.trim(), "0" | "off"))
                .unwrap_or(true);
            let enable = match val {
                "on" | "1" => true,
                "off" | "0" => false,
                _ => !cur,
            };
            let _ = fs::write(
                cfg.join("animations"),
                if enable { "1\n" } else { "0\n" },
            );
            run_quiet(
                "hyprctl",
                &[
                    "keyword",
                    "animations:enabled",
                    if enable { "true" } else { "false" },
                ],
            );
            refresh();
            0
        }
        "orca" => {
            let running = pgrep_exact("orca");
            let want = resolve_bool(val, running).unwrap_or(!running);
            if running && !want {
                run_quiet("pkill", &["-x", "orca"]);
            } else if !running && want {
                spawn_quiet("orca", &[]);
            }
            refresh();
            0
        }
        "mono-audio" => {
            apply_mono_audio(val, &cfg);
            refresh();
            0
        }
        "touchpad" => touchpad::apply(val, &cfg, &runtime_dir()),
        "webcam" => webcam::apply(val, &cfg, &home_dir()),
        "mic" => audio::apply(audio::Node::Source, val),
        "speaker" => audio::apply(audio::Node::Sink, val),
        "kbd-backlight" | "kbd" => backlight::apply(val, &cfg),
        "battery-limit" => battery::apply(val),
        "dpms" => dpms::apply(val, &runtime_dir()),
        other => {
            eprintln!(
                "[FAIL] Unknown setting domain: {other}\n       Known domains: {}",
                DOMAINS.join(", ")
            );
            EXIT_UNKNOWN_DOMAIN
        }
    }
}

/// Refresh the Quickshell Status model after a mutating action.
fn refresh() {
    run_quiet("qs", &["ipc", "call", "status", "refresh"]);
}

/// Route every stream through a mono PipeWire sink, remembering the real sink.
fn apply_mono_audio(val: &str, cfg: &std::path::Path) {
    let cur = fs::read_to_string(cfg.join("mono-audio"))
        .map(|s| s.trim() == "1")
        .unwrap_or(false);
    let next = resolve_bool(val, cur).unwrap_or(!cur);
    let _ = fs::write(
        cfg.join("mono-audio"),
        if next { "1\n" } else { "0\n" },
    );
    let cur_sink = run_out("pactl", &["get-default-sink"]);
    if !cur_sink.is_empty() && cur_sink != "superfedora_mono" {
        let _ = fs::write(cfg.join("mono-prev-sink"), format!("{cur_sink}\n"));
    }
    let prev_sink = fs::read_to_string(cfg.join("mono-prev-sink"))
        .unwrap_or_default()
        .trim()
        .to_string();
    run_quiet("pactl", &["unload-module", "module-remap-sink"]);
    if !next {
        if !prev_sink.is_empty() {
            run_quiet("pactl", &["set-default-sink", &prev_sink]);
        }
        return;
    }
    let master = format!("master={prev_sink}");
    let mut args = vec!["load-module", "module-remap-sink", "sink_name=superfedora_mono"];
    if !prev_sink.is_empty() {
        args.push(&master);
    }
    args.extend(["channels=2", "channel_map=mono,mono"]);
    run_quiet("pactl", &args);
    run_quiet("pactl", &["set-default-sink", "superfedora_mono"]);
}