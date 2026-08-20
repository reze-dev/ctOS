use crate::app::{
    App, GpuChoice, InstallMode, Page,
    StepStatus,
};
use ratatui::{
    layout::{Alignment, Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph, Wrap},
    Frame,
};

const CYAN: Color = Color::Rgb(0, 210, 255);
const BLUE: Color = Color::Rgb(90, 130, 255);
const GREEN: Color = Color::Rgb(115, 245, 160);
const RED: Color = Color::Rgb(255, 95, 135);
const YELLOW: Color = Color::Rgb(250, 218, 94);
const MAGENTA: Color = Color::Rgb(215, 115, 255);
const DIM: Color = Color::DarkGray;

pub fn draw(f: &mut Frame, app: &App) {
    let area = f.area();
    let chunks = Layout::vertical([
        Constraint::Length(3), // Header
        Constraint::Min(12),   // Content
        Constraint::Length(2), // Footer hints
    ])
    .split(area);

    draw_header(f, chunks[0], app);

    match app.page {
        Page::Welcome => draw_welcome(f, chunks[1]),
        Page::Hostname => draw_input(
            f,
            chunks[1],
            app,
            "1/10",
            "Host Configuration",
            "Enter system hostname (e.g. Makima, Northstar):",
        ),
        Page::Username => draw_input(
            f,
            chunks[1],
            app,
            "2/10",
            "User Configuration",
            "Enter primary username:",
        ),
        Page::Password => draw_input(
            f,
            chunks[1],
            app,
            "2/10",
            "User Password",
            "Enter user password (hidden):",
        ),
        Page::PasswordConfirm => draw_input(
            f,
            chunks[1],
            app,
            "2/10",
            "Confirm Password",
            "Confirm user password:",
        ),
        Page::Profile => draw_select(
            f,
            chunks[1],
            app,
            "3/10",
            "System Profile",
            "Select a system bundle preset:",
        ),
        Page::ProfileCustomize => draw_features_checklist(f, chunks[1], app),
        Page::Bootloader => draw_select(
            f,
            chunks[1],
            app,
            "4/10",
            "Bootloader Selection",
            "Choose default bootloader & theme:",
        ),
        Page::Mode => draw_select(
            f,
            chunks[1],
            app,
            "5/10",
            "Installation Mode",
            "Select installation layout mode:",
        ),
        Page::Disk => draw_disk_select(f, chunks[1], app),
        Page::DiskConfirm => {
            let warn = format!(
                "⚠ WARNING: All data on /dev/{} will be DESTROYED!\n\nType 'yes' to confirm partition wiping:",
                app.config.disk_dev
            );
            draw_input(f, chunks[1], app, "6/10", "Confirm Disk Destruction", &warn);
        }
        Page::PartSelect => draw_select(
            f,
            chunks[1],
            app,
            "6/10",
            "Partition Selection",
            "Select partition configuration method:",
        ),
        Page::PartNewStart => draw_input(
            f,
            chunks[1],
            app,
            "6/10",
            "Create Partition",
            "Enter partition start position (e.g., 100GB, 50%):",
        ),
        Page::PartNewEnd => draw_input(
            f,
            chunks[1],
            app,
            "6/10",
            "Create Partition",
            "Enter partition end position (e.g., 100%, 500GB):",
        ),
        Page::PartExist => draw_input(
            f,
            chunks[1],
            app,
            "6/10",
            "Existing Partition",
            "Enter existing partition name (e.g. nvme0n1p3, sda2):",
        ),
        Page::PartConfirm => draw_select(
            f,
            chunks[1],
            app,
            "6/10",
            "Confirm Partition",
            &format!("Format and install NixOS on {}?", app.config.nixos_part),
        ),
        Page::Efi => draw_efi_select(f, chunks[1], app),
        Page::Fs => draw_select(
            f,
            chunks[1],
            app,
            "7/10",
            "Filesystem Type",
            "Select root filesystem type:",
        ),
        Page::RootSize => draw_input(
            f,
            chunks[1],
            app,
            "7/10",
            "Root Partition Size",
            "Enter root partition size (default: 100%):",
        ),
        Page::Swap => draw_input(
            f,
            chunks[1],
            app,
            "7/10",
            "Swap Space Configuration",
            "Enter swap size (e.g. 8G, 16G, or 0 to disable):",
        ),
        Page::SwapPartition => draw_input(
            f,
            chunks[1],
            app,
            "7/10",
            "Dedicated Swap Partition",
            "Enter dedicated swap partition device (e.g., /dev/nvme0n1p4):",
        ),
        Page::Gpu => draw_select(
            f,
            chunks[1],
            app,
            "8/10",
            "GPU Graphics Driver",
            "Select GPU driver configuration:",
        ),
        Page::GpuNvBus => draw_input(
            f,
            chunks[1],
            app,
            "8/10",
            "NVIDIA PCI Bus ID",
            "Enter NVIDIA Bus ID (e.g. PCI:1:0:0):",
        ),
        Page::GpuIgpuType => draw_select(
            f,
            chunks[1],
            app,
            "8/10",
            "Integrated GPU Vendor",
            "Select integrated GPU vendor (Intel / AMD):",
        ),
        Page::GpuIgpuBus => draw_input(
            f,
            chunks[1],
            app,
            "8/10",
            "Integrated GPU Bus ID",
            "Enter iGPU Bus ID (e.g. PCI:0:2:0 or PCI:5:0:0):",
        ),
        Page::DualBoot => draw_dual_boot_select(f, chunks[1], app),
        Page::Summary => draw_summary(f, chunks[1], app),
        Page::Installing => draw_installing(f, chunks[1], app),
        Page::Done => draw_done(f, chunks[1]),
    }

    draw_footer(f, chunks[2], app);
}

