// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// hardware/webcam.rs — Camera Privacy Gate: uvcvideo + WirePlumber Fragment
// ==============================================================================

use crate::hardware::refresh_status;
use crate::{notify_send, run_quiet};
use std::fs;
use std::path::Path;

/// Managed WirePlumber fragment filename, ordered last in `conf.d`.
pub const CONF_NAME: &str = "99-superfedora-webcam.conf";

/// Persisted webcam intent (`~/.config/superfedora/webcam-enabled`).
pub fn enabled(cfg_dir: &Path) -> bool {
    fs::read_to_string(cfg_dir.join("webcam-enabled"))
        .map(|s| s.trim() != "off")
        .unwrap_or(true)
}

/// WirePlumber SPA-JSON fragment that hides every camera from the graph.
///
/// WirePlumber merges configuration fragments recursively per object, so this
/// file only overrides the two camera monitors inside the system `main`
/// profile and leaves the rest of the user's configuration intact. It is
/// deleted entirely when the camera is re-enabled.
pub fn wireplumber_conf() -> String {
    concat!(
        "# Managed by supershell (Apache-2.0) -- SuperFedora webcam privacy gate.\n",
        "# Both camera monitors are disabled so no camera node reaches the\n",
        "# PipeWire graph. Delete this fragment, or run\n",
        "# `supersettings apply webcam on`, to restore capture.\n",
        "wireplumber.profiles = {\n",
        "  main = {\n",
        "    monitor.v4l2 = disabled\n",
        "    monitor.libcamera = disabled\n",
        "  }\n",
        "}\n",
    )
    .to_string()
}

/// Create or remove the WirePlumber fragment for the requested camera state.
pub fn sync_wireplumber(home: &Path, camera_on: bool) -> bool {
    let dir = home.join(".config/wireplumber/wireplumber.conf.d");
    let conf = dir.join(CONF_NAME);
    if camera_on {
        return fs::remove_file(&conf).is_ok() || !conf.exists();
    }
    if fs::create_dir_all(&dir).is_err() {
        return false;
    }
    fs::write(&conf, wireplumber_conf()).is_ok()
}

/// Apply `webcam <toggle|on|off|status>`.
///
/// Unloads (or reloads) the `uvcvideo` kernel module with a non-interactive
/// `sudo -n`, keeps the WirePlumber fragment in sync, restarts the user
/// PipeWire/WirePlumber stack and refreshes Quickshell.
pub fn apply(val: &str, cfg_dir: &Path, home: &Path) -> i32 {
    let current = enabled(cfg_dir);
    let verb = val.trim().to_ascii_lowercase();
    if verb == "status" {
        println!("[OK] webcam: {}", if current { "on" } else { "off" });
        return 0;
    }
    let want = match verb.as_str() {
        "" | "toggle" => !current,
        "on" | "enable" | "enabled" | "1" => true,
        "off" | "disable" | "disabled" | "0" => false,
        other => {
            eprintln!("[FAIL] webcam expects one of: toggle | on | off | status (got '{other}')");
            return 2;
        }
    };
    let _ = fs::write(
        cfg_dir.join("webcam-enabled"),
        if want { "on\n" } else { "off\n" },
    );
    let conf_ok = sync_wireplumber(home, want);
    let mut mp = vec!["-n", "modprobe"];
    if !want {
        mp.push("-r");
    }
    mp.push("uvcvideo");
    run_quiet("sudo", &mp);
    run_quiet("systemctl", &["--user", "restart", "wireplumber.service"]);
    notify_send(
        if want { "Webcam Enabled" } else { "Webcam Disabled" },
        if want {
            "Camera module reloaded · WirePlumber camera monitors enabled"
        } else {
            "uvcvideo unloaded · WirePlumber camera monitors hidden"
        },
    );
    refresh_status();
    println!(
        "[{}] webcam {} (wireplumber fragment: {})",
        if want { "OK" } else { "--" },
        if want { "on" } else { "off" },
        if conf_ok { "synced" } else { "unavailable" }
    );
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn conf_fragment_is_valid_spajson_with_both_monitors() {
        let conf = wireplumber_conf();
        assert!(conf.contains("monitor.v4l2 = disabled"));
        assert!(conf.contains("monitor.libcamera = disabled"));
        assert!(conf.contains("wireplumber.profiles = {"));
        // Balanced braces and one comment header per leading line.
        assert_eq!(conf.matches('{').count(), 2);
        assert_eq!(conf.matches('}').count(), 2);
        assert!(conf.ends_with("}\n"));
    }

    #[test]
    fn conf_is_deterministic() {
        assert_eq!(wireplumber_conf(), wireplumber_conf());
    }

    #[test]
    fn fragment_lifecycle_is_idempotent() {
        let dir = crate::hardware::scratch("webcam");
        let home = dir.join("home");
        let confd = home.join(".config/wireplumber/wireplumber.conf.d");
        assert!(sync_wireplumber(&home, false));
        assert!(confd.join(CONF_NAME).is_file());
        assert_eq!(fs::read_to_string(confd.join(CONF_NAME)).unwrap(), wireplumber_conf());
        // Re-applying the same state must not fail and must not duplicate.
        assert!(sync_wireplumber(&home, false));
        assert_eq!(fs::read_dir(&confd).unwrap().count(), 1);
        // Enabling removes the fragment; repeating is still a success.
        assert!(sync_wireplumber(&home, true));
        assert!(!confd.join(CONF_NAME).exists());
        assert!(sync_wireplumber(&home, true));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn persisted_intent_roundtrips() {
        let dir = crate::hardware::scratch("webcam-state");
        let cfg = dir.join("cfg");
        fs::create_dir_all(&cfg).unwrap();
        assert!(enabled(&cfg));
        fs::write(cfg.join("webcam-enabled"), "off\n").unwrap();
        assert!(!enabled(&cfg));
        fs::write(cfg.join("webcam-enabled"), "on\n").unwrap();
        assert!(enabled(&cfg));
        let _ = fs::remove_dir_all(&dir);
    }
}