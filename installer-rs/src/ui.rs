use crate::app::{App, InputMode, Page, StepStatus};
use ratatui::{
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, Paragraph, Wrap},
    Frame,
};

const CYAN: Color = Color::Rgb(0, 191, 255);
const BLUE: Color = Color::Rgb(91, 127, 255);
const GREEN: Color = Color::Rgb(115, 245, 159);
const RED: Color = Color::Rgb(255, 95, 135);
const YELLOW: Color = Color::Rgb(250, 218, 94);
const DIM: Color = Color::DarkGray;

pub fn draw(f: &mut Frame, app: &App) {
    let area = f.area();
    let chunks = Layout::vertical([
        Constraint::Length(3), // header
        Constraint::Min(10),   // content
    ])
    .split(area);

    draw_header(f, chunks[0]);

    match app.page {
        Page::Welcome => draw_welcome(f, chunks[1]),
        Page::Hostname => draw_input(
            f,
            chunks[1],
            app,
            "1/8",
            "Host Configuration",
            "Enter hostname:",
        ),
        Page::Username => draw_input(
            f,
            chunks[1],
            app,
            "2/8",
            "User Configuration",
            "Enter username:",
        ),
        Page::Password => draw_input(
            f,
            chunks[1],
            app,
            "2/8",
            "User Configuration",
            "Enter password:",
        ),
        Page::PasswordConfirm => draw_input(
            f,
            chunks[1],
            app,
            "2/8",
            "User Configuration",
            "Confirm password:",
        ),
        Page::Mode => draw_select(
            f,
            chunks[1],
            app,
            "3/8",
            "Installation Mode",
            "Select installation mode:",
        ),
        Page::Disk => draw_input(
            f,
            chunks[1],
            app,
            "4/8",
            "Disk Selection",
            "Enter target disk device:",
        ),
        Page::DiskConfirm => {
            let warn = format!(
                "⚠ WARNING: All data on /dev/{} will be DESTROYED!\n\nType 'yes' to confirm:",
                app.config.disk_dev
            );
            draw_input(f, chunks[1], app, "4/8", "Confirm", &warn);
        }
        Page::PartSelect => draw_select(
            f,
            chunks[1],
            app,
            "4/8",
            "Partition Selection",
            "What would you like to do?",
        ),
        Page::PartNewStart => draw_input(
            f,
            chunks[1],
            app,
            "4/8",
            "Create Partition",
            "Enter start position:",
        ),
        Page::PartNewEnd => draw_input(
            f,
            chunks[1],
            app,
            "4/8",
            "Create Partition",
            "Enter end position:",
        ),
        Page::PartExist => draw_input(
            f,
            chunks[1],
            app,
            "4/8",
            "Select Partition",
            "Enter NixOS partition device:",
        ),
        Page::PartConfirm => {
            let warn = format!(
                "⚠ WARNING: All data on {} will be DESTROYED!\n\nType 'yes' to confirm:",
                app.config.nixos_part
            );
            draw_input(f, chunks[1], app, "4/8", "Confirm", &warn);
        }
        Page::Efi => draw_input(
            f,
            chunks[1],
            app,
            "4/8",
            "EFI Partition",
            "EFI System Partition:",
        ),
        Page::Swap => draw_input(
            f,
            chunks[1],
            app,
            "5/8",
            "Swap Configuration",
            "Enter swap size (e.g., 8G, 16G, 0 to disable):",
        ),
        Page::Fs => draw_select(
            f,
            chunks[1],
            app,
            "6/8",
            "Filesystem",
            "Select root filesystem:",
        ),
        Page::Gpu => draw_select(
            f,
            chunks[1],
            app,
            "7/8",
            "GPU Configuration",
            "Select GPU type:",
        ),
        Page::GpuNvBus => draw_input(
            f,
            chunks[1],
            app,
            "7/8",
            "NVIDIA Configuration",
            "NVIDIA Bus ID:",
        ),
        Page::GpuIgpuType => draw_select(
            f,
            chunks[1],
            app,
            "7/8",
            "NVIDIA Prime",
            "Select iGPU type:",
        ),
        Page::GpuIgpuBus => draw_input(f, chunks[1], app, "7/8", "NVIDIA Prime", "iGPU Bus ID:"),
        Page::Summary => draw_summary(f, chunks[1], app),
        Page::Installing => draw_installing(f, chunks[1], app),
        Page::Done => draw_done(f, chunks[1], app),
    }
}

