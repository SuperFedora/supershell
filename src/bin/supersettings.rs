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
use std::io::{self, IsTerminal};
use std::process;
use std::time::Duration;
use supershell::{
    ShellEnv, play_sfx, qs_call,
    settings_engine::{apply_setting, print_probe},
};

const PAGES: &[(&str, &str, &str)] = &[
    ("system", "01 System & Display", "Monitors, GPU VA-API Codecs, Audio, Brightness, Nightlight"),
    ("devices", "02 Devices & Bluetooth", "Bluetooth controllers, On-Demand CUPS Socket, Touchpad & Input"),
    ("network", "03 Network & VPN", "Wi-Fi SSIDs, Ethernet, DNS, Firewalld & WireGuard/Tailscale"),
    ("personalization", "04 Personalization", "16-Bit Rainbow Palettes, Day/Night Mode, Corners, Wallpapers"),
    ("windowing", "05 Windowing & Shell", "SuperDock Edge/Autohide, SuperBar HUD, VFR & Direct Scanout"),
    ("notifications", "06 Notifications & Clock", "Do Not Disturb, 10 Cast Specialists, 24h Clock & Overlay"),
    ("apps", "07 Apps & SuperForge", "2-Tier Binary Cache, -march=native Builds, Firefox WebApps"),
    ("accounts", "08 Accounts & Security", "User Groups, Shell, SSH ED25519 Keys, PAM & Fingerprint"),
    ("accessibility", "09 Accessibility", "UI Font Scale, Animations, Screen Reader (Orca), Mono Audio"),
    ("power", "10 Power, Mode & Vault", "Workstation Modes (Stealth/Balanced/Forge/Arcade), Btrfs Vault & AI"),
];

fn run_tui(env: &ShellEnv) -> i32 {
    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else { let _ = disable_raw_mode(); return 1; };
    let mut sel = 0usize;
    let mut msg = String::from("SuperSettings 10-Page Workstation Configurator Ready");

    loop {
        let _ = term.draw(|f| {
            let pri = env.pri();
            let sec = env.sec();
            let rows = Layout::default().direction(Direction::Vertical).constraints([Constraint::Length(3), Constraint::Min(12), Constraint::Length(3)]).split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERSETTINGS v0.4.0 ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw("  10-Page Native Rust Workstation Settings Engine (VA-API + Modes + Btrfs) "),
            ])).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let items: Vec<ListItem> = PAGES.iter().enumerate().map(|(i, &(id, title, desc))| {
                let is_sel = i == sel;
                ListItem::new(Line::from(vec![
                    Span::styled(if is_sel { " > " } else { "   " }, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
                    Span::styled(format!("{title:<26}"), Style::default().fg(if is_sel { Color::Black } else { Color::White }).bg(if is_sel { pri } else { Color::Reset }).add_modifier(Modifier::BOLD)),
                    Span::styled(format!(" [{id:<15}] "), Style::default().fg(sec)),
                    Span::styled(desc, Style::default().fg(Color::Gray)),
                ]))
            }).collect();
            let list = List::new(items).block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(sec)).title(" WORKSTATION SETTINGS PAGES (Enter=Open GUI Page, m=Cycle Mode, t=Toggle Theme, c=Toggle Corners) "));
            f.render_widget(list, rows[1]);

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" KEYS ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" [Enter] Open Page  [m] Cycle Mode  [g] Optimize GPU/VA-API  [t] Day/Night  [c] Corners  [q] Quit | "),
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
                KeyCode::Down | KeyCode::Char('j') => sel = (sel + 1) % PAGES.len(),
                KeyCode::Up | KeyCode::Char('k') => sel = (sel + PAGES.len() - 1) % PAGES.len(),
                KeyCode::Enter => {
                    let id = PAGES[sel].0;
                    let _ = qs_call("settings", &["open", id]);
                    play_sfx("click");
                    msg = format!("Opened settings page: {id}");
                }
                KeyCode::Char('m') => {
                    let _ = apply_setting(&["mode".into(), "cycle".into()]);
                    msg = "Cycled 16-Bit Workstation Mode (Stealth/Balanced/Forge/Arcade)".into();
                }
                KeyCode::Char('g') => {
                    let _ = apply_setting(&["hardware".into(), "optimize".into()]);
                    msg = "Applied GPU VA-API & Firefox zero-copy DMABUF optimization".into();
                }
                KeyCode::Char('t') => {
                    let _ = apply_setting(&["theme".into(), "toggle".into()]);
                    msg = "Toggled Day/Night mode".into();
                }
                KeyCode::Char('c') => {
                    let _ = apply_setting(&["corners".into(), "toggle".into()]);
                    msg = "Toggled Square/Rounded corners".into();
                }
                KeyCode::Char('n') => {
                    let _ = apply_setting(&["theme".into(), "next".into()]);
                    msg = "Rotated to next 16-bit palette".into();
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
    if args.is_empty() {
        if io::stdin().is_terminal() && io::stdout().is_terminal() {
            process::exit(run_tui(&env));
        } else {
            let _ = qs_call("settings", &["toggle"]);
            return;
        }
    }
    let cmd = args[0].as_str();
    match cmd {
        "tui" => process::exit(run_tui(&env)),
        "version" | "--version" | "-V" => println!("supersettings 0.4.0 (SuperFedora/supershell)"),
        "probe" | "settings-probe" => print_probe(),
        "apply" | "settings-apply" => process::exit(apply_setting(&args[1..])),
        "mode" | "profile" | "hardware" | "vaapi" | "theme" | "palette" | "corners"
        | "ui-scale" | "animations" | "nightlight" | "orca" | "mono-audio" => {
            process::exit(apply_setting(&args))
        }
        "open" => {
            let page = args.get(1).map(|s| s.as_str()).unwrap_or("system");
            let _ = qs_call("settings", &["open", page]);
            println!("[OK] Opened SuperSettings page: {page}");
        }
        "toggle" => {
            if let Some(p) = args.get(1) {
                let _ = qs_call("settings", &["open", p]);
            } else {
                let _ = qs_call("settings", &["toggle"]);
            }
        }
        "close" => { let _ = qs_call("settings", &["close"]); }
        "list" | "status" => {
            for &(id, title, desc) in PAGES {
                println!("  {:<16} {:<26} {}", id, title, desc);
            }
            print_probe();
        }
        "-h" | "--help" | "help" => {
            println!("Usage: supersettings [tui|probe|apply <domain> <action>|open [page]|toggle|list]");
        }
        other => {
            let _ = qs_call("settings", &["open", other]);
        }
    }
}
