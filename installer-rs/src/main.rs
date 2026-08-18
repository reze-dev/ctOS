mod app;
mod backend;
mod cmd;
mod detect;
mod flake;
mod state;
mod ui;

use app::{App, BootloaderChoice, GpuChoice, IgpuType, InstallMode, Page, ProfileChoice};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::prelude::*;
use std::io::stdout;
use std::time::Duration;
use tokio::sync::mpsc;

const NIX_CONFIG_FEATURES: &str = "experimental-features = nix-command flakes";

fn main() -> Result<(), Box<dyn std::error::Error>> {
    ensure_nix_config();

    // Check root privilege in release / production mode
    if std::env::var("NORTHSTAR_DEV").is_err() && nix::unistd::geteuid().as_raw() != 0 {
        eprintln!("\x1b[0;31mPlease run as root (e.g. sudo northstar-installer)\x1b[0m");
        std::process::exit(1);
    }

    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(async_main())
}

async fn async_main() -> Result<(), Box<dyn std::error::Error>> {
    let work_dir = flake::extract_flake().map_err(|e| -> Box<dyn std::error::Error> {
        eprintln!("Failed to extract flake: {e}");
        e.into()
    })?;

    let _ = std::env::set_current_dir(&work_dir);

    let mut app = App::new(work_dir.clone());

    // Hardware Auto-Detection
    let detected = detect::detect_all().await;
    app.detected_disks = detected.disks;
    app.detected_efis = detected.efi_partitions;
    app.config.dual_boot_entries = detected.detected_os;

    if let Some(first_disk) = app.detected_disks.first() {
        app.config.disk_dev = first_disk.name.clone();
    }
    if let Some((first_efi, _, _)) = app.detected_efis.first() {
        app.config.efi_part = first_efi.clone();
    }

    // Auto-configure detected GPUs
    app.config.gpu_choice = detected.gpu_choice;
    if let Some(nv) = detected.nvidia_bus_id {
        app.config.nvidia_bus_id = nv;
    }
    if let Some(igpu) = detected.igpu_bus_id {
        app.config.igpu_bus_id = igpu;
    }
    app.config.igpu_type = detected.igpu_type;

    app.init_page();

    // Install panic hook
    let original_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |panic_info| {
        let _ = disable_raw_mode();
        let _ = stdout().execute(LeaveAlternateScreen);
        original_hook(panic_info);
    }));

    // Setup terminal
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    let result = run_app(&mut terminal, &mut app).await;

    // Teardown terminal
    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;

    if let Err(ref e) = result {
        eprintln!("Error: {e}");
    }

    let _ = std::fs::remove_dir_all(&work_dir);
    result
}

fn ensure_nix_config() {
    let current = std::env::var("NIX_CONFIG").unwrap_or_default();
    if current.contains(NIX_CONFIG_FEATURES) {
        return;
    }

    let next = if current.trim().is_empty() {
        NIX_CONFIG_FEATURES.to_string()
    } else {
        format!("{}\n{}", current.trim_end(), NIX_CONFIG_FEATURES)
    };
    unsafe { std::env::set_var("NIX_CONFIG", next) };
}

async fn run_app(
    terminal: &mut Terminal<CrosstermBackend<std::io::Stdout>>,
    app: &mut App,
) -> Result<(), Box<dyn std::error::Error>> {
    loop {
        terminal.draw(|f| ui::draw(f, app))?;

        if app.page == Page::Installing {
            let mut updates = Vec::new();
            if let Some(ref mut rx) = app.install_rx {
                while let Ok(update) = rx.try_recv() {
                    updates.push(update);
                }
            }

            for update in updates {
                let msg = update.message.clone();
                if let Some(step) = app.install_steps.iter_mut().find(|s| s.name == update.step)
                {
                    if update.done {
                        step.status = app::StepStatus::Done;
                    } else if update.error.is_some() {
                        step.status = app::StepStatus::Error;
                    } else {
                        step.status = app::StepStatus::Running;
                    }
                }
                if !msg.is_empty() {
                    app.add_log(format!("❯ {msg}"));
                }
                if let Some(err) = update.error {
                    app.add_log(format!("✗ ERROR: {err}"));
                    app.install_err = Some(err);
                }
            }

            // Check if installation task completed
            if let Some(ref handle) = app.install_handle {
                if handle.is_finished() {
                    if app.install_err.is_none() {
                        app.go_to_page(Page::Done);
                    }
                    app.install_handle = None;
                }
            }

            app.spinner_idx = app.spinner_idx.wrapping_add(1);
        }

        if event::poll(Duration::from_millis(80))? {
            if let Event::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue;
                }

                if key.code == KeyCode::Char('c')
                    && key.modifiers.contains(crossterm::event::KeyModifiers::CONTROL)
                {
                    app.should_quit = true;
                }

                handle_key(app, key.code).await;
            }
        }

        if app.should_quit {
            break;
        }
    }

    Ok(())
}

