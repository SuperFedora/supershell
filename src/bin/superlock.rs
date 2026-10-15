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
use std::env;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::{self, Command, Stdio};
use std::time::Duration;
use supershell::{ShellEnv, play_sfx, qs_call, run_quiet};

fn discover_sessions() -> Vec<(String, String)> {
    let mut out = Vec::new();
    for dir in ["/usr/share/wayland-sessions", "/usr/share/xsessions"] {
        if let Ok(entries) = fs::read_dir(dir) {
            let mut paths: Vec<_> = entries.flatten().map(|e| e.path()).filter(|p| p.extension().and_then(|x| x.to_str()) == Some("desktop")).collect();
            paths.sort();
            for p in paths {
                let id = p.file_stem().and_then(|s| s.to_str()).unwrap_or("hyprland").to_string();
                let name = fs::read_to_string(&p)
                    .ok()
                    .and_then(|t| t.lines().find_map(|l| l.strip_prefix("Name=").map(|s| s.trim().to_string())))
                    .unwrap_or_else(|| id.clone());
                out.push((id, name));
            }
        }
    }
    if out.is_empty() {
        out.push(("hyprland".into(), "Hyprland".into()));
        out.push(("gnome".into(), "GNOME".into()));
    }
    out
}

fn current_session_id(env: &ShellEnv) -> String {
    if let Ok(txt) = fs::read_to_string(env.state_dir.join("session.env")) {
        for line in txt.lines() {
            if let Some((k, v)) = line.split_once('=') && k.trim() == "SELECTED_SESSION" {
                let val = v.trim().trim_matches('"').trim_matches('\'');
                if !val.is_empty() {
                    return val.to_string();
                }
            }
        }
    }
    "hyprland".into()
}

fn set_session_id(env: &ShellEnv, target: &str) {
    let _ = fs::write(env.state_dir.join("session.env"), format!("SELECTED_SESSION=\"{target}\"\n"));
    let uid = Command::new("id").arg("-u").output().ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_else(|| "1000".into());
    let obj = format!("/org/freedesktop/Accounts/User{uid}");
    run_quiet("gdbus", &["call", "--system", "--dest", "org.freedesktop.Accounts", "--object-path", &obj, "--method", "org.freedesktop.Accounts.User.SetSession", target]);
    run_quiet("gdbus", &["call", "--system", "--dest", "org.freedesktop.Accounts", "--object-path", &obj, "--method", "org.freedesktop.Accounts.User.SetXSession", target]);
}

fn activate_lock() {
    if !qs_call("lock", &["activate"]) {
        if Command::new("hyprlock").status().is_err() {
            run_quiet("loginctl", &["lock-session"]);
        }
    }
}

fn idle_mode(env: &ShellEnv) -> String {
    fs::read_to_string(env.state_dir.join("idle-mode"))
        .map(|s| s.trim().to_string())
        .ok()
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "poweroff".into())
}

