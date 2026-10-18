// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/audio.rs — Mic & Speaker Control via wpctl with Mute LED Sync
// ==============================================================================

use crate::hardware::{refresh_status, set_brightness};
use crate::{notify_send, qs_call, run_out, run_quiet};
use std::path::Path;

/// Volume delta applied by the `up` and `down` verbs, in percent.
const STEP: &str = "5%";

/// PipeWire default node families addressed by this module.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Node {
    Sink,
    Source,
}

impl Node {
    /// `@DEFAULT_AUDIO_*@` selector understood by wpctl.
    pub fn target(self) -> &'static str {
        match self {
            Node::Sink => "@DEFAULT_AUDIO_SINK@",
            Node::Source => "@DEFAULT_AUDIO_SOURCE@",
        }
    }

    /// Platform mute indicator LED class for this node family.
    pub fn mute_led(self) -> &'static str {
        match self {
            Node::Sink => "platform::mute",
            Node::Source => "platform::micmute",
        }
    }

    /// Human readable setting domain name.
    pub fn label(self) -> &'static str {
        match self {
            Node::Sink => "speaker",
            Node::Source => "mic",
        }
    }
}

/// Parse `wpctl get-volume` output such as `Volume: 0.55`, `Volume: 55%` or
/// `Volume: 1.00 [MUTED]` into `(volume 0.0..=1.0, muted)`.
///
/// Both the fractional and the percentage spellings wpctl has shipped are
/// accepted; anything unparseable degrades to silence rather than panicking.
///
/// Pure function: unit tested without a running PipeWire daemon.
pub fn parse_volume(out: &str) -> (f32, bool) {
    let vol = out
        .split_whitespace()
        .find_map(|word| {
            let (digits, is_percent) = match word.strip_suffix('%') {
                Some(d) => (d, true),
                None => (word, false),
            };
            digits
                .parse::<f32>()
                .ok()
                .map(|v| if is_percent { v / 100.0 } else { v })
        })
        .unwrap_or(0.0)
        .clamp(0.0, 1.0);
    (vol, out.contains("[MUTED]"))
}

/// Live `(volume, muted)` state for a node family.
pub fn status(node: Node) -> (f32, bool) {
    parse_volume(&run_out("wpctl", &["get-volume", node.target()]))
}

/// Mirror the mute state onto the platform mute LED: lit while muted, dark
/// while live. Silently no-ops when the machine exposes no such LED class.
fn sync_mute_led(node: Node, muted: bool) {
    let dir = Path::new("/sys/class/leds").join(node.mute_led());
    if dir.is_dir() {
        set_brightness(&dir, u32::from(muted));
    }
}

fn set_mute(node: Node, muted: bool) {
    run_quiet("wpctl", &["set-mute", node.target(), if muted { "1" } else { "0" }]);
}

/// Shared tail for every mutating verb: sync the LED, fire the volume OSD,
/// refresh Quickshell, then notify.
fn finish(node: Node, expect: Option<bool>) -> i32 {
    let (vol, muted) = status(node);
    let muted = expect.unwrap_or(muted);
    sync_mute_led(node, muted);
    let _ = qs_call("osd", &["volume"]);
    refresh_status();
    let label = node.label();
    notify_send(
        &format!("{label} {}", if muted { "Muted" } else { "Unmuted" }),
        &format!("Volume {:.0}%", vol * 100.0),
    );
    println!(
        "[{}] {} muted={} vol={:.0}%",
        if muted { "--" } else { "OK" },
        label,
        muted,
        vol * 100.0
    );
    0
}

/// Apply `mic|speaker <toggle|mute|unmute|up|down|status>`.
pub fn apply(node: Node, val: &str) -> i32 {
    let verb = val.trim().to_ascii_lowercase();
    let (_, muted) = status(node);
    match verb.as_str() {
        "status" => {
            let (vol, muted) = status(node);
            println!(
                "[OK] {} vol={:.0}% muted={}",
                node.label(),
                vol * 100.0,
                muted
            );
            0
        }
        "" | "toggle" => {
            set_mute(node, !muted);
            finish(node, Some(!muted))
        }
        "mute" | "off" => {
            set_mute(node, true);
            finish(node, Some(true))
        }
        "unmute" | "on" => {
            set_mute(node, false);
            finish(node, Some(false))
        }
        "up" | "down" => {
            let delta = if verb == "up" {
                format!("{STEP}+")
            } else {
                format!("{STEP}-")
            };
            run_quiet("wpctl", &["set-volume", "-l", "1.0", node.target(), &delta]);
            finish(node, None)
        }
        other => {
            eprintln!(
                "[FAIL] {} expects one of: toggle | mute | unmute | up | down | status (got '{other}')",
                node.label()
            );
            2
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_unmuted_volume() {
        assert_eq!(parse_volume("Volume: 0.55"), (0.55, false));
        assert_eq!(parse_volume("Volume: 1.00"), (1.0, false));
    }

    #[test]
    fn parses_muted_volume_and_percent() {
        assert_eq!(parse_volume("Volume: 1.00 [MUTED]"), (1.0, true));
        assert_eq!(parse_volume("Volume: 42%"), (0.42, false));
        assert_eq!(parse_volume("Volume: 42% [MUTED]"), (0.42, true));
        assert_eq!(parse_volume("Volume: 100%"), (1.0, false));
    }

    #[test]
    fn clamps_garbage_and_empty_output() {
        assert_eq!(parse_volume(""), (0.0, false));
        assert_eq!(parse_volume("Volume: 9.99"), (1.0, false));
        assert_eq!(parse_volume("wpctl: no object found"), (0.0, false));
    }

    #[test]
    fn node_families_are_distinct() {
        assert_eq!(Node::Sink.target(), "@DEFAULT_AUDIO_SINK@");
        assert_eq!(Node::Source.target(), "@DEFAULT_AUDIO_SOURCE@");
        assert_ne!(Node::Sink.mute_led(), Node::Source.mute_led());
        assert_eq!(Node::Sink.label(), "speaker");
        assert_eq!(Node::Source.label(), "mic");
    }
}