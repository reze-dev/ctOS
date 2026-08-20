use std::collections::VecDeque;
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use zeroize::Zeroize;

/// Installation mode.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum InstallMode {
    #[default]
    WholeDisk,
    PartitionOnly,
}

impl std::fmt::Display for InstallMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::WholeDisk => write!(f, "whole-disk"),
            Self::PartitionOnly => write!(f, "partition-only"),
        }
    }
}

/// Profile bundle choice.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ProfileChoice {
    Base,
    #[default]
    Desktop,
    Workstation,
}

impl std::fmt::Display for ProfileChoice {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Base => write!(f, "Base (Minimal CLI Server)"),
            Self::Desktop => write!(f, "Desktop (GUI + Compositors + Browsers)"),
            Self::Workstation => write!(f, "Workstation (Desktop + Devtools + Virt)"),
        }
    }
}

/// Bootloader choice.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum BootloaderChoice {
    #[default]
    Grub,
    Limine,
}

impl std::fmt::Display for BootloaderChoice {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Grub => write!(f, "GRUB (Cyberpunk DedSec Theme)"),
            Self::Limine => write!(f, "Limine (Modern Ultra-Fast UEFI)"),
        }
    }
}

/// GPU driver choice.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum GpuChoice {
    #[default]
    None,
    Nvidia,
    NvidiaPrime,
}

impl std::fmt::Display for GpuChoice {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::None => write!(f, "Default (no NVIDIA)"),
            Self::Nvidia => write!(f, "NVIDIA Discrete"),
            Self::NvidiaPrime => write!(f, "NVIDIA Prime (Hybrid GPU)"),
        }
    }
}

/// Integrated GPU type for Prime setups.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum IgpuType {
    #[default]
    Intel,
    Amd,
}

impl std::fmt::Display for IgpuType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Intel => write!(f, "intel"),
            Self::Amd => write!(f, "amd"),
        }
    }
}

impl IgpuType {
    pub fn bus_id_key(&self) -> &'static str {
        match self {
            Self::Intel => "intelBusId",
            Self::Amd => "amdgpuBusId",
        }
    }
}

/// Custom toggleable feature in the customization page.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FeatureOption {
    pub id: String,
    pub label: String,
    pub category: String,
    pub enabled: bool,
}

/// Dual-boot OS entry detected on ESP.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DualBootEntry {
    pub name: String,
    pub efi_path: String,
    pub disk_uuid: String,
    pub enabled: bool,
}

/// Disk information parsed from lsblk.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct DiskInfo {
    pub name: String,
    pub size: String,
    pub model: String,
    pub drive_type: String,
    pub partitions: Vec<PartitionInfo>,
}

/// Partition information parsed from lsblk.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct PartitionInfo {
    pub name: String,
    pub size: String,
    pub fs_type: String,
    pub mountpoint: Option<String>,
    pub label: Option<String>,
    pub uuid: Option<String>,
}

/// Holds all user-collected configuration for installation.
#[derive(Debug, Clone)]
pub struct InstallConfig {
    pub hostname: String,
    pub username: String,
    pub hashed_pw: String,
    pub profile: ProfileChoice,
    pub shell: String,
    pub bootloader: BootloaderChoice,
    pub features: Vec<FeatureOption>,
    pub dual_boot_entries: Vec<DualBootEntry>,
    pub mode: InstallMode,
    pub disk_dev: String,
    pub nixos_part: String,
    pub efi_part: String,
    pub swap_size: String,
    pub swap_partition: String,
    pub fs_type: String,
    pub root_size: String,
    pub gpu_choice: GpuChoice,
    pub nvidia_bus_id: String,
    pub igpu_bus_id: String,
    pub igpu_type: IgpuType,
}

impl Default for InstallConfig {
    fn default() -> Self {
        Self {
            hostname: String::new(),
            username: String::new(),
            hashed_pw: String::new(),
            profile: ProfileChoice::Desktop,
            shell: "zsh".to_string(),
            bootloader: BootloaderChoice::Grub,
            features: default_features(ProfileChoice::Desktop),
            dual_boot_entries: Vec::new(),
            mode: InstallMode::WholeDisk,
            disk_dev: String::new(),
            nixos_part: String::new(),
            efi_part: String::new(),
            swap_size: "8G".to_string(),
            swap_partition: String::new(),
            fs_type: "btrfs".to_string(),
            root_size: "100%".to_string(),
            gpu_choice: GpuChoice::None,
            nvidia_bus_id: String::new(),
            igpu_bus_id: String::new(),
            igpu_type: IgpuType::Intel,
        }
    }
}

