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
use serde_json::Value;
use std::env;
use std::fs;
use std::io::{self, IsTerminal};
use std::process::{self, Command};
use std::time::Duration;
use supershell::{ShellEnv, play_sfx, qs_call, qs_running};

#[derive(Clone, Default, Serialize, Deserialize)]
struct NotifState {
    #[serde(default)]
    dnd: bool,
    #[serde(default)]
    history: Vec<Value>,
}

fn load_notifs(env: &ShellEnv) -> NotifState {
    let p = env.state_dir.join("notifications.json");
    if let Ok(txt) = fs::read_to_string(&p) && let Ok(st) = serde_json::from_str::<NotifState>(&txt) { return st; }
    let st = NotifState::default();
    save_notifs(env, &st);
    st
}

fn save_notifs(env: &ShellEnv, st: &NotifState) {
    if let Ok(s) = serde_json::to_string_pretty(st) { let _ = fs::write(env.state_dir.join("notifications.json"), format!("{s}\n")); }
}

fn trigger_banner(kind: &str) -> i32 {
    let (id, sfx, label) = match kind.to_ascii_lowercase().as_str() {
        "ready" | "boot" | "login" | "unlock" => ("ready", "startup", "R E A D Y"),
        "warn" | "warning" | "critical" | "alert" | "danger" => ("warning", "alert", "W A R N I N G"),
        "update" | "forge" | "complete" => ("update", "confirm", "U P D A T E   C O M P L E T E"),
        "checkpoint" | "snapshot" | "btrfs" | "saved" => ("checkpoint", "confirm", "C H E C K P O I N T   S A V E D"),
        _ => { eprintln!("Usage: supernotify --banner <ready|warning|update|checkpoint>"); return 2; }
    };
    if !qs_call("notifications", &["banner", id]) { play_sfx(sfx); }
    println!("  [OK] Banner triggered: {label}");
    0
}

fn trigger_cast(role: &str, custom_title: Option<&str>, custom_body: Option<&str>) -> i32 {
    let r = role.to_ascii_lowercase();
    if let Some(title) = custom_title {
        let (app, urg) = match r.as_str() {
            "ai" | "agent" | "openclaw" | "agy" | "ollama" => ("AGY // OPENCLAW", "normal"),
            "sec" | "security" | "alert" | "polkit" => ("POLKIT // GUARD", "critical"),
            "build" | "builder" | "forge" => ("SF FORGE", "normal"),
            "eng" | "engineer" | "sys" | "system" => ("SUPERFEDORA", "normal"),
            _ => ("FIREFOX", "normal"),
        };
        let mut c = Command::new("notify-send");
        c.args(["-u", urg, "-a", app, title]);
        if let Some(b) = custom_body { c.arg(b); }
        let _ = c.status();
        println!("  [OK] Cast comms transmitted [{app}]: {title}");
        return 0;
    }
    if r == "all" || r == "test" {
        let _ = qs_call("notifications", &["cast", "all"]);
        println!("  [OK] Cast comms triggered: Full Workstation Cast Showcase");
        return 0;
    }
    let (id, urg, app, title, body, desc) = match r.as_str() {
        "ai" | "agent" | "openclaw" | "agy" | "claude" | "ollama" | "pi" => (
            "ai", "normal", "AGY // OPENCLAW", "Neural Harness Link Active",
            "Context indexed. Ready for code synthesis and workstation automation.", "AI Agent (Bottom-Center)",
        ),
        "sec" | "security" | "alert" | "polkit" | "firewall" | "critical" => (
            "security", "critical", "POLKIT // GUARD", "Privilege Escalation Check",
            "Critical telemetry & policy guard monitoring active.", "Security / System Alert (Top-Center + WARNING Banner)",
        ),
        "build" | "builder" | "forge" | "dnf" | "cargo" | "gcc" => (
            "builder", "normal", "SF FORGE", "Native Target Compiled",
            "Built with -O3 -march=native -flto=auto and linked via mold.", "Builder / Forge (Top-Right)",
        ),
        "eng" | "engineer" | "sys" | "system" | "superfedora" | "btrfs" => (
            "engineer", "normal", "SUPERFEDORA", "Btrfs Checkpoint Verified",
            "Workstation subvolume state synchronized and ready for rollback.", "System Engineer (Top-Right)",
        ),
        "app" | "apps" | "firefox" | "discord" | "slack" | "spotify" => (
            "app", "normal", "FIREFOX", "External App Transmission",
            "Incoming desktop application relay framed in 16-bit scanline bezel.", "App Comms (Top-Right)",
        ),
        _ => { eprintln!("Usage: supernotify --cast <ai|security|builder|engineer|app|all>"); return 2; }
    };
    if !qs_call("notifications", &["cast", id]) {
        let _ = Command::new("notify-send").args(["-u", urg, "-a", app, title, body]).status();
    }
    println!("  [OK] Cast comms triggered: {desc}");
    0
}

