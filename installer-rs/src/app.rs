use tokio::sync::mpsc;

/// Holds all user-collected configuration for installation.
#[derive(Debug, Clone, Default)]
pub struct InstallConfig {
    pub hostname: String,
    pub username: String,
    pub hashed_pw: String,
    pub mode: String, // "whole-disk" or "partition-only"
    pub disk_dev: String,
    pub nixos_part: String,
    pub efi_part: String,
    pub swap_size: String,
    pub fs_type: String,
    pub gpu_choice: String, // "1"=none, "2"=nvidia, "3"=prime
    pub nvidia_bus_id: String,
    pub igpu_bus_id: String,
    pub igpu_type: String,
}

/// Progress updates sent from backend to TUI.
#[derive(Debug, Clone)]
pub struct ProgressUpdate {
    pub step: String,
    pub message: String,
    pub done: bool,
    pub error: Option<String>,
}

/// Page in the wizard.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Page {
    Welcome,
    Hostname,
    Username,
    Password,
    PasswordConfirm,
    Mode,
    Disk,
    DiskConfirm,
    PartSelect,
    PartNewStart,
    PartNewEnd,
    PartExist,
    PartConfirm,
    Efi,
    Swap,
    Fs,
    Gpu,
    GpuNvBus,
    GpuIgpuType,
    GpuIgpuBus,
    Summary,
    Installing,
    Done,
}

/// Status of an installation step.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StepStatus {
    Pending,
    Running,
    Done,
    Error,
}

/// An installation step tracked in the progress view.
#[derive(Debug, Clone)]
pub struct InstallStep {
    pub name: String,
    pub label: String,
    pub status: StepStatus,
}

/// Main application state.
pub struct App {
    pub page: Page,
    pub should_quit: bool,

    // Input
    pub input: String,
    pub cursor_pos: usize,
    pub input_mode: InputMode,
    pub err: String,

    // Selection
    pub choices: Vec<String>,
    pub cursor: usize,

    // Collected data
    pub config: InstallConfig,
    pub password_tmp: String,
    pub part_new_start: String,

    // Shell output for display
    pub cmd_output: String,

    // Installation
    pub install_steps: Vec<InstallStep>,
    pub log_lines: Vec<String>,
    pub install_done: bool,
    pub install_err: Option<String>,
    pub progress_rx: Option<mpsc::UnboundedReceiver<ProgressUpdate>>,
    pub spinner_frame: usize,

    // Work dir
    pub work_dir: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputMode {
    Normal,
    Password,
}

impl App {
    pub fn new(work_dir: String) -> Self {
        Self {
            page: Page::Welcome,
            should_quit: false,
            input: String::new(),
            cursor_pos: 0,
            input_mode: InputMode::Normal,
            err: String::new(),
            choices: Vec::new(),
            cursor: 0,
            config: InstallConfig::default(),
            password_tmp: String::new(),
            part_new_start: String::new(),
            cmd_output: String::new(),
            install_steps: vec![
                InstallStep {
                    name: "generate_config".into(),
                    label: "Generate configuration".into(),
                    status: StepStatus::Pending,
                },
                InstallStep {
                    name: "partition".into(),
                    label: "Partition disk".into(),
                    status: StepStatus::Pending,
                },
                InstallStep {
                    name: "install_nixos".into(),
                    label: "Install NixOS".into(),
                    status: StepStatus::Pending,
                },
                InstallStep {
                    name: "copy_flake".into(),
                    label: "Copy flake to system".into(),
                    status: StepStatus::Pending,
                },
            ],
            log_lines: Vec::new(),
            install_done: false,
            install_err: None,
            progress_rx: None,
            spinner_frame: 0,
            work_dir,
        }
    }

    pub fn reset_input(&mut self) {
        self.input.clear();
        self.cursor_pos = 0;
        self.err.clear();
    }