pub fn default_features(profile: ProfileChoice) -> Vec<FeatureOption> {
    let is_desktop = profile == ProfileChoice::Desktop || profile == ProfileChoice::Workstation;
    let is_workstation = profile == ProfileChoice::Workstation;

    vec![
        // Window Managers / Compositors
        FeatureOption {
            id: "hyprland".into(),
            label: "Hyprland (Dynamic Wayland Tiling WM)".into(),
            category: "Desktop / Compositor".into(),
            enabled: is_desktop,
        },
        FeatureOption {
            id: "niri".into(),
            label: "Niri (Scrollable-tiling Wayland WM)".into(),
            category: "Desktop / Compositor".into(),
            enabled: false,
        },
        FeatureOption {
            id: "noctalia".into(),
            label: "Noctalia (Custom Desktop Environment)".into(),
            category: "Desktop / Compositor".into(),
            enabled: is_desktop,
        },
        // Shells
        FeatureOption {
            id: "zsh".into(),
            label: "Zsh + Starship / OMP Shell".into(),
            category: "Shell & Terminal".into(),
            enabled: true,
        },
        FeatureOption {
            id: "fish".into(),
            label: "Fish Friendly Interactive Shell".into(),
            category: "Shell & Terminal".into(),
            enabled: false,
        },
        FeatureOption {
            id: "ghostty".into(),
            label: "Ghostty Modern Terminal".into(),
            category: "Shell & Terminal".into(),
            enabled: is_desktop,
        },
        FeatureOption {
            id: "kitty".into(),
            label: "Kitty GPU-accelerated Terminal".into(),
            category: "Shell & Terminal".into(),
            enabled: is_desktop,
        },
        // Development & Virt
        FeatureOption {
            id: "devtools".into(),
            label: "Developer Workspace (LSPs, Compilers, Tools)".into(),
            category: "Development & Virt".into(),
            enabled: is_workstation,
        },
        FeatureOption {
            id: "virtualization".into(),
            label: "Docker & Libvirt Virtualization".into(),
            category: "Development & Virt".into(),
            enabled: is_workstation,
        },
        FeatureOption {
            id: "emacs".into(),
            label: "Emacs with Doom/Custom Config".into(),
            category: "Development & Virt".into(),
            enabled: false,
        },
    ]
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
    Profile,
    ProfileCustomize,
    Bootloader,
    Mode,
    Disk,
    DiskConfirm,
    PartSelect,
    PartNewStart,
    PartNewEnd,
    PartExist,
    PartConfirm,
    Efi,
    Fs,
    RootSize,
    Swap,
    SwapPartition,
    Gpu,
    GpuNvBus,
    GpuIgpuType,
    GpuIgpuBus,
    DualBoot,
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

    // Input state
    pub input: String,
    pub cursor_pos: usize,
    pub err: String,

    // Selection state
    pub choices: Vec<String>,
    pub cursor: usize,

    // Detected hardware info
    pub detected_disks: Vec<DiskInfo>,
    pub detected_efis: Vec<(String, String, String)>,

    // Collected data
    pub config: InstallConfig,
    pub plain_pw: String,

    // Temporary storage for multi-step inputs
    pub part_new_start: String,

    // Installation progress
    pub install_steps: Vec<InstallStep>,
    pub install_err: Option<String>,
    pub install_rx: Option<mpsc::UnboundedReceiver<ProgressUpdate>>,
    pub install_handle: Option<JoinHandle<()>>,
    pub spinner_idx: usize,
    pub work_dir: String,

    // Live terminal log lines for the UI
    pub log_lines: VecDeque<String>,
}

impl App {
    pub fn new(work_dir: String) -> Self {
        let mut app = Self {
            page: Page::Welcome,
            should_quit: false,
            input: String::new(),
            cursor_pos: 0,
            err: String::new(),
            choices: Vec::new(),
            cursor: 0,
            detected_disks: Vec::new(),
            detected_efis: Vec::new(),
            config: InstallConfig::default(),
            plain_pw: String::new(),
            part_new_start: String::new(),
            install_steps: vec![
                InstallStep {
                    name: "generate_config".into(),
                    label: "Generate System Configuration".into(),
                    status: StepStatus::Pending,
                },
                InstallStep {
                    name: "partition".into(),
                    label: "Partition & Format Disk (Disko)".into(),
                    status: StepStatus::Pending,
                },
                InstallStep {
                    name: "install_nixos".into(),
                    label: "Install NixOS System & Packages".into(),
                    status: StepStatus::Pending,
                },
                InstallStep {
                    name: "copy_flake".into(),
                    label: "Copy Flake & Setup User Environment".into(),
                    status: StepStatus::Pending,
                },
            ],
            install_err: None,
            install_rx: None,
            install_handle: None,
            spinner_idx: 0,
            work_dir,
            log_lines: VecDeque::with_capacity(100),
        };
        app.init_page();
        app
    }