fn run_tui(env: &ShellEnv) -> i32 {
    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else { let _ = disable_raw_mode(); return 1; };
    let mut st = load_notifs(env);
    let mut msg = String::from("SuperNotify 16-Bit Cast Comms & Banner Controller Ready");

    loop {
        let _ = term.draw(|f| {
            let (pri, sec) = (env.pri(), env.sec());
            let rows = Layout::default().direction(Direction::Vertical).constraints([Constraint::Length(3), Constraint::Min(10), Constraint::Length(3)]).split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERNOTIFY v0.1.0 ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw(format!("  DND: {}  |  Unread: {}  |  Cast Portraits: Ready ", if st.dnd { "ON" } else { "OFF" }, st.history.len())),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let items: Vec<ListItem> = if st.history.is_empty() {
                vec![ListItem::new("  [--] No unread notifications in history.")]
            } else {
                st.history.iter().enumerate().map(|(i, v)| {
                    let s = v.get("summary").and_then(|x| x.as_str()).unwrap_or("Notification");
                    let b = v.get("body").and_then(|x| x.as_str()).unwrap_or("");
                    let role = v.get("roleTitle").or_else(|| v.get("role")).and_then(|x| x.as_str()).unwrap_or("SYS ENG");
                    ListItem::new(format!("  [{:02}] [{role}] {s} — {b}", i + 1))
                }).collect()
            };
            f.render_widget(List::new(items).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(sec)).title(" NOTIFICATION HISTORY & CAST COMMS RELAY ")), rows[1]);

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" KEYS ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" [d] DND  [c] Clear  [1-5] Cast (AI/Sec/Build/Eng/App)  [r/w/u/p] Banners  [q] Quit | "),
                Span::styled(&msg, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[2]);
        });

        if event::poll(Duration::from_millis(250)).unwrap_or(false) && let Ok(Event::Key(k)) = event::read() && k.kind == KeyEventKind::Press {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Char('d') => {
                    st.dnd = !st.dnd;
                    save_notifs(env, &st);
                    let _ = qs_call("notifications", &["setDnd", if st.dnd { "on" } else { "off" }]);
                    msg = format!("Do Not Disturb: {}", if st.dnd { "on" } else { "off" });
                }
                KeyCode::Char('c') => { st.history.clear(); save_notifs(env, &st); let _ = qs_call("notifications", &["dismissAll"]); msg = "Cleared all notifications".into(); }
                KeyCode::Char('1') => { let _ = trigger_cast("ai", None, None); msg = "Cast Comms: AI Agent".into(); }
                KeyCode::Char('2') => { let _ = trigger_cast("security", None, None); msg = "Cast Comms: Security".into(); }
                KeyCode::Char('3') => { let _ = trigger_cast("builder", None, None); msg = "Cast Comms: Builder".into(); }
                KeyCode::Char('4') => { let _ = trigger_cast("engineer", None, None); msg = "Cast Comms: System Engineer".into(); }
                KeyCode::Char('5') => { let _ = trigger_cast("app", None, None); msg = "Cast Comms: App".into(); }
                KeyCode::Char('r') => { let _ = trigger_banner("ready"); msg = "Banner: READY".into(); }
                KeyCode::Char('w') => { let _ = trigger_banner("warning"); msg = "Banner: WARNING".into(); }
                KeyCode::Char('u') => { let _ = trigger_banner("update"); msg = "Banner: UPDATE COMPLETE".into(); }
                KeyCode::Char('p') => { let _ = trigger_banner("checkpoint"); msg = "Banner: CHECKPOINT SAVED".into(); }
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
    let mut st = load_notifs(&env);
    if let Some(b) = action.strip_prefix("--banner=") { process::exit(trigger_banner(b)); }
    if let Some(c) = action.strip_prefix("--cast=") { process::exit(trigger_cast(c, args.get(1).map(|s| s.as_str()), args.get(2).map(|s| s.as_str()))); }
    match action {
        "tui" => process::exit(run_tui(&env)),
        "version" | "--version" | "-V" => println!("supernotify 0.1.0 (SuperFedora/supershell)"),
        "status" => {
            println!("  [OK] Notification Server : {}", if qs_running() { "running (quickshell)" } else { "offline" });
            println!("  [OK] Do Not Disturb      : {}", if st.dnd { "on" } else { "off" });
            println!("  [OK] Unread in Center    : {}", st.history.len());
            println!("  [OK] Cast Portrait Dir   : {}", env.state_dir.join("cast").display());
        }
        "history" | "list" => {
            println!("SuperFedora Notification History (DND: {}, Unread: {})", if st.dnd { "on" } else { "off" }, st.history.len());
            if st.history.is_empty() {
                println!("  [--] No unread notifications in history.");
            } else {
                for (i, item) in st.history.iter().enumerate() {
                    let t = item.get("time").and_then(|v| v.as_str()).unwrap_or("--:--");
                    let urg = item.get("urgency").and_then(|v| v.as_str()).unwrap_or("normal").to_uppercase();
                    let role = item.get("roleTitle").or_else(|| item.get("role")).and_then(|v| v.as_str()).unwrap_or("SYS ENG").to_uppercase();
                    let app = item.get("appName").and_then(|v| v.as_str()).unwrap_or("System");
                    let s = item.get("summary").and_then(|v| v.as_str()).unwrap_or("Notification");
                    let b = item.get("body").and_then(|v| v.as_str()).unwrap_or("").replace('\n', " ");
                    let sfx = if b.trim().is_empty() { String::new() } else { format!(" — {}", b.trim()) };
                    println!("  [{:02}] {t} [{role} // {app}] ({urg}): {s}{sfx}", i + 1);
                }
            }
        }
        "--banner" | "banner" => process::exit(trigger_banner(args.get(1).map(|s| s.as_str()).unwrap_or("ready"))),
        "--cast" | "cast" | "character" | "role" => process::exit(trigger_cast(args.get(1).map(|s| s.as_str()).unwrap_or("all"), args.get(2).map(|s| s.as_str()), args.get(3).map(|s| s.as_str()))),
        "test" | "preview" => {
            let tgt = args.get(1).map(|s| s.as_str()).unwrap_or("all");
            if matches!(tgt.to_ascii_lowercase().as_str(), "ready" | "warn" | "warning" | "update" | "checkpoint") {
                process::exit(trigger_banner(tgt));
            } else {
                process::exit(trigger_cast(tgt, None, None));
            }
        }
        "dnd" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("toggle");
            if sub == "status" || sub == "get" {
                println!("{}", if st.dnd { "on" } else { "off" });
            } else if matches!(sub, "on" | "off" | "toggle") {
                st.dnd = if sub == "toggle" { !st.dnd } else { sub == "on" };
                save_notifs(&env, &st);
                let lbl = if st.dnd { "on" } else { "off" };
                let _ = qs_call("notifications", &["setDnd", lbl]);
                println!("  [OK] Do Not Disturb: {lbl}");
            } else {
                eprintln!("Usage: supernotify dnd [on|off|toggle|status]");
                process::exit(2);
            }
        }
        "clear" | "dismiss-all" | "dismissAll" => { st.history.clear(); save_notifs(&env, &st); let _ = qs_call("notifications", &["dismissAll"]); println!("  [OK] Cleared all notifications."); }
        "dismiss" => { if !qs_call("notifications", &["dismiss"]) && !st.history.is_empty() { st.history.remove(0); save_notifs(&env, &st); } println!("  [OK] Dismissed latest notification."); }
        "center" | "toggle" => { let _ = qs_call("notifications", &["toggle"]); println!("  [OK] Toggled Notification Center."); }
        "send" => {
            let title = args.get(1).map(|s| s.as_str()).unwrap_or("SuperFedora");
            let mut c = Command::new("notify-send");
            c.args(["-a", "SuperFedora", title]);
            if let Some(body) = args.get(2) && !body.is_empty() { c.arg(body); }
            let _ = c.status();
            println!("  [OK] Sent notification: {title}");
        }
        "-h" | "--help" | "help" => println!("Usage: supernotify [status|history|dnd|clear|dismiss|center|send|--banner|--cast|tui]"),
        _ => { eprintln!("unknown notify action: {action}"); process::exit(2); }
    }
}
