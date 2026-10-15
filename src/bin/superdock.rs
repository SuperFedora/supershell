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
use serde_json::Value;
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::io::{self, IsTerminal};
use std::process::{self, Command};
use std::time::Duration;
use supershell::{DockConfig, ShellEnv, WorkspaceModes, notify_dock, play_sfx, qs_call, run_quiet};

fn load_dock(env: &ShellEnv) -> DockConfig {
    let p = env.state_dir.join("dock.json");
    if let Ok(txt) = fs::read_to_string(&p) && let Ok(cfg) = serde_json::from_str::<DockConfig>(&txt) { return cfg; }
    let cfg = DockConfig::default();
    save_dock(env, &cfg);
    cfg
}

fn save_dock(env: &ShellEnv, cfg: &DockConfig) {
    if let Ok(s) = serde_json::to_string_pretty(cfg) { let _ = fs::write(env.state_dir.join("dock.json"), format!("{s}\n")); }
}

fn load_modes(env: &ShellEnv) -> WorkspaceModes {
    let p = env.state_dir.join("workspace-modes.json");
    if let Ok(txt) = fs::read_to_string(&p) && let Ok(m) = serde_json::from_str::<WorkspaceModes>(&txt) { return m; }
    let m = WorkspaceModes { default: "dwindle".into(), workspaces: BTreeMap::new() };
    save_modes(env, &m);
    m
}

fn save_modes(env: &ShellEnv, m: &WorkspaceModes) {
    if let Ok(s) = serde_json::to_string_pretty(m) { let _ = fs::write(env.state_dir.join("workspace-modes.json"), format!("{s}\n")); }
}

fn cmd_layout(env: &ShellEnv, sub: &str, ws_opt: Option<&str>) {
    let ws = ws_opt.map(|s| s.to_string()).unwrap_or_else(|| {
        Command::new("hyprctl").args(["activeworkspace", "-j"]).output().ok()
            .and_then(|o| serde_json::from_slice::<Value>(&o.stdout).ok())
            .and_then(|v| v.get("id").and_then(|i| i.as_i64()).map(|i| i.to_string()))
            .unwrap_or_else(|| "1".into())
    });
    let mut modes = load_modes(env);
    let cur = modes.workspaces.get(&ws).cloned().unwrap_or_else(|| modes.default.clone());
    if sub == "current" { println!("{cur}"); return; }
    let order = ["dwindle", "scrolling", "floating"];
    let cur_idx = order.iter().position(|&x| x == cur).unwrap_or(0);
    let nxt = match sub.to_ascii_lowercase().as_str() {
        "tiling" | "dwindle" => "dwindle",
        "scrolling" | "master" => "scrolling",
        "floating" => "floating",
        "back" => order[(cur_idx + 2) % 3],
        _ => order[(cur_idx + 1) % 3],
    };
    modes.workspaces.insert(ws.clone(), nxt.to_string());
    save_modes(env, &modes);
    let _ = fs::write(env.state_dir.join("tiling-layout"), format!("{nxt}\n"));

    let clients = Command::new("hyprctl").args(["clients", "-j"]).output().ok().and_then(|o| serde_json::from_slice::<Vec<Value>>(&o.stdout).ok()).unwrap_or_default();
    let ws_num = ws.parse::<i64>().unwrap_or(1);
    let mut batch = String::new();
    for c in &clients {
        let cw = c.get("workspace").and_then(|w| w.get("id")).and_then(|i| i.as_i64()).unwrap_or(-1);
        let mapped = c.get("mapped").and_then(|m| m.as_bool()).unwrap_or(false);
        let fl = c.get("floating").and_then(|f| f.as_bool()).unwrap_or(false);
        if cw == ws_num && mapped && let Some(addr) = c.get("address").and_then(|a| a.as_str()) {
            if nxt == "floating" && !fl {
                batch.push_str(&format!("dispatch setfloating address:{addr};dispatch resizewindowpixel exact 72% 74%,address:{addr};dispatch centerwindow 1;"));
            } else if nxt != "floating" && fl {
                batch.push_str(&format!("dispatch settiled address:{addr};"));
            }
        }
    }
    if nxt == "floating" {
        run_quiet("hyprctl", &["keyword", "input:follow_mouse", "0"]);
    } else {
        run_quiet("hyprctl", &["keyword", "general:layout", if nxt == "scrolling" { "master" } else { "dwindle" }]);
        run_quiet("hyprctl", &["keyword", "input:follow_mouse", "1"]);
    }
    if !batch.is_empty() { run_quiet("hyprctl", &["--batch", &batch]); }
    let lbl = if nxt == "dwindle" { "Tiling" } else if nxt == "scrolling" { "Scrolling" } else { "Floating" };
    run_quiet("notify-send", &["-a", "SuperFedora", "-t", "1400", &format!("Workspace {ws} layout"), &format!("Mode: {lbl}")]);
    notify_dock();
}