    pub fn add_log(&mut self, line: String) {
        if self.log_lines.len() >= 100 {
            self.log_lines.pop_front();
        }
        self.log_lines.push_back(line);
    }

    pub fn apply_profile(&mut self, profile: ProfileChoice) {
        self.config.profile = profile;
        self.config.features = default_features(profile);
    }

    pub fn toggle_current_feature(&mut self) {
        if self.cursor < self.config.features.len() {
            self.config.features[self.cursor].enabled = !self.config.features[self.cursor].enabled;
        }
    }

    pub fn toggle_current_dual_boot(&mut self) {
        if self.cursor < self.config.dual_boot_entries.len() {
            self.config.dual_boot_entries[self.cursor].enabled =
                !self.config.dual_boot_entries[self.cursor].enabled;
        }
    }

    pub fn init_page(&mut self) {
        self.err.clear();
        self.cursor = 0;

        match self.page {
            Page::Welcome => {}
            Page::Hostname => {
                self.input = self.config.hostname.clone();
                self.cursor_pos = self.input.len();
            }
            Page::Username => {
                self.input = self.config.username.clone();
                self.cursor_pos = self.input.len();
            }
            Page::Password | Page::PasswordConfirm => {
                self.input.clear();
                self.cursor_pos = 0;
            }
            Page::Profile => {
                self.choices = vec![
                    ProfileChoice::Base.to_string(),
                    ProfileChoice::Desktop.to_string(),
                    ProfileChoice::Workstation.to_string(),
                ];
                self.cursor = match self.config.profile {
                    ProfileChoice::Base => 0,
                    ProfileChoice::Desktop => 1,
                    ProfileChoice::Workstation => 2,
                };
            }
            Page::ProfileCustomize => {
                self.cursor = 0;
            }
            Page::Bootloader => {
                self.choices = vec![
                    BootloaderChoice::Grub.to_string(),
                    BootloaderChoice::Limine.to_string(),
                ];
                self.cursor = match self.config.bootloader {
                    BootloaderChoice::Grub => 0,
                    BootloaderChoice::Limine => 1,
                };
            }
            Page::Mode => {
                self.choices = vec![
                    "Whole Disk (Disko wipes disk & partitions automatically)".into(),
                    "Partition Only (Install alongside existing OS / custom partitions)".into(),
                ];
                self.cursor = if self.config.mode == InstallMode::PartitionOnly {
                    1
                } else {
                    0
                };
            }
            Page::Disk => {
                if !self.detected_disks.is_empty() {
                    self.choices = self
                        .detected_disks
                        .iter()
                        .map(|d| format!("{} - {} ({}, {})", d.name, d.size, d.drive_type, d.model))
                        .collect();
                    if let Some(pos) = self
                        .detected_disks
                        .iter()
                        .position(|d| d.name == self.config.disk_dev)
                    {
                        self.cursor = pos;
                    }
                } else {
                    self.input = self.config.disk_dev.clone();
                    self.cursor_pos = self.input.len();
                }
            }
            Page::DiskConfirm => {
                self.input.clear();
                self.cursor_pos = 0;
            }
            Page::PartSelect => {
                self.choices = vec![
                    "Create new partition in free space (parted)".into(),
                    "Use existing unformatted partition".into(),
                ];
            }
            Page::PartNewStart => {
                self.input = "100GB".into();
                self.cursor_pos = self.input.len();
            }
            Page::PartNewEnd => {
                self.input = "100%".into();
                self.cursor_pos = self.input.len();
            }
            Page::PartExist => {
                self.input.clear();
                self.cursor_pos = 0;
            }
            Page::PartConfirm => {
                self.choices = vec![
                    "Yes, format this partition for NixOS".into(),
                    "No, go back and change partition".into(),
                ];
            }
            Page::Efi => {
                if !self.detected_efis.is_empty() {
                    self.choices = self
                        .detected_efis
                        .iter()
                        .map(|(dev, size, uuid)| format!("{dev} ({size}) [UUID: {uuid}]"))
                        .collect();
                    self.choices
                        .push("Enter custom EFI partition manually".into());
                } else {
                    self.input = self.config.efi_part.clone();
                    self.cursor_pos = self.input.len();
                }
            }
            Page::Fs => {
                self.choices = vec![
                    "btrfs (recommended: subvolumes for root, home, nix, log & snapshots)".into(),
                    "ext4 (standard single partition)".into(),
                ];
                self.cursor = if self.config.fs_type == "ext4" { 1 } else { 0 };
            }
            Page::RootSize => {
                self.input = self.config.root_size.clone();
                self.cursor_pos = self.input.len();
            }
            Page::Swap => {
                self.input = self.config.swap_size.clone();
                self.cursor_pos = self.input.len();
            }
            Page::SwapPartition => {
                self.input = self.config.swap_partition.clone();
                self.cursor_pos = self.input.len();
            }
            Page::Gpu => {
                self.choices = vec![
                    GpuChoice::None.to_string(),
                    GpuChoice::Nvidia.to_string(),
                    GpuChoice::NvidiaPrime.to_string(),
                ];
                self.cursor = match self.config.gpu_choice {
                    GpuChoice::None => 0,
                    GpuChoice::Nvidia => 1,
                    GpuChoice::NvidiaPrime => 2,
                };
            }
            Page::GpuNvBus => {
                self.input = self.config.nvidia_bus_id.clone();
                self.cursor_pos = self.input.len();
            }
            Page::GpuIgpuType => {
                self.choices = vec!["Intel".into(), "AMD".into()];
                self.cursor = match self.config.igpu_type {
                    IgpuType::Intel => 0,
                    IgpuType::Amd => 1,
                };
            }
            Page::GpuIgpuBus => {
                self.input = self.config.igpu_bus_id.clone();
                self.cursor_pos = self.input.len();
            }
            Page::DualBoot => {
                self.cursor = 0;
            }
            Page::Summary => {}
            Page::Installing => {}
            Page::Done => {}
        }
    }