    pub fn go_to_page(&mut self, page: Page) {
        self.page = page;
        self.reset_input();
        self.cursor = 0;
        self.input_mode = InputMode::Normal;

        match page {
            Page::Mode => {
                self.choices = vec![
                    "Whole disk — fresh install, wipes entire disk".into(),
                    "Partition only — dual-boot, specific partition".into(),
                ];
            }
            Page::Password | Page::PasswordConfirm => {
                self.input_mode = InputMode::Password;
            }
            Page::PartSelect => {
                self.choices = vec![
                    "Use an existing partition".into(),
                    "Create a new partition from unallocated space".into(),
                ];
            }
            Page::Fs => {
                self.choices = vec!["btrfs (recommended)".into(), "ext4".into()];
            }
            Page::Gpu => {
                self.choices = vec![
                    "None / Intel / AMD".into(),
                    "NVIDIA (proprietary)".into(),
                    "NVIDIA + AMD/Intel hybrid (Prime)".into(),
                ];
            }
            Page::GpuIgpuType => {
                self.choices = vec!["Intel".into(), "AMD".into()];
            }
            _ => {}
        }
    }

    pub fn type_char(&mut self, c: char) {
        self.input.insert(self.cursor_pos, c);
        self.cursor_pos += 1;
    }

    pub fn delete_char(&mut self) {
        if self.cursor_pos > 0 {
            self.cursor_pos -= 1;
            self.input.remove(self.cursor_pos);
        }
    }

    pub fn input_value(&self) -> String {
        self.input.trim().to_string()
    }

    pub fn prev_page(&self) -> Page {
        match self.page {
            Page::Hostname => Page::Welcome,
            Page::Username => Page::Hostname,
            Page::Password => Page::Username,
            Page::PasswordConfirm => Page::Password,
            Page::Mode => Page::Password,
            Page::Disk => Page::Mode,
            Page::DiskConfirm => Page::Disk,
            Page::PartSelect => Page::DiskConfirm,
            Page::PartExist | Page::PartNewStart => Page::PartSelect,
            Page::PartNewEnd => Page::PartNewStart,
            Page::PartConfirm => Page::PartSelect,
            Page::Efi => Page::PartConfirm,
            Page::Swap => {
                if self.config.mode == "whole-disk" {
                    Page::DiskConfirm
                } else {
                    Page::Efi
                }
            }
            Page::Fs => Page::Swap,
            Page::Gpu => {
                if self.config.mode == "whole-disk" {
                    Page::Fs
                } else {
                    Page::Swap
                }
            }
            Page::GpuNvBus => Page::Gpu,
            Page::GpuIgpuType => Page::GpuNvBus,
            Page::GpuIgpuBus => Page::GpuIgpuType,
            Page::Summary => Page::Gpu,
            _ => Page::Welcome,
        }
    }

    pub fn tick_spinner(&mut self) {
        self.spinner_frame = (self.spinner_frame + 1) % 10;
    }

    pub fn spinner_char(&self) -> &str {
        const FRAMES: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        FRAMES[self.spinner_frame % FRAMES.len()]
    }

    pub fn handle_progress(&mut self, p: ProgressUpdate) {
        if let Some(ref e) = p.error {
            self.install_err = Some(e.clone());
            for step in &mut self.install_steps {
                if step.name == p.step {
                    step.status = StepStatus::Error;
                }
            }
            return;
        }

        for step in &mut self.install_steps {
            if step.name == p.step {
                step.status = if p.done {
                    StepStatus::Done
                } else {
                    StepStatus::Running
                };
            }
        }

        if !p.message.is_empty() {
            self.log_lines.push(p.message);
            if self.log_lines.len() > 8 {
                self.log_lines.drain(..self.log_lines.len() - 8);
            }
        }

        if self
            .install_steps
            .iter()
            .all(|s| s.status == StepStatus::Done)
        {
            self.install_done = true;
            self.go_to_page(Page::Done);
        }
    }

    pub fn install_progress_fraction(&self) -> f64 {
        let done = self
            .install_steps
            .iter()
            .filter(|s| s.status == StepStatus::Done)
            .count();
        done as f64 / self.install_steps.len() as f64
    }
}