async fn handle_key(app: &mut App, key: KeyCode) {
    match app.page {
        Page::Welcome => match key {
            KeyCode::Enter => app.go_to_page(Page::Hostname),
            KeyCode::Char('q') => app.should_quit = true,
            _ => {}
        },

        Page::Hostname | Page::Username | Page::Password | Page::PasswordConfirm | Page::DiskConfirm | Page::PartNewStart | Page::PartNewEnd | Page::PartExist | Page::RootSize | Page::Swap | Page::SwapPartition | Page::GpuNvBus | Page::GpuIgpuBus => {
            match key {
                KeyCode::Enter => handle_text_submit(app).await,
                KeyCode::Char(c) => app.type_char(c),
                KeyCode::Backspace => app.delete_char(),
                KeyCode::Esc => {
                    let p = app.prev_page();
                    app.go_to_page(p);
                }
                _ => {}
            }
        }

        Page::ProfileCustomize => match key {
            KeyCode::Up | KeyCode::Char('k') if app.cursor > 0 => {
                app.cursor -= 1;
            }
            KeyCode::Down | KeyCode::Char('j') if app.cursor < app.config.features.len().saturating_sub(1) => {
                app.cursor += 1;
            }
            KeyCode::Char(' ') => {
                app.toggle_current_feature();
            }
            KeyCode::Enter => {
                app.go_to_page(Page::Bootloader);
            }
            KeyCode::Esc => {
                app.go_to_page(Page::Profile);
            }
            _ => {}
        },

        Page::DualBoot => match key {
            KeyCode::Up | KeyCode::Char('k') if app.cursor > 0 => {
                app.cursor -= 1;
            }
            KeyCode::Down | KeyCode::Char('j') if app.cursor < app.config.dual_boot_entries.len().saturating_sub(1) => {
                app.cursor += 1;
            }
            KeyCode::Char(' ') => {
                app.toggle_current_dual_boot();
            }
            KeyCode::Enter => {
                app.go_to_page(Page::Summary);
            }
            KeyCode::Esc => {
                let p = app.prev_page();
                app.go_to_page(p);
            }
            _ => {}
        },

        Page::Profile | Page::Bootloader | Page::Mode | Page::Disk | Page::PartSelect | Page::PartConfirm | Page::Efi | Page::Fs | Page::Gpu | Page::GpuIgpuType => {
            match key {
                KeyCode::Up | KeyCode::Char('k') if app.cursor > 0 => {
                    app.cursor -= 1;
                }
                KeyCode::Down | KeyCode::Char('j') if app.cursor < app.choices.len().saturating_sub(1) => {
                    app.cursor += 1;
                }
                KeyCode::Enter => handle_selection(app),
                KeyCode::Esc => {
                    let p = app.prev_page();
                    app.go_to_page(p);
                }
                _ => {}
            }
        }

        Page::Summary => match key {
            KeyCode::Enter | KeyCode::Char('y') | KeyCode::Char('Y') => {
                start_installation(app).await;
            }
            KeyCode::Esc | KeyCode::Char('n') | KeyCode::Char('N') => {
                app.go_to_page(Page::Hostname);
            }
            _ => {}
        },

        Page::Installing => {}

        Page::Done => {
            if key == KeyCode::Enter || key == KeyCode::Char('q') {
                app.should_quit = true;
            }
        }
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
        Page::Password => {
            if val.is_empty() {
                app.err = "Password cannot be empty".into();
                return;
            }
            app.plain_pw = val;
            app.go_to_page(Page::PasswordConfirm);
        }
        Page::PasswordConfirm => {
            if val != app.plain_pw {
                app.err = "Passwords do not match".into();
                return;
            }
            match backend::hash_password(&app.plain_pw).await {
                Ok(hash) => {
                    app.config.hashed_pw = hash;
                    app.go_to_page(Page::Profile);
                }
                Err(e) => {
                    app.err = format!("Failed to hash password: {e}");
                }
            }
        }
        Page::DiskConfirm => {
            if val.to_lowercase() != "yes" {
                app.err = "Type 'yes' to confirm or press Esc to choose another disk".into();
                return;
            }
            if app.config.mode == InstallMode::WholeDisk {
                app.go_to_page(Page::Fs);
            } else {
                app.go_to_page(Page::PartSelect);
            }
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
        Page::RootSize => {
            app.config.root_size = if val.is_empty() { "100%".into() } else { val };
            app.go_to_page(Page::Swap);
        }
        Page::Swap => {
            let swap = if val.is_empty() { "8G".into() } else { val };
            app.config.swap_size = swap.clone();
            if app.config.mode == InstallMode::PartitionOnly
                && app.config.fs_type == "ext4"
                && swap != "0"
            {
                app.go_to_page(Page::SwapPartition);
            } else {
                app.config.swap_partition.clear();
                app.go_to_page(Page::Gpu);
            }
        }
        Page::SwapPartition => {
            if val.is_empty() {
                app.err = "Swap partition device required for ext4 partition-only mode".into();
                return;
            }
            app.config.swap_partition = val;
            app.go_to_page(Page::Gpu);
        }
        Page::GpuNvBus => {
            if val.is_empty() {
                app.err = "NVIDIA Bus ID required (e.g. PCI:1:0:0)".into();
                return;
            }
            app.config.nvidia_bus_id = val;
            if app.config.gpu_choice == GpuChoice::NvidiaPrime {
                app.go_to_page(Page::GpuIgpuType);
            } else if !app.config.dual_boot_entries.is_empty() {
                app.go_to_page(Page::DualBoot);
            } else {
                app.go_to_page(Page::Summary);
            }
        }
        Page::GpuIgpuBus => {
            if val.is_empty() {
                app.err = "Integrated GPU Bus ID required (e.g. PCI:0:2:0)".into();
                return;
            }
            app.config.igpu_bus_id = val;
            if !app.config.dual_boot_entries.is_empty() {
                app.go_to_page(Page::DualBoot);
            } else {
                app.go_to_page(Page::Summary);
            }
        }
        _ => {}
    }
}

fn handle_selection(app: &mut App) {
    match app.page {
        Page::Profile => {
            let p = match app.cursor {
                0 => ProfileChoice::Base,
                1 => ProfileChoice::Desktop,
                _ => ProfileChoice::Workstation,
            };
            app.apply_profile(p);
            app.go_to_page(Page::ProfileCustomize);
        }
        Page::Bootloader => {
            let b = match app.cursor {
                0 => BootloaderChoice::Grub,
                _ => BootloaderChoice::Limine,
            };
            app.config.bootloader = b;
            app.go_to_page(Page::Mode);
        }
        Page::Mode => {
            app.config.mode = if app.cursor == 0 {
                InstallMode::WholeDisk
            } else {
                InstallMode::PartitionOnly
            };
            app.go_to_page(Page::Disk);
        }
        Page::Disk => {
            if !app.detected_disks.is_empty() {
                if let Some(d) = app.detected_disks.get(app.cursor) {
                    app.config.disk_dev = d.name.clone();
                }
            }
            if app.config.mode == InstallMode::WholeDisk {
                app.go_to_page(Page::DiskConfirm);
            } else {
                app.go_to_page(Page::PartSelect);
            }
        }
        Page::PartSelect => {
            if app.cursor == 0 {
                app.go_to_page(Page::PartNewStart);
            } else {
                app.go_to_page(Page::PartExist);
            }
        }
        Page::PartConfirm => {
            if app.cursor == 0 {
                app.go_to_page(Page::Efi);
            } else {
                app.go_to_page(Page::PartSelect);
            }
        }
        Page::Efi => {
            if !app.detected_efis.is_empty() {
                if app.cursor < app.detected_efis.len() {
                    let (dev, _, _) = &app.detected_efis[app.cursor];
                    app.config.efi_part = dev.clone();
                    app.go_to_page(Page::Fs);
                } else {
                    app.detected_efis.clear();
                    app.init_page();
                }
            }
        }
        Page::Fs => {
            app.config.fs_type = if app.cursor == 0 { "btrfs".into() } else { "ext4".into() };
            if app.config.mode == InstallMode::WholeDisk && app.config.fs_type == "ext4" {
                app.go_to_page(Page::RootSize);
            } else {
                app.go_to_page(Page::Swap);
            }
        }
        Page::Gpu => {
            let g = match app.cursor {
                0 => GpuChoice::None,
                1 => GpuChoice::Nvidia,
                _ => GpuChoice::NvidiaPrime,
            };
            app.config.gpu_choice = g;
            match g {
                GpuChoice::None => {
                    if !app.config.dual_boot_entries.is_empty() {
                        app.go_to_page(Page::DualBoot);
                    } else {
                        app.go_to_page(Page::Summary);
                    }
                }
                GpuChoice::Nvidia | GpuChoice::NvidiaPrime => {
                    if app.config.nvidia_bus_id.is_empty() {
                        app.config.nvidia_bus_id = "PCI:1:0:0".into();
                    }
                    app.go_to_page(Page::GpuNvBus);
                }
            }
        }
        Page::GpuIgpuType => {
            app.config.igpu_type = if app.cursor == 0 {
                IgpuType::Intel
            } else {
                IgpuType::Amd
            };
            if app.config.igpu_bus_id.is_empty() {
                app.config.igpu_bus_id = if app.config.igpu_type == IgpuType::Intel {
                    "PCI:0:2:0".into()
                } else {
                    "PCI:5:0:0".into()
                };
            }
            app.go_to_page(Page::GpuIgpuBus);
        }
        _ => {}
    }
}

async fn start_installation(app: &mut App) {
    app.go_to_page(Page::Installing);

    let (tx, rx) = mpsc::unbounded_channel();
    app.install_rx = Some(rx);

    let cfg = app.config.clone();
    let work_dir = app.work_dir.clone();

    let handle = tokio::spawn(async move {
        let mut state = state::State::new();
        backend::run_installation(cfg, &mut state, &work_dir, tx).await;
    });

    app.install_handle = Some(handle);
}