fn run_tui(env: &ShellEnv) -> i32 {
    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else { let _ = disable_raw_mode(); return 1; };
    let mut cfg = load_dock(env);
    let mut msg = String::from("SuperDock 16-Bit Controller Ready");

    loop {
        let _ = term.draw(|f| {
            let (pri, sec) = (env.pri(), env.sec());
            let rows = Layout::default().direction(Direction::Vertical).constraints([Constraint::Length(3), Constraint::Min(10), Constraint::Length(3)]).split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERDOCK v0.3.0 ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw(format!("  Edge: {}  |  Autohide: {}  |  ShowAlways: {} ", cfg.position, cfg.autohide, cfg.show_always)),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let items: Vec<ListItem> = cfg.pinned.iter().enumerate().map(|(i, p)| {
                ListItem::new(Line::from(vec![Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(sec).add_modifier(Modifier::BOLD)), Span::raw(p)]))
            }).collect();
            f.render_widget(List::new(items).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(sec)).title(" PINNED DOCK APPLICATIONS ")), rows[1]);

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" KEYS ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" [b/t/l/r] Edge  [a] Autohide  [s] ShowAlways  [w] Cycle WS Layout  [g] App Grid  [q] Quit | "),
                Span::styled(&msg, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[2]);
        });

        if event::poll(Duration::from_millis(250)).unwrap_or(false) && let Ok(Event::Key(k)) = event::read() && k.kind == KeyEventKind::Press {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Char('b') => { cfg.position = "bottom".into(); save_dock(env, &cfg); notify_dock(); msg = "Dock edge: bottom".into(); }
                KeyCode::Char('t') => { cfg.position = "top".into(); save_dock(env, &cfg); notify_dock(); msg = "Dock edge: top".into(); }
                KeyCode::Char('l') => { cfg.position = "left".into(); save_dock(env, &cfg); notify_dock(); msg = "Dock edge: left".into(); }
                KeyCode::Char('r') => { cfg.position = "right".into(); save_dock(env, &cfg); notify_dock(); msg = "Dock edge: right".into(); }
                KeyCode::Char('a') => { cfg.autohide = !cfg.autohide; save_dock(env, &cfg); notify_dock(); play_sfx("toggle"); msg = format!("Autohide: {}", cfg.autohide); }
                KeyCode::Char('s') => { cfg.show_always = !cfg.show_always; save_dock(env, &cfg); notify_dock(); play_sfx("toggle"); msg = format!("ShowAlways: {}", cfg.show_always); }
                KeyCode::Char('w') => { cmd_layout(env, "cycle", None); msg = "Cycled workspace layout".into(); }
                KeyCode::Char('g') => { let _ = qs_call("dock", &["toggleApps"]); msg = "Toggled Launchpad App Grid".into(); }
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
    if args.is_empty() && io::stdin().is_terminal() && io::stdout().is_terminal() { process::exit(run_tui(&env)); }
    let action = args.first().map(|s| s.as_str()).unwrap_or("status");
    let mut cfg = load_dock(&env);
    match action {
        "tui" => process::exit(run_tui(&env)),
        "version" | "--version" | "-V" => println!("superdock 0.3.0 (SuperFedora/supershell)"),
        "status" | "list" => {
            let modes = load_modes(&env);
            println!("Dock Position : {}", cfg.position);
            println!("Auto-Hide     : {}", if cfg.autohide { "on" } else { "off" });
            println!("Show Always   : {}", if cfg.show_always { "on (all workspaces)" } else { "off (floating workspaces only)" });
            println!("Pinned Apps   : {}", cfg.pinned.join(", "));
            if !modes.workspaces.is_empty() {
                let s: Vec<String> = modes.workspaces.iter().map(|(k, v)| format!("WS{k}={v}")).collect();
                println!("WS Layouts    : {}", s.join(", "));
            }
        }
        "position" | "edge" => {
            let pos = args.get(1).map(|s| s.to_ascii_lowercase()).unwrap_or_else(|| "bottom".into());
            if !matches!(pos.as_str(), "bottom" | "top" | "left" | "right") { eprintln!("Position must be bottom, top, left, or right"); process::exit(2); }
            cfg.position = pos.clone();
            save_dock(&env, &cfg);
            let _ = fs::write(env.state_dir.join("dock-position"), format!("{pos}\n"));
            notify_dock();
            println!("[OK] Dock position set to {pos}");
        }
        "autohide" => {
            let v = args.get(1).map(|s| s.to_ascii_lowercase()).unwrap_or_else(|| "toggle".into());
            cfg.autohide = if v == "toggle" { !cfg.autohide } else { matches!(v.as_str(), "on" | "true" | "1" | "yes") };
            save_dock(&env, &cfg);
            notify_dock();
            println!("[OK] Dock autohide {}", if cfg.autohide { "enabled" } else { "disabled" });
        }
        "always" | "show-always" | "toggle" => {
            let v = args.get(1).map(|s| s.to_ascii_lowercase()).unwrap_or_else(|| "toggle".into());
            cfg.show_always = if v == "toggle" || matches!(v.as_str(), "bottom" | "top" | "left" | "right") { !cfg.show_always } else { matches!(v.as_str(), "on" | "true" | "1" | "yes") };
            save_dock(&env, &cfg);
            notify_dock();
            println!("[OK] Dock visibility: {}", if cfg.show_always { "all workspaces" } else { "floating workspaces only" });
        }
        "pinned" => {
            cfg.pinned = args[1..].iter().map(|x| x.trim_end_matches(".desktop").to_string()).filter(|x| !x.is_empty()).collect();
            save_dock(&env, &cfg);
            notify_dock();
        }
        "pin" => {
            let Some(raw) = args.get(1) else { process::exit(2) };
            let app = raw.trim_end_matches(".desktop").to_string();
            let idx = args.get(2).and_then(|s| s.parse::<isize>().ok()).unwrap_or(-1);
            cfg.pinned.retain(|x| x != &app);
            if idx >= 0 && (idx as usize) <= cfg.pinned.len() { cfg.pinned.insert(idx as usize, app.clone()); } else { cfg.pinned.push(app.clone()); }
            save_dock(&env, &cfg);
            notify_dock();
            println!("[OK] Pinned {app} to dock");
        }
        "unpin" => {
            let Some(raw) = args.get(1) else { process::exit(2) };
            let app = raw.trim_end_matches(".desktop");
            cfg.pinned.retain(|x| x != app);
            save_dock(&env, &cfg);
            notify_dock();
            println!("[OK] Unpinned {app} from dock");
        }
        "apps" | "grid" | "launchpad" => { let _ = qs_call("dock", &["toggleApps"]); }
        "layout" | "mode" => cmd_layout(&env, args.get(1).map(|s| s.as_str()).unwrap_or("cycle"), args.get(2).map(|s| s.as_str())),
        "minimize" => {
            if let Ok(out) = Command::new("hyprctl").args(["activewindow", "-j"]).output()
                && let Ok(v) = serde_json::from_slice::<Value>(&out.stdout)
                && let Some(addr) = v.get("address").and_then(|a| a.as_str())
                && let Some(ws) = v.get("workspace").and_then(|w| w.get("id")).and_then(|i| i.as_i64())
                && !addr.is_empty() && ws > 0
            {
                run_quiet("hyprctl", &["--batch", &format!("dispatch movetoworkspacesilent special:minimized,address:{addr};dispatch workspace {ws}")]);
                notify_dock();
            }
        }
        "reset" | "init" | "preset" => {
            save_dock(&env, &DockConfig::default());
            save_modes(&env, &WorkspaceModes { default: "dwindle".into(), workspaces: BTreeMap::new() });
            notify_dock();
            println!("[OK] Dock reset to Omarchy defaults");
        }
        _ => {
            println!("Usage: superdock [status|position|autohide|always|pinned|pin|unpin|apps|layout|minimize|reset|tui]");
            if action != "-h" && action != "--help" && action != "help" { process::exit(2); }
        }
    }
}