fn draw_header(f: &mut Frame, area: Rect, app: &App) {
    let title = Span::styled(
        " ❄ NORTHSTAR NIXOS INSTALLER ",
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    );

    let step_label = match app.page {
        Page::Welcome => "Welcome",
        Page::Hostname | Page::Username | Page::Password | Page::PasswordConfirm => "Identity & Auth",
        Page::Profile | Page::ProfileCustomize => "Profiles & Features",
        Page::Bootloader => "Bootloader",
        Page::Mode | Page::Disk | Page::DiskConfirm | Page::PartSelect | Page::PartNewStart | Page::PartNewEnd | Page::PartExist | Page::PartConfirm | Page::Efi => "Storage & Disko",
        Page::Fs | Page::RootSize | Page::Swap | Page::SwapPartition => "Filesystem & Swap",
        Page::Gpu | Page::GpuNvBus | Page::GpuIgpuType | Page::GpuIgpuBus => "Hardware & GPU",
        Page::DualBoot => "Dual-Boot Config",
        Page::Summary => "Review & Confirm",
        Page::Installing => "Installing System",
        Page::Done => "Complete",
    };

    let step_span = Span::styled(
        format!(" [ {step_label} ] "),
        Style::default().fg(BLUE).add_modifier(Modifier::BOLD),
    );

    let header_line = Line::from(vec![title, Span::raw("──"), step_span]);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(BLUE));

    f.render_widget(Paragraph::new(header_line).block(block), area);
}

fn draw_footer(f: &mut Frame, area: Rect, app: &App) {
    let hints = match app.page {
        Page::Welcome => " [Enter] Start Wizard    [q / Ctrl+C] Quit",
        Page::ProfileCustomize | Page::DualBoot => " [Space] Toggle Checkbox    [↑/↓/j/k] Navigate    [Enter] Next    [Esc] Back",
        Page::Summary => " [Enter / y] Start Installation    [Esc / n] Edit Settings    [Ctrl+C] Quit",
        Page::Installing => " Please wait while NixOS packages are being downloaded and compiled...",
        Page::Done => " [Enter / q] Exit Installer & Reboot",
        _ => " [Enter] Confirm & Next    [↑/↓/j/k] Navigate    [Esc] Previous Step    [Ctrl+C] Quit",
    };

    let text = Span::styled(hints, Style::default().fg(DIM));
    f.render_widget(Paragraph::new(text).alignment(Alignment::Center), area);
}

