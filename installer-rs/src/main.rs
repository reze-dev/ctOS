mod app;
mod backend;
mod cmd;
mod flake;
mod state;
mod ui;

use app::{App, Page};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::prelude::*;
use std::io::stdout;
use std::time::Duration;
use tokio::sync::mpsc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Root check
    if nix::unistd::geteuid().as_raw() != 0 {
        eprintln!("\x1b[0;31mPlease run as root\x1b[0m");
        std::process::exit(1);
    }

    // Extract embedded flake
    let work_dir = flake::extract_flake().map_err(|e| -> Box<dyn std::error::Error> {
        eprintln!("Failed to extract flake: {e}");
        e.into()
    })?;

    std::env::set_current_dir(&work_dir)?;

    let mut app = App::new(work_dir.clone());

    // Terminal setup
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    // Main event loop
    let result = run_app(&mut terminal, &mut app).await;

    // Cleanup
    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;

    if let Err(ref e) = result {
        eprintln!("Error: {e}");
    }

    // Clean up work dir
    let _ = std::fs::remove_dir_all(&work_dir);

    result
}

async fn run_app(
    terminal: &mut Terminal<CrosstermBackend<std::io::Stdout>>,
    app: &mut App,
) -> Result<(), Box<dyn std::error::Error>> {
    loop {
        terminal.draw(|f| ui::draw(f, app))?;

        // Poll for progress updates (non-blocking)
        if app.page == Page::Installing {
            let mut updates = Vec::new();
            if let Some(ref mut rx) = app.progress_rx {
                while let Ok(update) = rx.try_recv() {
                    updates.push(update);
                }
            }
            for update in updates {
                app.handle_progress(update);
            }
            app.tick_spinner();
        }

        // Poll for keyboard events with a timeout (allows spinner to animate)
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue;
                }

                // Global quit
                if key.code == KeyCode::Char('c')
                    && key.modifiers.contains(event::KeyModifiers::CONTROL)
                {
                    app.should_quit = true;
                }

                if app.should_quit {
                    return Ok(());
                }

                handle_key(app, key.code).await;
            }
        }

        if app.should_quit {
            return Ok(());
        }
    }
}

