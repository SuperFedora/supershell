// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// settings_devices.rs — Session, Graphics & Application Role Telemetry
// ==============================================================================
// Read-only probes feeding the `MODE`, `A11Y`, `GPU` and `DEF` records of the
// SuperSettings telemetry block. Nothing here mutates machine state.

use crate::hardware::touchpad;
use crate::{pgrep_exact, runtime_dir};
use std::fs;
use std::path::Path;

/// Session policy and accessibility block: workstation mode, text size,
/// animations, narrator, night light, touchpad and mono audio.
pub fn emit_session(cfg: &Path) {
    let rt_dir = runtime_dir();
    let ui_scale = read_num(&cfg.join("ui-scale")).unwrap_or(14);
    let anim_on = read_inverted(&cfg.join("animations"), false);
    let orca_on = pgrep_exact("orca");
    let night_on = pgrep_exact("wlsunset");
    let night_temp = read_num(&cfg.join("nightlight-temp")).unwrap_or(4000);
    let tpad_on = touchpad::query_enabled(cfg, &rt_dir);
    let mono_on = read_on(&cfg.join("mono-audio"), false);
    let ws_mode = fs::read_to_string(cfg.join("workstation-mode"))
        .unwrap_or_else(|_| "balanced".into())
        .trim()
        .to_string();
    let pk_idle = if Path::new("/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf")
        .exists()
    {
        "On-Demand (30s ShutdownTimeout)"
    } else {
        "On-Demand (Socket)"
    };
    println!("MODE|{ws_mode}|{pk_idle}");
    println!(
        "A11Y|{ui_scale}|{}|{}|{}|{}|{}|{night_temp}",
        u8::from(anim_on),
        u8::from(orca_on),
        u8::from(night_on),
        u8::from(tpad_on),
        u8::from(mono_on)
    );
}

/// GPU architecture, VA-API driver, FFmpeg and DMABUF status.
pub fn emit_graphics(cfg: &Path) {
    let mut gpu_arch = String::from("Generic KMS/DRM GPU");
    let mut va_drv = "Mesa VA-API";
    if let Ok(entries) = fs::read_dir("/sys/bus/pci/devices") {
        for e in entries.flatten() {
            let p = e.path();
            if fs::read_to_string(p.join("class"))
                .unwrap_or_default()
                .trim()
                .starts_with("0x03")
            {
                match fs::read_to_string(p.join("vendor")).unwrap_or_default().trim() {
                    "0x1002" => {
                        gpu_arch = "AMD RDNA / Radeon".into();
                        va_drv = "radeonsi (Mesa Freeworld)";
                    }
                    "0x8086" => {
                        gpu_arch = "Intel Arc / Xe".into();
                        va_drv = "iHD (Intel Media Driver)";
                    }
                    "0x10de" => {
                        gpu_arch = "NVIDIA RTX / GeForce".into();
                        va_drv = "nvidia (NVDEC VA-API)";
                    }
                    _ => {}
                }
                break;
            }
        }
    }
    let ff_ok = Path::new("/usr/bin/ffmpeg").exists();
    let dmabuf_ok = cfg.join("firefox-vaapi.js").is_file();
    println!(
        "GPU|{gpu_arch}|{va_drv}|{}|{}",
        if ff_ok { "Full FFmpeg + VA-API" } else { "ffmpeg-free" },
        if dmabuf_ok { "Zero-Copy DMABUF Active" } else { "Standard" }
    );
}

/// The thirteen default application roles from `defaults.env`, in wire order.
const APP_ROLES: [&str; 13] = [
    "DEFAULT_TERMINAL",
    "DEFAULT_BROWSER",
    "DEFAULT_FILES",
    "DEFAULT_EDITOR",
    "DEFAULT_MONITOR",
    "DEFAULT_PDF",
    "DEFAULT_IMAGE",
    "DEFAULT_VIDEO",
    "DEFAULT_AUDIO",
    "DEFAULT_OFFICE",
    "DEFAULT_MAIL",
    "DEFAULT_ARCHIVE",
    "DEFAULT_SUITE",
];

/// Built-in fallback for each default application role.
const APP_FALLBACKS: [&str; 13] = [
    "kitty",
    "firefox",
    "yazi",
    "nvim",
    "btop",
    "zathura",
    "imv",
    "mpv",
    "mpv",
    "libreoffice",
    "thunderbird",
    "file-roller",
    "superfedora",
];

/// Emit the twelve default app roles, overridden from `defaults.env`.
pub fn emit_defaults(cfg: &Path) {
    let mut roles: Vec<String> = APP_FALLBACKS.map(String::from).to_vec();
    if let Ok(text) = fs::read_to_string(cfg.join("defaults.env")) {
        for (key, value) in text.lines().filter_map(|l| l.split_once('=')) {
            let Some(idx) = APP_ROLES.iter().position(|&n| n == key.trim()) else {
                continue;
            };
            roles[idx] = value
                .trim()
                .trim_matches('"')
                .trim_matches('\'')
                .to_string();
        }
    }
    println!("DEF|{}", roles.join("|"));
}

/// Read a trimmed unsigned integer config value.
pub fn read_num(path: &Path) -> Option<u32> {
    fs::read_to_string(path).ok()?.trim().parse::<u32>().ok()
}

/// Read a boolean config value where `1` / `on` / `true` mean true.
pub fn read_on(path: &Path, default: bool) -> bool {
    match fs::read_to_string(path) {
        Ok(s) => matches!(s.trim(), "1" | "on" | "true"),
        Err(_) => default,
    }
}

/// Read an inverted boolean config value (`0` / `off` mean false), used by
/// `animations` where a stored zero disables visual effects.
pub fn read_inverted(path: &Path, default: bool) -> bool {
    match fs::read_to_string(path) {
        Ok(s) => !matches!(s.trim(), "0" | "off" | "false"),
        Err(_) => default,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn read_num_parses_and_defaults() {
        let dir = crate::hardware::scratch("probe-num");
        let f = dir.join("ui-scale");
        assert_eq!(read_num(&f), None);
        fs::write(&f, "18\n").unwrap();
        assert_eq!(read_num(&f), Some(18));
        fs::write(&f, "not-a-number\n").unwrap();
        assert_eq!(read_num(&f), None);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn read_on_honours_on_off_and_default() {
        let dir = crate::hardware::scratch("probe-on");
        let f = dir.join("mono-audio");
        assert!(!read_on(&f, false));
        assert!(read_on(&f, true));
        fs::write(&f, "1\n").unwrap();
        assert!(read_on(&f, false));
        fs::write(&f, "off\n").unwrap();
        assert!(!read_on(&f, true));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn read_inverted_is_the_complement() {
        let dir = crate::hardware::scratch("probe-inv");
        let f = dir.join("animations");
        // A missing file falls back to the caller supplied default.
        assert!(!read_inverted(&f, false));
        assert!(read_inverted(&f, true));
        fs::write(&f, "0\n").unwrap();
        assert!(!read_inverted(&f, true));
        fs::write(&f, "off\n").unwrap();
        assert!(!read_inverted(&f, true));
        fs::write(&f, "1\n").unwrap();
        assert!(read_inverted(&f, false));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn app_role_table_is_aligned() {
        assert_eq!(APP_ROLES.len(), APP_FALLBACKS.len());
        assert_eq!(APP_ROLES.len(), 13);
        assert_eq!(APP_ROLES[0], "DEFAULT_TERMINAL");
        assert_eq!(*APP_ROLES.last().unwrap(), "DEFAULT_SUITE");
    }
}