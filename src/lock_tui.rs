// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// lock_tui.rs — Retro 16-Bit Session & Idle Manager TUI (superlock tui)
// ==============================================================================
// Rendering only. Every mutation is delegated back to the caller through the
// `LockUi` callback bundle so the session, idle and lock policy stays owned by
// the `superlock` binary itself.

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
use crate::{ShellEnv, play_sfx};
use std::time::Duration;

/// Installed Wayland/X11 sessions as `(session id, display name)`.
pub type Sessions = Vec<(String, String)>;

/// All state the TUI needs from its owner, as borrowed callbacks.
pub struct LockUi<'a> {
    pub env: &'a ShellEnv,
    pub sessions: Sessions,
    pub current: String,
    pub set_session: &'a dyn Fn(&str),
    pub idle_mode: &'a dyn Fn() -> String,
    pub cycle_idle: &'a dyn Fn(&str) -> String,
    pub lock_now: &'a dyn Fn(),
}

impl LockUi<'_> {
    /// Render the session manager until the user quits or locks the screen.
    pub fn run(&mut self) -> i32 {
        if enable_raw_mode().is_err() {
            return 1;
        }
        let mut stdout = std::io::stdout();
        let _ = execute!(stdout, EnterAlternateScreen);
        let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else {
            let _ = disable_raw_mode();
            return 1;
        };
        let mut sel = self
            .sessions
            .iter()
            .position(|(id, _)| *id == self.current)
            .unwrap_or(0);
        let mut msg = String::from("SuperLock 16-Bit Lock Screen, Idle & DE Session Manager Ready");

        loop {
            let idle = (self.idle_mode)();
            let pri = self.env.pri();
            let sec = self.env.sec();
            let cur = self.current.clone();
            let _ = term.draw(|f| {
                let rows = Layout::default()
                    .direction(Direction::Vertical)
                    .constraints([
                        Constraint::Length(3),
                        Constraint::Min(10),
                        Constraint::Length(3),
                    ])
                    .split(f.area());
                let hdr = Paragraph::new(Line::from(vec![
                    Span::styled(
                        concat!(" [::] SUPERLOCK v", env!("CARGO_PKG_VERSION"), " "),
                        Style::default()
                            .fg(Color::Black)
                            .bg(pri)
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::raw(format!("  Selected DE: {cur}  |  Idle Mode: {idle} ")),
                ]))
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(pri)),
                );
                f.render_widget(hdr, rows[0]);

                let items: Vec<ListItem> = self
                    .sessions
                    .iter()
                    .enumerate()
                    .map(|(i, (id, name))| {
                        let is_sel = i == sel;
                        let is_act = *id == cur;
                        ListItem::new(Line::from(vec![
                            Span::styled(
                                if is_sel { " > " } else { "   " },
                                Style::default().fg(pri).add_modifier(Modifier::BOLD),
                            ),
                            Span::styled(
                                if is_act { "[SELECTED] " } else { "           " },
                                Style::default()
                                    .fg(Color::Green)
                                    .add_modifier(Modifier::BOLD),
                            ),
                            Span::styled(
                                format!("{id:<18} ({name})"),
                                Style::default()
                                    .fg(if is_sel { Color::Black } else { Color::White })
                                    .bg(if is_sel { pri } else { Color::Reset })
                                    .add_modifier(Modifier::BOLD),
                            ),
                        ]))
                    })
                    .collect();
                let list = List::new(items).block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(sec))
                        .title(
                            " INSTALLED WAYLAND / X11 SESSIONS (Enter=Select DE, l=Lock Now, i=Cycle Idle Mode) ",
                        ),
                );
                f.render_widget(list, rows[1]);

                let ftr = Paragraph::new(Line::from(vec![
                    Span::styled(
                        " KEYS ",
                        Style::default()
                            .fg(Color::Black)
                            .bg(sec)
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::raw(
                        " [Enter] Select DE  [n] Next DE  [l] Lock Workstation  [i] Cycle Idle Mode  [q] Quit | ",
                    ),
                    Span::styled(
                        &msg,
                        Style::default().fg(pri).add_modifier(Modifier::BOLD),
                    ),
                ]))
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(pri)),
                );
                f.render_widget(ftr, rows[2]);
            });

            if !event::poll(Duration::from_millis(250)).unwrap_or(false) {
                continue;
            }
            let Ok(Event::Key(key)) = event::read() else { continue };
            if key.kind != KeyEventKind::Press || self.sessions.is_empty() {
                continue;
            }
            let count = self.sessions.len();
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Down | KeyCode::Char('j') => sel = (sel + 1) % count,
                KeyCode::Up | KeyCode::Char('k') => sel = (sel + count - 1) % count,
                KeyCode::Enter => {
                    self.current = self.sessions[sel].0.clone();
                    (self.set_session)(&self.current);
                    play_sfx("confirm");
                    msg = format!("Selected DE session: {}", self.current);
                }
                KeyCode::Char('n') => {
                    sel = (sel + 1) % count;
                    self.current = self.sessions[sel].0.clone();
                    (self.set_session)(&self.current);
                    play_sfx("click");
                    msg = format!("Cycled DE session: {}", self.current);
                }
                KeyCode::Char('l') => {
                    let _ = disable_raw_mode();
                    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
                    (self.lock_now)();
                    return 0;
                }
                KeyCode::Char('i') => {
                    msg = format!("Idle mode: {}", (self.cycle_idle)("toggle"));
                }
                _ => {}
            }
        }
        let _ = disable_raw_mode();
        let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
        let _ = term.show_cursor();
        0
    }
}