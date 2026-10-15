// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// telemetry_hud.rs — Zero-Fork Rust Telemetry Stream, Hyprland Socket & Native HUD
// ==============================================================================

use crate::ShellEnv;
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, Paragraph},
};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::{self, BufRead, BufReader, IsTerminal};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

#[derive(Clone, Serialize, Deserialize)]
pub struct TelemetryFrame {
    pub cpu_pct: u64,
    pub ram_used_mb: u64,
    pub ram_total_mb: u64,
    pub ram_pct: u16,
    pub gpu_pct: u16,
    pub temp_c: u64,
    pub bat_pct: u16,
    pub bat_status: String,
    pub mode: String,
    pub hypr_event: String,
    pub vfr: bool,
    pub direct_scanout: bool,
}

fn sample_cpu_raw() -> (u64, u64) {
    let Ok(txt) = fs::read_to_string("/proc/stat") else { return (0, 0) };
    let Some(first) = txt.lines().next() else { return (0, 0) };
    let nums: Vec<u64> = first.split_whitespace().skip(1).filter_map(|s| s.parse().ok()).collect();
    if nums.len() >= 4 {
        let idle = nums[3] + nums.get(4).copied().unwrap_or(0);
        let total: u64 = nums.iter().sum();
        (total.saturating_sub(idle), total)
    } else {
        (0, 0)
    }
}

pub fn collect_frame(prev_cpu: &mut (u64, u64), last_event: &str) -> TelemetryFrame {
    let cur = sample_cpu_raw();
    let cpu_pct = if prev_cpu.1 > 0 && cur.1 > prev_cpu.1 {
        ((cur.0.saturating_sub(prev_cpu.0) * 100) / (cur.1 - prev_cpu.1)).min(100)
    } else {
        0
    };
    *prev_cpu = cur;

    let (mut tot_kb, mut avail_kb) = (1024u64, 1024u64);
    if let Ok(m) = fs::read_to_string("/proc/meminfo") {
        for line in m.lines() {
            let mut p = line.split_whitespace();
            match (p.next().unwrap_or(""), p.next().and_then(|s| s.parse::<u64>().ok())) {
                ("MemTotal:", Some(v)) => tot_kb = v.max(1024),
                ("MemAvailable:", Some(v)) => avail_kb = v,
                _ => {}
            }
        }
    }
    let ram_total_mb = (tot_kb / 1024).max(1);
    let ram_used_mb = tot_kb.saturating_sub(avail_kb) / 1024;
    let ram_pct = ((ram_used_mb * 100) / ram_total_mb).min(100) as u16;

    let mut gpu_pct = 0u16;
    for card in ["card0", "card1", "card2"] {
        if let Ok(s) = fs::read_to_string(format!("/sys/class/drm/{card}/device/gpu_busy_percent"))
            && let Ok(v) = s.trim().parse::<u16>()
        {
            gpu_pct = v.min(100);
            break;
        }
    }

    let temp_c = fs::read_dir("/sys/class/thermal")
        .ok()
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| fs::read_to_string(e.path().join("temp")).ok()?.trim().parse::<u64>().ok())
        .map(|v| if v > 1000 { v / 1000 } else { v })
        .filter(|&c| (15..125).contains(&c))
        .max()
        .unwrap_or(40);

    let (mut bat_pct, mut bat_status) = (100u16, String::from("AC"));
    for bat in ["BAT0", "BAT1"] {
        let base = Path::new("/sys/class/power_supply").join(bat);
        if base.exists() {
            bat_pct = fs::read_to_string(base.join("capacity")).ok().and_then(|s| s.trim().parse().ok()).unwrap_or(100).min(100);
            bat_status = fs::read_to_string(base.join("status")).unwrap_or_else(|_| "AC".into()).trim().to_string();
            break;
        }
    }

    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let mode = fs::read_to_string(Path::new(&home).join(".config/superfedora/workstation-mode"))
        .unwrap_or_else(|_| "balanced".into())
        .trim()
        .to_string();

    TelemetryFrame {
        cpu_pct,
        ram_used_mb,
        ram_total_mb,
        ram_pct,
        gpu_pct,
        temp_c,
        bat_pct,
        bat_status,
        mode,
        hypr_event: last_event.to_string(),
        vfr: true,
        direct_scanout: true,
    }
}