fn draw_welcome(f: &mut Frame, area: Rect) {
    let banner = r#"
    ███╗   ██╗ ██████╗ ██████╗ ████████╗██╗  ██╗███████╗████████╗ █████╗ ██████╗ 
    ████╗  ██║██╔═══██╗██╔══██╗╚══██╔══╝██║  ██║██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
    ██╔██╗ ██║██║   ██║██████╔╝   ██║   ███████║███████╗   ██║   ███████║██████╔╝
    ██║╚██╗██║██║   ██║██╔══██╗   ██║   ██╔══██║╚════██║   ██║   ██╔══██║██╔══██╗
    ██║ ╚████║╚██████╔╝██║  ██║   ██║   ██║  ██║███████║   ██║   ██║  ██║██║  ██║
    ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
    "#;

    let lines = vec![
        Line::from(Span::styled(banner, Style::default().fg(CYAN))),
        Line::from(""),
        Line::from(Span::styled(
            "  Welcome to the Northstar NixOS installation wizard.",
            Style::default().fg(Color::White).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(Span::styled("  • Modular option-driven NixOS & Home Manager configuration", Style::default().fg(BLUE))),
        Line::from(Span::styled("  • Automated hardware & GPU Prime detection (NVIDIA + Intel/AMD)", Style::default().fg(BLUE))),
        Line::from(Span::styled("  • Limine and GRUB (DedSec theme) dual-boot chainloading support", Style::default().fg(BLUE))),
        Line::from(Span::styled("  • Declarative Btrfs subvolumes & Disko partitioning engine", Style::default().fg(BLUE))),
        Line::from(""),
        Line::from(Span::styled("  Press [Enter] to begin system configuration", Style::default().fg(GREEN).add_modifier(Modifier::BOLD))),
    ];

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_input(f: &mut Frame, area: Rect, app: &App, step: &str, title: &str, label: &str) {
    let chunks = Layout::vertical([
        Constraint::Length(3),
        Constraint::Length(3),
        Constraint::Min(2),
    ])
    .split(area);

    let title_line = Line::from(vec![
        Span::styled(format!("  [Step {step}] "), Style::default().fg(BLUE).add_modifier(Modifier::BOLD)),
        Span::styled(title, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
    ]);
    let label_line = Line::from(Span::styled(format!("  {label}"), Style::default().fg(Color::White)));

    f.render_widget(Paragraph::new(vec![title_line, Line::from(""), label_line]), chunks[0]);

    let is_pw = app.page == Page::Password || app.page == Page::PasswordConfirm;
    let display = if is_pw {
        "•".repeat(app.input.len())
    } else {
        app.input.clone()
    };

    let input_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(if !app.err.is_empty() { RED } else { BLUE }))
        .title(Span::styled(" Value ", Style::default().fg(CYAN)));

    f.render_widget(Paragraph::new(format!("  {display}")).block(input_block), chunks[1]);

    if !app.err.is_empty() {
        let err_text = Line::from(Span::styled(format!("  ⚠ {}", app.err), Style::default().fg(RED).add_modifier(Modifier::BOLD)));
        f.render_widget(Paragraph::new(err_text), chunks[2]);
    }

    f.set_cursor_position((chunks[1].x + 2 + app.cursor_pos as u16, chunks[1].y + 1));
}

fn draw_select(f: &mut Frame, area: Rect, app: &App, step: &str, title: &str, label: &str) {
    let mut lines = vec![
        Line::from(vec![
            Span::styled(format!("  [Step {step}] "), Style::default().fg(BLUE).add_modifier(Modifier::BOLD)),
            Span::styled(title, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(""),
        Line::from(Span::styled(format!("  {label}"), Style::default().fg(Color::White))),
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

    if !app.err.is_empty() {
        lines.push(Line::from(""));
        lines.push(Line::from(Span::styled(format!("  ⚠ {}", app.err), Style::default().fg(RED))));
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_features_checklist(f: &mut Frame, area: Rect, app: &App) {
    let mut lines = vec![
        Line::from(vec![
            Span::styled("  [Step 3/10] ", Style::default().fg(BLUE).add_modifier(Modifier::BOLD)),
            Span::styled("Customize Features & Compositors", Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(""),
        Line::from(Span::styled("  Toggle features using [Space]. Press [Enter] to continue.", Style::default().fg(DIM))),
        Line::from(""),
    ];

    let mut current_cat = "";
    for (i, feat) in app.config.features.iter().enumerate() {
        if feat.category != current_cat {
            current_cat = &feat.category;
            lines.push(Line::from(Span::styled(
                format!("  --- {current_cat} ---"),
                Style::default().fg(YELLOW).add_modifier(Modifier::BOLD),
            )));
        }

        let check = if feat.enabled { "[x]" } else { "[ ]" };
        let check_style = if feat.enabled {
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(DIM)
        };

        if i == app.cursor {
            lines.push(Line::from(vec![
                Span::styled("  › ", Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
                Span::styled(format!("{check} "), check_style),
                Span::styled(&feat.label, Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            ]));
        } else {
            lines.push(Line::from(vec![
                Span::raw("    "),
                Span::styled(format!("{check} "), check_style),
                Span::styled(&feat.label, Style::default().fg(Color::White)),
            ]));
        }
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_disk_select(f: &mut Frame, area: Rect, app: &App) {
    let chunks = Layout::vertical([
        Constraint::Length(3),
        Constraint::Min(8),
        Constraint::Length(5), // Disk visualizer bar
    ])
    .split(area);

    let title_line = Line::from(vec![
        Span::styled("  [Step 6/10] ", Style::default().fg(BLUE).add_modifier(Modifier::BOLD)),
        Span::styled("Target Disk Selection", Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
    ]);
    f.render_widget(Paragraph::new(title_line), chunks[0]);

    if !app.detected_disks.is_empty() {
        let mut lines = vec![Line::from(Span::styled("  Select a disk device:", Style::default().fg(Color::White))), Line::from("")];
        for (i, d) in app.detected_disks.iter().enumerate() {
            let label = format!("{}  ({} • {} • {})", d.name, d.size, d.drive_type, d.model);
            if i == app.cursor {
                lines.push(Line::from(Span::styled(format!("  › {label}"), Style::default().fg(CYAN).add_modifier(Modifier::BOLD))));
            } else {
                lines.push(Line::from(Span::styled(format!("    {label}"), Style::default().fg(Color::White))));
            }
        }
        let block = Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(CYAN));
        f.render_widget(Paragraph::new(lines).block(block), chunks[1]);

        // Render visual partition bar for currently highlighted disk
        if let Some(disk) = app.detected_disks.get(app.cursor) {
            draw_disk_visualizer(f, chunks[2], disk);
        }
    } else {
        draw_input(f, chunks[1], app, "6/10", "Target Disk", "Enter disk device name (e.g. nvme0n1, sda):");
    }
}

fn draw_disk_visualizer(f: &mut Frame, area: Rect, disk: &crate::app::DiskInfo) {
    let mut part_spans = Vec::new();
    part_spans.push(Span::styled(format!(" /dev/{} [{}]: ", disk.name, disk.size), Style::default().fg(YELLOW).add_modifier(Modifier::BOLD)));

    if disk.partitions.is_empty() {
        part_spans.push(Span::styled("[ Unpartitioned Space ]", Style::default().fg(DIM)));
    } else {
        for (idx, part) in disk.partitions.iter().enumerate() {
            let color = match idx % 4 {
                0 => CYAN,
                1 => GREEN,
                2 => MAGENTA,
                _ => BLUE,
            };
            let fs_label = if part.fs_type.is_empty() { "raw" } else { &part.fs_type };
            part_spans.push(Span::styled(
                format!("[ {} ({}, {}) ] ", part.name, part.size, fs_label),
                Style::default().fg(color).add_modifier(Modifier::BOLD),
            ));
        }
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(YELLOW))
        .title(Span::styled(" Disk Layout Visualizer ", Style::default().fg(YELLOW)));

    f.render_widget(Paragraph::new(Line::from(part_spans)).block(block), area);
}

fn draw_efi_select(f: &mut Frame, area: Rect, app: &App) {
    if !app.detected_efis.is_empty() {
        draw_select(
            f,
            area,
            app,
            "6/10",
            "EFI System Partition (ESP)",
            "Select existing EFI system partition:",
        );
    } else {
        draw_input(
            f,
            area,
            app,
            "6/10",
            "EFI System Partition (ESP)",
            "Enter EFI partition device (e.g. /dev/nvme0n1p1):",
        );
    }
}

fn draw_dual_boot_select(f: &mut Frame, area: Rect, app: &App) {
    let mut lines = vec![
        Line::from(vec![
            Span::styled("  [Step 9/10] ", Style::default().fg(BLUE).add_modifier(Modifier::BOLD)),
            Span::styled("Detected Dual-Boot Operating Systems", Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(""),
        Line::from(Span::styled(
            "  The following operating systems were detected on your EFI partition.",
            Style::default().fg(Color::White),
        )),
        Line::from(Span::styled(
            "  Use [Space] to toggle whether to add bootloader chainloader entries for each OS:",
            Style::default().fg(DIM),
        )),
        Line::from(""),
    ];

    for (i, entry) in app.config.dual_boot_entries.iter().enumerate() {
        let check = if entry.enabled { "[x]" } else { "[ ]" };
        let check_style = if entry.enabled {
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(DIM)
        };

        if i == app.cursor {
            lines.push(Line::from(vec![
                Span::styled("  › ", Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
                Span::styled(format!("{check} "), check_style),
                Span::styled(
                    format!("{} ({})", entry.name, entry.efi_path),
                    Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
                ),
            ]));
        } else {
            lines.push(Line::from(vec![
                Span::raw("    "),
                Span::styled(format!("{check} "), check_style),
                Span::styled(
                    format!("{} ({})", entry.name, entry.efi_path),
                    Style::default().fg(Color::White),
                ),
            ]));
        }
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_summary(f: &mut Frame, area: Rect, app: &App) {
    let cfg = &app.config;
    let gpu_label = match cfg.gpu_choice {
        GpuChoice::Nvidia => "NVIDIA Discrete".to_string(),
        GpuChoice::NvidiaPrime => format!(
            "NVIDIA Prime (NV: {}, iGPU {}: {})",
            cfg.nvidia_bus_id, cfg.igpu_type, cfg.igpu_bus_id
        ),
        GpuChoice::None => "Default / Mesa".to_string(),
    };

    let mut lines = vec![
        Line::from(vec![
            Span::styled("  [Step 10/10] ", Style::default().fg(BLUE).add_modifier(Modifier::BOLD)),
            Span::styled("Review System Configuration", Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(""),
    ];

    let swap_label = if !cfg.swap_partition.is_empty() {
        format!("{} (partition: {})", cfg.swap_size, cfg.swap_partition)
    } else if cfg.mode == InstallMode::PartitionOnly && cfg.fs_type == "btrfs" && cfg.swap_size != "0" {
        format!("{} (btrfs subvolume swapfile)", cfg.swap_size)
    } else {
        cfg.swap_size.clone()
    };

    let rows: Vec<(&str, String)> = vec![
        ("Hostname", cfg.hostname.clone()),
        ("Username", cfg.username.clone()),
        ("Profile", cfg.profile.to_string()),
        ("Bootloader", cfg.bootloader.to_string()),
        ("Mode", cfg.mode.to_string()),
        ("Disk", cfg.disk_dev.clone()),
        ("Filesystem", cfg.fs_type.clone()),
        ("Swap", swap_label),
        ("GPU Driver", gpu_label),
    ];

    for (k, v) in &rows {
        lines.push(Line::from(vec![
            Span::styled(format!("  {k:<16}: "), Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            Span::styled(v, Style::default().fg(Color::White)),
        ]));
    }

    if cfg.mode == InstallMode::PartitionOnly {
        lines.push(Line::from(vec![
            Span::styled("  NixOS Partition : ".to_string(), Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            Span::styled(&cfg.nixos_part, Style::default().fg(Color::White)),
        ]));
        lines.push(Line::from(vec![
            Span::styled("  EFI Partition   : ".to_string(), Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            Span::styled(&cfg.efi_part, Style::default().fg(Color::White)),
        ]));
    }

    let dual_boot_count = cfg.dual_boot_entries.iter().filter(|e| e.enabled).count();
    if dual_boot_count > 0 {
        lines.push(Line::from(vec![
            Span::styled("  Dual-Boot OS    : ".to_string(), Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            Span::styled(format!("{dual_boot_count} OS entry/entries configured"), Style::default().fg(GREEN)),
        ]));
    }

    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled("  ⚠ Review carefully: Disko will partition and format the selected disk.", Style::default().fg(YELLOW).add_modifier(Modifier::BOLD))));
    lines.push(Line::from(Span::styled("  Press [Enter] or [y] to start installation, [Esc] to go back.", Style::default().fg(GREEN).add_modifier(Modifier::BOLD))));

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(CYAN));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

fn draw_installing(f: &mut Frame, area: Rect, app: &App) {
    let chunks = Layout::horizontal([
        Constraint::Percentage(45), // Step checklist
        Constraint::Percentage(55), // Live logs
    ])
    .split(area);

    // Left pane: Step status
    let mut step_lines = vec![
        Line::from(Span::styled(
            "  Installing NixOS...",
            Style::default().fg(BLUE).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];

    for step in &app.install_steps {
        let (icon, style) = match step.status {
            StepStatus::Pending => ("○", Style::default().fg(DIM)),
            StepStatus::Running => (app.spinner_char(), Style::default().fg(CYAN).add_modifier(Modifier::BOLD)),
            StepStatus::Done => ("✓", Style::default().fg(GREEN).add_modifier(Modifier::BOLD)),
            StepStatus::Error => ("✗", Style::default().fg(RED).add_modifier(Modifier::BOLD)),
        };
        step_lines.push(Line::from(vec![
            Span::styled(format!("  {icon}  "), style),
            Span::styled(&step.label, if step.status == StepStatus::Running { Style::default().fg(Color::White).add_modifier(Modifier::BOLD) } else { Style::default().fg(Color::White) }),
        ]));
    }

    if let Some(ref e) = app.install_err {
        step_lines.push(Line::from(""));
        step_lines.push(Line::from(Span::styled(format!("  Error: {e}"), Style::default().fg(RED))));
    }

    let left_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(BLUE))
        .title(Span::styled(" Installation Progress ", Style::default().fg(BLUE)));
    f.render_widget(Paragraph::new(step_lines).block(left_block), chunks[0]);

    // Right pane: Live scrolling terminal output
    let mut log_spans = Vec::new();
    for line in &app.log_lines {
        log_spans.push(Line::from(Span::styled(line, Style::default().fg(CYAN))));
    }
    if log_spans.is_empty() {
        log_spans.push(Line::from(Span::styled("  Live build output will appear here...", Style::default().fg(DIM))));
    }

    let right_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(CYAN))
        .title(Span::styled(" Live Build Logs ", Style::default().fg(CYAN)));

    f.render_widget(
        Paragraph::new(log_spans)
            .block(right_block)
            .wrap(Wrap { trim: false }),
        chunks[1],
    );
}

fn draw_done(f: &mut Frame, area: Rect) {
    let lines = vec![
        Line::from(""),
        Line::from(Span::styled(
            "  🎉 Installation Finished Successfully!",
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "  Northstar NixOS has been deployed to your system.",
            Style::default().fg(Color::White),
        )),
        Line::from(Span::styled(
            "  Your configuration flake has been cloned into ~/northstar.",
            Style::default().fg(Color::White),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "  Press [Enter] or [q] to exit the installer.",
            Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
        )),
    ];

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(GREEN))
        .title(Span::styled(" Success ", Style::default().fg(GREEN)));
    f.render_widget(Paragraph::new(lines).block(block), area);
}