fn run_tui(env: &ShellEnv) -> i32 {
    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = std::io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else { let _ = disable_raw_mode(); return 1; };
    let sessions = discover_sessions();
    let mut cur_id = current_session_id(env);
    let mut sel = sessions.iter().position(|(id, _)| *id == cur_id).unwrap_or(0);
    let mut msg = String::from("SuperLock 16-Bit Lock Screen, Idle & DE Session Manager Ready");

    loop {
        let idle = idle_mode(env);
        let _ = term.draw(|f| {
            let pri = env.pri();
            let sec = env.sec();
            let rows = Layout::default().direction(Direction::Vertical).constraints([Constraint::Length(3), Constraint::Min(10), Constraint::Length(3)]).split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERLOCK v0.3.0 ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw(format!("  Selected DE: {cur_id}  |  Idle Mode: {idle} ")),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let items: Vec<ListItem> = sessions.iter().enumerate().map(|(i, (id, name))| {
                let is_sel = i == sel;
                let is_act = *id == cur_id;
                ListItem::new(Line::from(vec![
                    Span::styled(if is_sel { " > " } else { "   " }, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
                    Span::styled(if is_act { "[SELECTED] " } else { "           " }, Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                    Span::styled(format!("{id:<18} ({name})"), Style::default().fg(if is_sel { Color::Black } else { Color::White }).bg(if is_sel { pri } else { Color::Reset }).add_modifier(Modifier::BOLD)),
                ]))
            }).collect();
            let list = List::new(items).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(sec)).title(" INSTALLED WAYLAND / X11 SESSIONS (Enter=Select DE, l=Lock Now, i=Cycle Idle Mode) "));
            f.render_widget(list, rows[1]);

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" KEYS ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" [Enter] Select DE  [n] Next DE  [l] Lock Workstation  [i] Cycle Idle Mode  [q] Quit | "),
                Span::styled(&msg, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[2]);
        });

        if event::poll(Duration::from_millis(250)).unwrap_or(false)
            && let Ok(Event::Key(k)) = event::read()
            && k.kind == KeyEventKind::Press
        {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Down | KeyCode::Char('j') => sel = (sel + 1) % sessions.len(),
                KeyCode::Up | KeyCode::Char('k') => sel = (sel + sessions.len() - 1) % sessions.len(),
                KeyCode::Enter => {
                    cur_id = sessions[sel].0.clone();
                    set_session_id(env, &cur_id);
                    play_sfx("confirm");
                    msg = format!("Selected DE session: {cur_id}");
                }
                KeyCode::Char('n') => {
                    sel = (sel + 1) % sessions.len();
                    cur_id = sessions[sel].0.clone();
                    set_session_id(env, &cur_id);
                    play_sfx("click");
                    msg = format!("Cycled DE session: {cur_id}");
                }
                KeyCode::Char('l') => {
                    let _ = disable_raw_mode();
                    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
                    activate_lock();
                    return 0;
                }
                KeyCode::Char('i') => {
                    let script = env.home.join(".config/hypr/scripts/toggle-idle.sh");
                    if Path::new(&script).is_file() {
                        let _ = Command::new(script).status();
                    }
                    msg = format!("Idle mode: {}", idle_mode(env));
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
    let cmd = args.first().map(|s| s.as_str()).unwrap_or("status");
    let sessions = discover_sessions();
    let cur_id = current_session_id(&env);
    let cur_idx = sessions.iter().position(|(id, _)| *id == cur_id).unwrap_or(0);
    let cur_name = &sessions[cur_idx].1;

    match cmd {
        "tui" => process::exit(run_tui(&env)),
        "version" | "--version" | "-V" => println!("superlock 0.3.0 (SuperFedora/supershell)"),
        "lock" | "activate" => activate_lock(),
        "status" => println!("<b>\u{f0493} DE: {cur_name}</b>"),
        "list" => {
            for (i, (id, name)) in sessions.iter().enumerate() {
                let mark = if i == cur_idx { "[*]" } else { "   " };
                println!("{mark} {id:<20} ({name})");
            }
        }
        "next" => {
            let next_idx = (cur_idx + 1) % sessions.len();
            set_session_id(&env, &sessions[next_idx].0);
            println!("<b>\u{f0493} DE: {}</b>", sessions[next_idx].1);
        }
        "set" => {
            let target = args.get(1).map(|s| s.as_str()).unwrap_or("hyprland");
            set_session_id(&env, target);
        }
        "switch" => {
            run_quiet("gdbus", &["call", "--system", "--dest", "org.gnome.DisplayManager", "--object-path", "/org/gnome/DisplayManager/LocalDisplayFactory", "--method", "org.gnome.DisplayManager.LocalDisplayFactory.CreateTransientDisplay"]);
            run_quiet("systemctl", &["--user", "stop", "hyprland-session.target"]);
            run_quiet("systemctl", &["--user", "reset-failed"]);
            run_quiet("hyprctl", &["dispatch", "exit"]);
        }
        "pick" => {
            let mut input = String::new();
            for (id, name) in &sessions { input.push_str(&format!("{id}: {name}\n")); }
            if let Ok(mut child) = Command::new("fuzzel").args(["--dmenu", "--prompt", "Select DE > ", "--lines", "6", "--width", "38"]).stdin(Stdio::piped()).stdout(Stdio::piped()).spawn() {
                if let Some(mut stdin) = child.stdin.take() { let _ = stdin.write_all(input.as_bytes()); }
                if let Ok(out) = child.wait_with_output() && out.status.success() {
                    let choice = String::from_utf8_lossy(&out.stdout);
                    if let Some((sel_id, _)) = choice.trim().split_once(':') && !sel_id.is_empty() {
                        set_session_id(&env, sel_id);
                    }
                }
            }
        }
        "idle" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("status");
            if sub == "status" {
                println!("{}", idle_mode(&env));
            } else {
                let script = env.home.join(".config/hypr/scripts/toggle-idle.sh");
                let _ = Command::new(script).arg(sub).status();
            }
        }
        "-h" | "--help" | "help" => {
            println!("Usage: superlock [lock|status|list|next|set <id>|switch|pick|idle|tui]");
        }
        _ => {
            eprintln!("unknown superlock command: {cmd}");
            process::exit(2);
        }
    }
}
