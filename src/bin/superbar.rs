// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

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
    widgets::{Block, Borders, List, ListItem, Paragraph},
};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::{self, IsTerminal};
use std::process;
use std::time::Duration;
use supershell::{ShellEnv, play_sfx, qs_call, qs_running};

const DEFAULT_ICONS: &[&str] = &["wifi", "bluetooth", "|", "speaker", "mic", "camera", "|", "battery", "power"];

#[derive(Clone, Serialize, Deserialize)]
struct BarIcons {
    order: Vec<String>,
    hidden: Vec<String>,
}

impl Default for BarIcons {
    fn default() -> Self {
        Self {
            order: DEFAULT_ICONS.iter().map(|s| s.to_string()).collect(),
            hidden: Vec::new(),
        }
    }
}

fn load_icons(env: &ShellEnv) -> BarIcons {
    let p = env.state_dir.join("bar-icons.json");
    if let Ok(txt) = fs::read_to_string(&p)
        && let Ok(ic) = serde_json::from_str::<BarIcons>(&txt)
    {
        return ic;
    }
    BarIcons::default()
}

fn save_icons(env: &ShellEnv, ic: &BarIcons) {
    if let Ok(s) = serde_json::to_string_pretty(ic) {
        let _ = fs::write(env.state_dir.join("bar-icons.json"), format!("{s}\n"));
    }
    let _ = qs_call("status", &["reloadBar"]);
}

fn load_clock(env: &ShellEnv) -> (bool, bool) {
    let mut c24 = true;
    let mut csec = false;
    if let Ok(txt) = fs::read_to_string(env.state_dir.join("clock.conf")) {
        for line in txt.lines() {
            if line.trim() == "CLOCK_24H=0" { c24 = false; }
            if line.trim() == "CLOCK_SECONDS=1" { csec = true; }
        }
    }
    (c24, csec)
}

fn save_clock(env: &ShellEnv, c24: bool, csec: bool) {
    let _ = fs::write(
        env.state_dir.join("clock.conf"),
        format!("CLOCK_24H={}\nCLOCK_SECONDS={}\n", if c24 { 1 } else { 0 }, if csec { 1 } else { 0 }),
    );
    let _ = qs_call("status", &["refresh"]);
}

fn run_tui(env: &ShellEnv) -> i32 {
    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else { let _ = disable_raw_mode(); return 1; };
    let mut ic = load_icons(env);
    let (mut c24, mut csec) = load_clock(env);
    let mut sel = 0usize;
    let mut msg = String::from("SuperBar 16-Bit Top Bar & SuperDeck Studio Ready");

    loop {
        let _ = term.draw(|f| {
            let pri = env.pri();
            let sec = env.sec();
            let rows = Layout::default().direction(Direction::Vertical).constraints([Constraint::Length(3), Constraint::Min(10), Constraint::Length(3)]).split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERBAR v0.4.1 ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw(format!("  Daemon: {}  |  Clock: {} ({}) ", if qs_running() { "ONLINE" } else { "OFFLINE" }, if c24 { "24h" } else { "12h" }, if csec { "+sec" } else { "no-sec" })),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let items: Vec<ListItem> = ic.order.iter().enumerate().map(|(i, id)| {
                let is_sel = i == sel;
                let hidden = ic.hidden.contains(id);
                ListItem::new(Line::from(vec![
                    Span::styled(if is_sel { " > " } else { "   " }, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
                    Span::styled(if hidden { "[HIDDEN] " } else { "[SHOWN ] " }, Style::default().fg(if hidden { Color::Red } else { Color::Green }).add_modifier(Modifier::BOLD)),
                    Span::styled(id, Style::default().fg(if is_sel { Color::Black } else { Color::White }).bg(if is_sel { pri } else { Color::Reset }).add_modifier(Modifier::BOLD)),
                ]))
            }).collect();
            let list = List::new(items).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(sec)).title(" TOP BAR SYSTEM TRAY & POCKET ICONS (Enter=Toggle Hide, d=Dividers, r=Reset) "));
            f.render_widget(list, rows[1]);

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" KEYS ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" [Enter] Show/Hide  [t] Toggle Bar  [c] 24h/12h  [s] Seconds  [d] Dividers  [r] Reset  [q] Quit | "),
                Span::styled(&msg, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[2]);
        });

        if event::poll(Duration::from_millis(250)).unwrap_or(false)
            && let Ok(Event::Key(k)) = event::read()
            && k.kind == KeyEventKind::Press
        {
            let len = ic.order.len().max(1);
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Down | KeyCode::Char('j') => sel = (sel + 1) % len,
                KeyCode::Up | KeyCode::Char('k') => sel = (sel + len - 1) % len,
                KeyCode::Enter => {
                    if let Some(id) = ic.order.get(sel).cloned() && id != "|" {
                        if ic.hidden.contains(&id) { ic.hidden.retain(|x| x != &id); } else { ic.hidden.push(id.clone()); }
                        save_icons(env, &ic);
                        play_sfx("toggle");
                        msg = format!("Toggled icon visibility: {id}");
                    }
                }
                KeyCode::Char('t') => { let _ = qs_call("bar", &["toggle"]); msg = "Toggled Top Bar visibility".into(); }
                KeyCode::Char('c') => { c24 = !c24; save_clock(env, c24, csec); play_sfx("toggle"); msg = format!("Clock 24h: {c24}"); }
                KeyCode::Char('s') => { csec = !csec; save_clock(env, c24, csec); play_sfx("toggle"); msg = format!("Clock seconds: {csec}"); }
                KeyCode::Char('d') => {
                    if ic.order.iter().any(|x| x == "|") {
                        ic.order.retain(|x| x != "|");
                    } else {
                        ic = BarIcons::default();
                    }
                    save_icons(env, &ic);
                    sel = 0;
                    msg = "Toggled bar dividers".into();
                }
                KeyCode::Char('r') => {
                    ic = BarIcons::default();
                    save_icons(env, &ic);
                    sel = 0;
                    msg = "Reset bar icons to default".into();
                }
                _ => {}
            }
        }
    }
    let _ = disable_raw_mode();
    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
    let _ = term.show_cursor();
    0
}