fn draw_header(f: &mut Frame, area: Rect) {
    let header = Paragraph::new(Line::from(vec![Span::styled(
        "  ❄️  Cryonix NixOS Installer  ❄️",
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    )]))
    .block(
        Block::default()
            .borders(Borders::BOTTOM)
            .border_style(Style::default().fg(CYAN)),
    );
    f.render_widget(header, area);
}

fn draw_welcome(f: &mut Frame, area: Rect) {
    let art = vec![
        Line::from(Span::styled("", Style::default())),
        Line::from(Span::styled(
            "       *    .  ❄  .    *",
            Style::default().fg(CYAN),
        )),
        Line::from(Span::styled(
            "     .    ❄    *    ❄    .",
            Style::default().fg(CYAN),
        )),
        Line::from(Span::styled(
            "       .    *  .  *    .",
            Style::default().fg(CYAN),
        )),
        Line::from(Span::styled(
            "           ❄  .  ❄",
            Style::default().fg(CYAN),
        )),
        Line::from(Span::styled("             *", Style::default().fg(CYAN))),
        Line::from(""),
        Line::from(Span::styled(
            "  Welcome to the Cryonix NixOS Installer",
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "  This wizard will guide you through setting up",
            Style::default().fg(DIM),
        )),
        Line::from(Span::styled(
            "  a fresh NixOS system with your configuration.",
            Style::default().fg(DIM),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "  Press Enter to begin...",
            Style::default().fg(DIM),
        )),
    ];
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(CYAN))
        .title(Span::styled(" Welcome ", Style::default().fg(CYAN)));
    f.render_widget(Paragraph::new(art).block(block), area);
}

fn draw_input(f: &mut Frame, area: Rect, app: &App, step: &str, title: &str, label: &str) {
    let chunks = Layout::vertical([Constraint::Min(6), Constraint::Length(3)]).split(area);

    let mut lines = vec![
        Line::from(Span::styled(
            format!("  [Step {step}] {title}"),
            Style::default().fg(BLUE).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];

    if !app.cmd_output.is_empty() {
        for l in app.cmd_output.lines() {
            lines.push(Line::from(Span::styled(
                format!("  {l}"),
                Style::default().fg(DIM),
            )));
        }
        lines.push(Line::from(""));
    }

    lines.push(Line::from(Span::styled(
        format!("  {label}"),
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::BOLD),
    )));

    if !app.err.is_empty() {
        lines.push(Line::from(""));
        lines.push(Line::from(Span::styled(
            format!("  ✗ {}", app.err),
            Style::default().fg(RED).add_modifier(Modifier::BOLD),
        )));
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), chunks[0]);

    // Input field
    let display = if app.input_mode == InputMode::Password {
        "•".repeat(app.input.len())
    } else {
        app.input.clone()
    };
    let input_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(BLUE))
        .title(Span::styled(
            " enter: next • esc: back ",
            Style::default().fg(DIM),
        ));
    f.render_widget(
        Paragraph::new(format!("  {display}")).block(input_block),
        chunks[1],
    );

    // Cursor
    f.set_cursor_position((chunks[1].x + 2 + app.cursor_pos as u16, chunks[1].y + 1));
}