    pub fn go_to_page(&mut self, next: Page) {
        self.page = next;
        self.init_page();
    }

    pub fn prev_page(&self) -> Page {
        match self.page {
            Page::Welcome => Page::Welcome,
            Page::Hostname => Page::Welcome,
            Page::Username => Page::Hostname,
            Page::Password => Page::Username,
            Page::PasswordConfirm => Page::Password,
            Page::Profile => Page::PasswordConfirm,
            Page::ProfileCustomize => Page::Profile,
            Page::Bootloader => Page::ProfileCustomize,
            Page::Mode => Page::Bootloader,
            Page::Disk => Page::Mode,
            Page::DiskConfirm => Page::Disk,
            Page::PartSelect => Page::Disk,
            Page::PartNewStart => Page::PartSelect,
            Page::PartNewEnd => Page::PartNewStart,
            Page::PartExist => Page::PartSelect,
            Page::PartConfirm => {
                if self.part_new_start.is_empty() {
                    Page::PartExist
                } else {
                    Page::PartNewEnd
                }
            }
            Page::Efi => {
                if self.config.mode == InstallMode::WholeDisk {
                    Page::DiskConfirm
                } else {
                    Page::PartConfirm
                }
            }
            Page::Fs => Page::Efi,
            Page::RootSize => Page::Fs,
            Page::Swap => Page::Fs,
            Page::SwapPartition => Page::Swap,
            Page::Gpu => {
                if self.config.mode == InstallMode::WholeDisk && self.config.fs_type == "ext4" {
                    Page::RootSize
                } else if !self.config.swap_partition.is_empty() {
                    Page::SwapPartition
                } else {
                    Page::Swap
                }
            }
            Page::GpuNvBus => Page::Gpu,
            Page::GpuIgpuType => Page::GpuNvBus,
            Page::GpuIgpuBus => Page::GpuIgpuType,
            Page::DualBoot => match self.config.gpu_choice {
                GpuChoice::None => Page::Gpu,
                GpuChoice::Nvidia => Page::GpuNvBus,
                GpuChoice::NvidiaPrime => Page::GpuIgpuBus,
            },
            Page::Summary => {
                if !self.config.dual_boot_entries.is_empty() {
                    Page::DualBoot
                } else {
                    match self.config.gpu_choice {
                        GpuChoice::None => Page::Gpu,
                        GpuChoice::Nvidia => Page::GpuNvBus,
                        GpuChoice::NvidiaPrime => Page::GpuIgpuBus,
                    }
                }
            }
            Page::Installing => Page::Summary,
            Page::Done => Page::Done,
        }
    }

    pub fn type_char(&mut self, c: char) {
        self.input.insert(self.cursor_pos, c);
        self.cursor_pos += 1;
        self.err.clear();
    }

    pub fn delete_char(&mut self) {
        if self.cursor_pos > 0 {
            self.input.remove(self.cursor_pos - 1);
            self.cursor_pos -= 1;
            self.err.clear();
        }
    }

    pub fn input_value(&self) -> String {
        self.input.trim().to_string()
    }

    pub fn spinner_char(&self) -> &'static str {
        const SPINNER: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        SPINNER[self.spinner_idx % SPINNER.len()]
    }
}

impl Drop for App {
    fn drop(&mut self) {
        self.plain_pw.zeroize();
        self.input.zeroize();
    }
}