async fn handle_key(app: &mut App, key: KeyCode) {
    match app.page {
        Page::Welcome => {
            if key == KeyCode::Enter {
                app.go_to_page(Page::Hostname);
            }
        }

        // Text input pages
        Page::Hostname
        | Page::Username
        | Page::Disk
        | Page::PartNewStart
        | Page::PartNewEnd
        | Page::PartExist
        | Page::Swap
        | Page::GpuNvBus
        | Page::GpuIgpuBus => match key {
            KeyCode::Enter => handle_text_submit(app).await,
            KeyCode::Char(c) => app.type_char(c),
            KeyCode::Backspace => app.delete_char(),
            KeyCode::Esc => {
                let p = app.prev_page();
                app.go_to_page(p);
            }
            _ => {}
        },

        // Password pages
        Page::Password | Page::PasswordConfirm => match key {
            KeyCode::Enter => handle_password_submit(app).await,
            KeyCode::Char(c) => app.type_char(c),
            KeyCode::Backspace => app.delete_char(),
            KeyCode::Esc => {
                let p = if app.page == Page::PasswordConfirm {
                    Page::Password
                } else {
                    Page::Username
                };
                app.go_to_page(p);
            }
            _ => {}
        },

        // Confirm pages
        Page::DiskConfirm | Page::PartConfirm => match key {
            KeyCode::Enter => handle_confirm_submit(app),
            KeyCode::Char(c) => app.type_char(c),
            KeyCode::Backspace => app.delete_char(),
            KeyCode::Esc => app.go_to_page(Page::Disk),
            _ => {}
        },

        // EFI page
        Page::Efi => match key {
            KeyCode::Enter => {
                if !app.config.efi_part.is_empty() {
                    app.go_to_page(Page::Swap);
                } else {
                    let val = app.input_value();
                    if val.is_empty() {
                        app.err = "EFI partition cannot be empty".into();
                    } else {
                        app.config.efi_part = format!("/dev/{val}");
                        app.go_to_page(Page::Swap);
                    }
                }
            }
            KeyCode::Char(c) => app.type_char(c),
            KeyCode::Backspace => app.delete_char(),
            KeyCode::Esc => {
                let p = app.prev_page();
                app.go_to_page(p);
            }
            _ => {}
        },

        // Selection pages
        Page::Mode | Page::PartSelect | Page::Fs | Page::Gpu | Page::GpuIgpuType => match key {
            KeyCode::Up | KeyCode::Char('k') => {
                if app.cursor > 0 {
                    app.cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if app.cursor < app.choices.len().saturating_sub(1) {
                    app.cursor += 1;
                }
            }
            KeyCode::Enter => handle_selection(app),
            KeyCode::Esc => {
                let p = app.prev_page();
                app.go_to_page(p);
            }
            _ => {}
        },

        Page::Summary => match key {
            KeyCode::Enter | KeyCode::Char('y') | KeyCode::Char('Y') => {
                start_installation(app).await;
            }
            KeyCode::Esc | KeyCode::Char('n') | KeyCode::Char('N') => {
                app.go_to_page(Page::Hostname);
            }
            _ => {}
        },

        Page::Done => {
            if key == KeyCode::Enter || key == KeyCode::Char('q') {
                app.should_quit = true;
            }
        }

        Page::Installing => {} // No input during installation
    }
}

async fn handle_text_submit(app: &mut App) {
    let val = app.input_value();

    match app.page {
        Page::Hostname => {
            if val.is_empty() {
                app.err = "Hostname cannot be empty".into();
                return;
            }
            app.config.hostname = val;
            app.go_to_page(Page::Username);
        }
        Page::Username => {
            if val.is_empty() {
                app.err = "Username cannot be empty".into();
                return;
            }
            app.config.username = val;
            app.go_to_page(Page::Password);
        }
        Page::Disk => {
            if val.is_empty() {
                app.err = "Device cannot be empty".into();
                return;
            }
            app.config.disk_dev = val;
            // Fetch disk info for confirm page
            app.cmd_output = cmd::run_capture(&format!(
                "lsblk -d -n -o NAME,SIZE,MODEL,TYPE 2>/dev/null | grep disk"
            ))
            .await
            .unwrap_or_default();
            app.go_to_page(Page::DiskConfirm);
        }
        Page::PartNewStart => {
            if val.is_empty() {
                app.err = "Start position required".into();
                return;
            }
            app.part_new_start = val;
            app.go_to_page(Page::PartNewEnd);
        }
        Page::PartNewEnd => {
            if val.is_empty() {
                app.err = "End position required".into();
                return;
            }
            let start = &app.part_new_start;
            if let Err(e) = cmd::run(&format!(
                r#"parted -s /dev/{} mkpart primary "{start}" "{val}""#,
                app.config.disk_dev
            ))
            .await
            {
                app.err = format!("Failed: {e}");
                return;
            }
            tokio::time::sleep(Duration::from_secs(2)).await;
            cmd::run_silent(&format!("partprobe /dev/{}", app.config.disk_dev)).await;
            tokio::time::sleep(Duration::from_secs(1)).await;
            let name = cmd::run_capture(&format!(
                "lsblk -n -l -o NAME /dev/{} | tail -1",
                app.config.disk_dev
            ))
            .await
            .unwrap_or_default();
            app.config.nixos_part = format!("/dev/{name}");
            app.go_to_page(Page::PartConfirm);
        }
        Page::PartExist => {
            if val.is_empty() {
                app.err = "Partition device required".into();
                return;
            }
            app.config.nixos_part = format!("/dev/{val}");
            app.go_to_page(Page::PartConfirm);
        }
        Page::Swap => {
            app.config.swap_size = if val.is_empty() { "8G".into() } else { val };
            if app.config.mode == "whole-disk" {
                app.go_to_page(Page::Fs);
            } else {
                app.go_to_page(Page::Gpu);
            }
        }
        Page::GpuNvBus => {
            app.config.nvidia_bus_id = val;
            app.go_to_page(Page::GpuIgpuType);
        }
        Page::GpuIgpuBus => {
            app.config.igpu_bus_id = val;
            app.go_to_page(Page::Summary);
        }
        _ => {}
    }
}

async fn handle_password_submit(app: &mut App) {
    let val = app.input.clone();
    if val.is_empty() {
        app.err = "Password cannot be empty".into();
        return;
    }

    if app.page == Page::Password {
        app.password_tmp = val;
        app.go_to_page(Page::PasswordConfirm);
    } else {
        if val != app.password_tmp {
            app.err = "Passwords do not match".into();
            app.go_to_page(Page::Password);
            return;
        }
        // Hash password
        match backend::hash_password(&val).await {
            Ok(hash) => {
                app.config.hashed_pw = hash;
                app.go_to_page(Page::Mode);
            }
            Err(e) => {
                app.err = format!("Failed to hash password: {e}");
                app.go_to_page(Page::Password);
            }
        }
    }
}

fn handle_confirm_submit(app: &mut App) {
    if app.input_value() != "yes" {
        app.err = "Type 'yes' to confirm".into();
        return;
    }
    match app.page {
        Page::DiskConfirm => {
            if app.config.mode == "whole-disk" {
                app.go_to_page(Page::Swap);
            } else {
                app.go_to_page(Page::PartSelect);
            }
        }
        Page::PartConfirm => {
            // Auto-detect EFI
            let _disk = &app.config.disk_dev;
            app.go_to_page(Page::Efi);
            // EFI detection will happen in go_to_page via cmd_output
        }
        _ => {}
    }
}

fn handle_selection(app: &mut App) {
    match app.page {
        Page::Mode => {
            app.config.mode = if app.cursor == 0 {
                "whole-disk"
            } else {
                "partition-only"
            }
            .into();
            app.go_to_page(Page::Disk);
        }
        Page::PartSelect => {
            if app.cursor == 0 {
                app.go_to_page(Page::PartExist);
            } else {
                app.go_to_page(Page::PartNewStart);
            }
        }
        Page::Fs => {
            app.config.fs_type = if app.cursor == 0 { "btrfs" } else { "ext4" }.into();
            app.go_to_page(Page::Gpu);
        }
        Page::Gpu => {
            app.config.gpu_choice = format!("{}", app.cursor + 1);
            if app.cursor == 2 {
                app.go_to_page(Page::GpuNvBus);
            } else {
                app.go_to_page(Page::Summary);
            }
        }
        Page::GpuIgpuType => {
            app.config.igpu_type = if app.cursor == 0 { "intel" } else { "amd" }.into();
            app.go_to_page(Page::GpuIgpuBus);
        }
        _ => {}
    }
}

async fn start_installation(app: &mut App) {
    app.go_to_page(Page::Installing);

    // Init git for nix flake
    cmd::run_silent("git init").await;
    cmd::run_silent("git add .").await;
    cmd::run_silent(r#"git commit -m "Embedded flake" --allow-empty"#).await;

    let cfg = app.config.clone();
    let work_dir = app.work_dir.clone();
    let (tx, rx) = mpsc::unbounded_channel();
    app.progress_rx = Some(rx);

    // Spawn installation in background task
    tokio::spawn(async move {
        let mut state = state::State::new();
        backend::run_installation(cfg, &mut state, &work_dir, tx).await;
    });
}