fn main() {
    let env = ShellEnv::load();
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() && io::stdin().is_terminal() && io::stdout().is_terminal() {
        process::exit(run_tui(&env));
    }
    let cmd = args.first().map(|s| s.as_str()).unwrap_or("status");
    let mut ic = load_icons(&env);
    let (mut c24, mut csec) = load_clock(&env);
    match cmd {
        "tui" => process::exit(run_tui(&env)),
        "version" | "--version" | "-V" => println!("superbar 0.4.1 (SuperFedora/supershell)"),
        "--stream-json" | "stream-json" => {
            let once = args.iter().any(|a| a == "--once" || a == "-1");
            let frames = args.windows(2).find(|w| w[0] == "--frames").and_then(|w| w[1].parse::<usize>().ok());
            process::exit(supershell::telemetry_hud::run_stream_json(once, frames));
        }
        "--telemetry-json" | "telemetry-json" | "telemetry" => {
            process::exit(supershell::telemetry_hud::run_stream_json(true, Some(1)));
        }
        "hud" | "--hud" | "layer-shell" => {
            let once = args.iter().any(|a| a == "--once" || a == "-1" || a == "--json");
            process::exit(supershell::telemetry_hud::run_native_hud(&env, once));
        }
        "mode" | "profile" => {
            let m = args.get(1).map(|s| s.as_str()).unwrap_or("status");
            let code = process::Command::new("superfedora").args(["mode", m]).status().map(|s| s.code().unwrap_or(0)).unwrap_or(1);
            process::exit(code);
        }
        "status" | "list" => {
            let ws_mode = fs::read_to_string(env.state_dir.join("workstation-mode")).unwrap_or_else(|_| "balanced".into());
            println!("SuperBar Daemon : {}", if qs_running() { "running (quickshell)" } else { "native-hud ready" });
            println!("Workstation Mode: {}", ws_mode.trim().to_uppercase());
            println!("Clock Format    : {} ({})", if c24 { "24-hour" } else { "12-hour" }, if csec { "seconds shown" } else { "no seconds" });
            println!("Bar Icon Order  : {}", ic.order.join(" "));
            println!("Hidden Icons    : {}", if ic.hidden.is_empty() { "none".into() } else { ic.hidden.join(", ") });
        }
        "toggle" => {
            let _ = qs_call("bar", &["toggle"]);
            println!("[OK] Toggled SuperBar visibility");
        }
        "reload" | "refresh" => {
            let _ = qs_call("status", &["reloadBar"]);
            let _ = qs_call("status", &["refresh"]);
            println!("[OK] Reloaded SuperBar state");
        }
        "deck" | "superdeck" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("toggle");
            if sub == "toggle" { let _ = qs_call("superdeck", &["toggle"]); }
            else if sub == "close" { let _ = qs_call("superdeck", &["close"]); }
            else { let _ = qs_call("superdeck", &["open", sub]); }
            println!("[OK] SuperDeck action: {sub}");
        }
        "clock" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("status");
            match sub {
                "24h" => { c24 = true; save_clock(&env, c24, csec); println!("[OK] Clock set to 24-hour"); }
                "12h" => { c24 = false; save_clock(&env, c24, csec); println!("[OK] Clock set to 12-hour"); }
                "seconds" => { csec = !csec; save_clock(&env, c24, csec); println!("[OK] Clock seconds: {csec}"); }
                _ => println!("Clock: {} (seconds: {})", if c24 { "24h" } else { "12h" }, csec),
            }
        }
        "icons" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("list");
            match sub {
                "reset" => { ic = BarIcons::default(); save_icons(&env, &ic); println!("[OK] Reset bar icons"); }
                "hide" => if let Some(id) = args.get(2) { if !ic.hidden.contains(id) { ic.hidden.push(id.clone()); } save_icons(&env, &ic); println!("[OK] Hid icon {id}"); }
                "show" => if let Some(id) = args.get(2) { ic.hidden.retain(|x| x != id); save_icons(&env, &ic); println!("[OK] Showed icon {id}"); }
                _ => println!("Order: {}\nHidden: {:?}", ic.order.join(" "), ic.hidden),
            }
        }
        _ => {
            println!("Usage: superbar [status|--stream-json [--once]|--telemetry-json|hud [--once]|mode [stealth|balanced|forge|arcade]|toggle|reload|deck|clock|icons|tui]");
            if cmd != "-h" && cmd != "--help" && cmd != "help" { process::exit(2); }
        }
    }
}