fn draw_select(f: &mut Frame, area: Rect, app: &App, step: &str, title: &str, label: &str) {
    let mut lines = vec![
        Line::from(Span::styled(
            format!("  [Step {step}] {title}"),
            Style::default().fg(BLUE).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(Span::styled(
            format!("  {label}"),
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];

    for (i, choice) in app.choices.iter().enumerate() {
        if i == app.cursor {
            lines.push(Line::from(Span::styled(
                format!("  › {choice}"),
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            )));
        } else {
            lines.push(Line::from(Span::styled(
                format!("    {choice}"),
                Style::default().fg(Color::White),
            )));
        }
    }

    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "  ↑/↓: navigate  •  enter: select  •  esc: back",
        Style::default().fg(DIM),
    )));

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_summary(f: &mut Frame, area: Rect, app: &App) {
    let cfg = &app.config;
    let gpu_label = match cfg.gpu_choice.as_str() {
        "2" => "NVIDIA".to_string(),
        "3" => format!(
            "NVIDIA Prime ({} + {}:{})",
            cfg.nvidia_bus_id, cfg.igpu_type, cfg.igpu_bus_id
        ),
        _ => "Default (no NVIDIA)".to_string(),
    };

    let mut lines = vec![
        Line::from(Span::styled(
            "  [Step 8/8] Review Configuration",
            Style::default().fg(BLUE).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];

    let rows = vec![
        ("Hostname", &cfg.hostname),
        ("Username", &cfg.username),
        ("Mode", &cfg.mode),
        ("Disk", &cfg.disk_dev),
        ("Swap", &cfg.swap_size),
    ];
    for (k, v) in &rows {
        lines.push(Line::from(vec![
            Span::styled(
                format!("  {k:<16}"),
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(v.to_string()),
        ]));
    }
    if cfg.mode == "partition-only" {
        lines.push(Line::from(vec![
            Span::styled(
                "  NixOS Part    ".to_string(),
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(&cfg.nixos_part),
        ]));
        lines.push(Line::from(vec![
            Span::styled(
                "  EFI Part      ".to_string(),
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(&cfg.efi_part),
        ]));
    }
    if cfg.mode == "whole-disk" {
        lines.push(Line::from(vec![
            Span::styled(
                "  Filesystem    ".to_string(),
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(&cfg.fs_type),
        ]));
    }
    lines.push(Line::from(vec![
        Span::styled(
            "  GPU           ".to_string(),
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(gpu_label),
    ]));

    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "  ⚠ This will modify your disk. Make sure the config is correct.",
        Style::default().fg(YELLOW),
    )));
    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "  enter/y: install  •  esc/n: start over  •  ctrl+c: quit",
        Style::default().fg(DIM),
    )));

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_installing(f: &mut Frame, area: Rect, app: &App) {
    let chunks = Layout::vertical([
        Constraint::Min(8),
        Constraint::Length(3),
        Constraint::Length(6),
    ])
    .split(area);

    // Steps checklist
    let mut lines = vec![
        Line::from(Span::styled(
            "  Installing NixOS...",
            Style::default().fg(BLUE).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];

    for step in &app.install_steps {
        let (icon, style) = match step.status {
            StepStatus::Pending => ("○", Style::default().fg(DIM)),
            StepStatus::Running => (app.spinner_char(), Style::default().fg(CYAN)),
            StepStatus::Done => ("✓", Style::default().fg(GREEN)),
            StepStatus::Error => ("✗", Style::default().fg(RED)),
        };
        lines.push(Line::from(Span::styled(
            format!("  {icon}  {}", step.label),
            style,
        )));
    }

    if let Some(ref e) = app.install_err {
        lines.push(Line::from(""));
        lines.push(Line::from(Span::styled(
            format!("  ✗ Error: {e}"),
            Style::default().fg(RED).add_modifier(Modifier::BOLD),
        )));
        lines.push(Line::from(Span::styled(
            "  ctrl+c to exit",
            Style::default().fg(DIM),
        )));
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), chunks[0]);

    // Progress gauge
    let gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(BLUE)),
        )
        .gauge_style(Style::default().fg(CYAN))
        .ratio(app.install_progress_fraction())
        .label(format!(
            "{}%",
            (app.install_progress_fraction() * 100.0) as u16
        ));
    f.render_widget(gauge, chunks[1]);

    // Log
    let log_lines: Vec<Line> = app
        .log_lines
        .iter()
        .map(|l| Line::from(Span::styled(format!("  > {l}"), Style::default().fg(DIM))))
        .collect();
    let log_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(DIM))
        .title(Span::styled(" Log ", Style::default().fg(DIM)));
    f.render_widget(
        Paragraph::new(log_lines)
            .block(log_block)
            .wrap(Wrap { trim: true }),
        chunks[2],
    );
}

fn draw_done(f: &mut Frame, area: Rect, app: &App) {
    let lines = vec![
        Line::from(""),
        Line::from(Span::styled(
            "  ✅ Installation Complete!",
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(format!(
            "  Configuration saved to: /home/{}/cryonix",
            app.config.username
        )),
        Line::from("  You can now reboot into your new Cryonix system."),
        Line::from(""),
        Line::from(Span::styled(
            "  After reboot:",
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(Span::styled(
            format!(
                "    cd ~/cryonix && sudo nixos-rebuild switch --flake .#{}",
                app.config.hostname
            ),
            Style::default().fg(CYAN),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "  Press enter or q to exit",
            Style::default().fg(DIM),
        )),
    ];
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(GREEN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}