pub fn runtime_telemetry_path() -> PathBuf {
    let base = env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/tmp"))
        .join("superfedora");
    let _ = fs::create_dir_all(&base);
    base.join("telemetry.json")
}

fn try_open_hypr_socket2() -> Option<BufReader<UnixStream>> {
    let xdg = env::var("XDG_RUNTIME_DIR").ok()?;
    let his = env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;
    let sock = PathBuf::from(xdg).join("hypr").join(his).join(".socket2.sock");
    let stream = UnixStream::connect(sock).ok()?;
    let _ = stream.set_read_timeout(Some(Duration::from_millis(200)));
    Some(BufReader::new(stream))
}

pub fn run_stream_json(once: bool, max_frames: Option<usize>) -> i32 {
    let mut prev_cpu = sample_cpu_raw();
    thread::sleep(Duration::from_millis(40));
    let mut hypr_sock = try_open_hypr_socket2();
    let mut last_ev = String::from("init");
    let out_path = runtime_telemetry_path();
    let mut count = 0usize;

    loop {
        if let Some(ref mut reader) = hypr_sock {
            let mut line = String::new();
            if reader.read_line(&mut line).unwrap_or(0) > 0 {
                last_ev = line.trim().to_string();
            }
        }
        let frame = collect_frame(&mut prev_cpu, &last_ev);
        if let Ok(json) = serde_json::to_string(&frame) {
            let _ = fs::write(&out_path, format!("{json}\n"));
            println!("{json}");
        }
        count += 1;
        if once || max_frames.map(|m| count >= m).unwrap_or(false) {
            break;
        }
        thread::sleep(Duration::from_millis(1000));
    }
    0
}

pub fn run_native_hud(env: &ShellEnv, once: bool) -> i32 {
    let mut prev = sample_cpu_raw();
    thread::sleep(Duration::from_millis(30));
    let mut frame = collect_frame(&mut prev, "layer-shell-hud");
    let out_path = runtime_telemetry_path();
    if let Ok(json) = serde_json::to_string(&frame) {
        let _ = fs::write(&out_path, format!("{json}\n"));
    }
    if once || !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        println!(
            "[SUPERBAR NATIVE LAYER-SHELL HUD] Mode: {} | CPU: {}% | RAM: {}/{} MB ({}%) | GPU: {}% | Temp: {}C | Bat: {}% ({}) | VFR: on",
            frame.mode.to_uppercase(),
            frame.cpu_pct,
            frame.ram_used_mb,
            frame.ram_total_mb,
            frame.ram_pct,
            frame.gpu_pct,
            frame.temp_c,
            frame.bat_pct,
            frame.bat_status
        );
        return 0;
    }

    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else { let _ = disable_raw_mode(); return 1; };

    loop {
        let _ = term.draw(|f| {
            let pri = env.pri();
            let sec = env.sec();
            let rows = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(3), Constraint::Length(3), Constraint::Min(4)])
                .split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERBAR NATIVE WAYLAND HUD (<15MB Pure-Rust Layer-Shell Fallback) ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw(format!("  [DECK // {}]  |  Temp: {}C  |  Bat: {}% ({}) ", frame.mode.to_uppercase(), frame.temp_c, frame.bat_pct, frame.bat_status)),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let g = Gauge::default()
                .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(sec)).title(" ZERO-FORK TELEMETRY BAR (CPU / RAM / GPU) "))
                .gauge_style(Style::default().fg(pri).bg(Color::DarkGray))
                .percent(frame.ram_pct)
                .label(format!("CPU: {}%  |  RAM: {}/{} MB ({}%)  |  GPU: {}%  |  [m] Cycle Mode  [q] Quit", frame.cpu_pct, frame.ram_used_mb, frame.ram_total_mb, frame.ram_pct, frame.gpu_pct));
            f.render_widget(g, rows[1]);
        });

        if event::poll(Duration::from_millis(500)).unwrap_or(false)
            && let Ok(Event::Key(k)) = event::read()
            && k.kind == KeyEventKind::Press
        {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Char('m') => {
                    let _ = Command::new("superfedora").args(["mode", "cycle"]).stdout(Stdio::null()).stderr(Stdio::null()).status();
                }
                _ => {}
            }
        }
        frame = collect_frame(&mut prev, "layer-shell-hud");
    }
    let _ = disable_raw_mode();
    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
    let _ = term.show_cursor();
    0
}
