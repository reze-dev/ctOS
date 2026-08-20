<p align="center">
  <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="120" alt="NixOS Logo"/>
</p>

<h1 align="center">❄️ Northstar-nix</h1>

<p align="center">
  A premium, modular, option-driven NixOS & Home Manager configuration built on
  <a href="https://flake.parts">flake-parts</a>,
  <a href="https://github.com/nix-community/home-manager">Home Manager</a>,
  <a href="https://github.com/nix-community/disko">disko</a>, and modern
  <b>Pipe Operators</b> (<code>|&gt;</code>).
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos&logoColor=white" alt="NixOS Unstable"/>
  <img src="https://img.shields.io/badge/flake--parts-modular-5277C3?logo=nixos" alt="flake-parts"/>
  <img src="https://img.shields.io/badge/experimental-pipe--operators-orange" alt="Pipe Operators"/>
  <img src="https://img.shields.io/badge/secure--boot-lanzaboote-success" alt="Lanzaboote Secure Boot"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>
</p>

---

## ✨ Key Features

- **🎛️ Toggle-based modularity** — every system and user module is cleanly isolated behind `northstar.<domain>.<feature>.enable` options.
- **⚡ Functional Pipe Operator Composition** — leverages native experimental `pipe-operators` (`|>`) for clean functional transformations in profile bundles and discovery helpers.
- **📁 Auto-discovered configurations** — drop a host directory in `hosts/` or a module anywhere in `modules/` and it is dynamically detected, scanned, and wired up via `lib.scanModules`.
- **🛡️ UEFI Secure Boot & Configurable Bootloaders** — first-class support for **Lanzaboote Secure Boot** (`sbctl`), **Limine** (ultra-fast modern UEFI bootloader), and **GRUB 2** styled with the cyber DedSec theme.
- **🤖 Dedicated AI/ML & Gaming Workstations** — out-of-the-box modules for local LLMs (Ollama, PyTorch, Llama.cpp with CUDA/ROCm acceleration) and high-performance gaming (Steam, Gamemode, Gamescope, MangoHud, Wine/Proton, and controller drivers).
- **🛠️ Automated USB Auto-mounting** — seamless external device detection, auto-mounting, and desktop notifications via `udisks2`, `gvfs`, and `udiskie`.
- **💻 Decoupled Development Workspaces** — developer toolchains (compilers, LSPs, direnv, git, container runtimes, virtualization) isolated into clean workstation profiles.
- **🚀 Dual Async Installers** — both an interactive Ratatui TUI installer (`installer-rs`) with live hardware detection & split log viewing, and an automated Python installer (`installer/install.py`).
- **💾 Declarative Dual-Boot & Disko** — supports whole-disk formatting or partition-only dual-boot layouts with Btrfs subvolumes (`/root`, `/home`, `/nix`, `/var/log`, `/swap`) and auto-chainloading for Windows, Fedora, Ubuntu, and Arch.
- **🔄 Idempotency & Checkpointing** — execution checkpoints allow resuming interrupted installations seamlessly.

---

## 📂 Directory Structure

The repository is organized into distinct domain layers:

```
northstar/
├── flake.nix                   # Flake entry point (inputs, flake-parts wire-up)
├── flake.lock
│
├── flake/                      # flake-parts modules
│   ├── hosts.nix               # Host discovery & nixosConfigurations exports
│   ├── installer.nix           # Python installer package definition
│   └── rust-installer.nix      # Rust TUI installer package definition (crane)
│
├── hosts/                      # Host machine configurations
│   ├── common.nix              # Shared system base config (flakes, pipe-operators)
│   └── <hostname>/             # Per-machine system settings & hardware declarations
│       ├── default.nix         # Host entry point (users, profiles, bootloader, GPU)
│       ├── disko.nix           # Declarative partition scheme
│       └── hardware.nix        # Hardware scans (kernel modules, CPU microcode)
│
├── lib/                        # Shared Nix helpers and discovery templates
│   ├── default.nix             # Module discovery (lib.scanModules), host discovery
│   └── disko/
│       ├── btrfs.nix           # Whole-disk Btrfs layout with subvolumes
│       └── ext4.nix            # Whole-disk Ext4 layout
│
├── home/
│   └── default.nix             # Home Manager configuration entry point
│
├── modules/                    # Option-based module definitions
│   ├── features/               # Vertical feature slices
│   │   ├── core/               # Boot, env, fonts, locale, networking, packages, shells
│   │   ├── desktop/            # Audio, display, browsers, Hyprland, Niri, Noctalia, Caelestia, Gaming
│   │   ├── development/        # Dev defaults, toolchains, AI/ML, git, Emacs, virtualization
│   │   ├── shell/              # Fish, Zsh, Starship, Oh My Posh
│   │   ├── terminals/          # Ghostty, Kitty
│   │   └── tools/              # Eza, Fzf, Tmux, Yazi, Zoxide
│   ├── hardware/               # Hardware drivers (NVIDIA, Prime)
│   └── profiles/               # Composable feature bundles (base, desktop, workstation, gaming)
│
├── installer-rs/               # Ratatui TUI async installer source (Rust)
│   ├── src/                    # App state, hardware detection, UI widgets, Disko generators
│   └── tests/                  # Automated unit test suite (21 tests)
├── installer/                  # Python interactive installer source
├── tests/                      # Python installer & E2E verification test suite (167 tests)
└── assets/                     # DedSec Plymouth splash, themes, and media assets
```

---

## 🚀 Quick Start

### 1. Installation from a NixOS Live USB

Before running the installers, export the flake and experimental feature flags (including **pipe operators**):

```bash
export NIX_CONFIG="experimental-features = nix-command flakes pipe-operators"
```

> [!TIP]
> **Option A (Recommended): Pre-built Rust TUI Installer Binary**
> ```bash
> curl -fsSL https://github.com/reze-dev/northstar/releases/latest/download/northstar-installer -o installer
> chmod +x installer && sudo ./installer
> ```

> [!NOTE]
> **Option B: Run Rust Installer via Nix**
> ```bash
> nix run github:reze-dev/northstar#rust-install --impure
> ```

> [!NOTE]
> **Option C: Run Python Installer via Nix**
> ```bash
> nix run github:reze-dev/northstar --impure
> ```

---

### 2. Post-installation System Management

To apply configuration changes on an installed system:

```bash
cd ~/northstar
sudo nixos-rebuild switch --flake .#<hostname>
```

For example, for the `Makima` host:
```bash
sudo nixos-rebuild switch --flake .#Makima
```

To update flake inputs and dependencies:
```bash
nix flake update
```

---

## 🎛️ Profiles & Feature Bundles

Northstar uses clean profile bundles composed via the native Nix **pipe operator** (`|>`):

```nix
# Example from modules/profiles/desktop.nix
northstar.features = features |> (f: lib.genAttrs f (_: { enable = true; }));
```

### Available Profiles (`northstar.profiles.*`)

| Profile | Option | Description |
| :--- | :--- | :--- |
| **Base** | `northstar.profiles.base.enable` | Minimal headless/server system (boot, networking, SSH, neovim, shells, fonts, locales, env) |
| **Desktop** | `northstar.profiles.desktop.enable` | Full graphical workstation (Audio, Bluetooth, Hyprland, Niri, Noctalia, Firefox, Zen, Ghostty, Kitty, XDG, Power, Udiskie) |
| **Workstation** | `northstar.profiles.workstation.enable` | Desktop + Full Developer Toolchains, Docker/Libvirt virtualization, AI/ML SDKs, Emacs, and Direnv |
| **Gaming** | `northstar.profiles.gaming.enable` | Dedicated gaming environment (Steam, Gamemode, Gamescope, MangoHud, Wine/Proton, Lutris, latency tweaks, controllers) |

---

## 🔧 Module Reference

### Vertical Feature Modules (`northstar.features.*`)

#### Core & System
| Module | Option | Description |
| :--- | :--- | :--- |
| **Boot** | `northstar.features.boot.enable` | Configurable bootloader (`grub` or `limine`) and Plymouth splash |
| **Bootloader** | `northstar.features.boot.loader` | Choose `"grub"` (with DedSec cyberpunk theme) or `"limine"` (fast modern UEFI) |
| **Secure Boot**| `northstar.features.boot.secureBoot.enable` | Lanzaboote UEFI Secure Boot integration + `sbctl` package |
| **Networking**| `northstar.features.networking.enable` | NetworkManager daemon + customized firewall settings |
| **Locales** | `northstar.features.locales.enable` | Timezone, keyboard layout, and i18n locales |
| **Fonts** | `northstar.features.fonts.enable` | Curated Nerd Fonts collection |
| **Packages** | `northstar.features.packages.enable` | Base system utilities, `udisks2`, `gvfs`, and core CLI tools |
| **SSH** | `northstar.features.ssh.enable` | OpenSSH daemon |
| **Environment**| `northstar.features.env.enable` | Global environment variables (`EDITOR`, `VISUAL`, etc.) |

#### Desktop & Window Managers
| Module | Option | Description |
| :--- | :--- | :--- |
| **Hyprland** | `northstar.features.hyprland.enable` | Dynamic tiling Wayland compositor with animations & keybinds |
| **Niri** | `northstar.features.niri.enable` | Scrollable-tiling Wayland compositor |
| **Noctalia** | `northstar.features.noctalia.enable` | Noctalia Wayland desktop shell |
| **Caelestia** | `northstar.features.caelestia.enable` | Caelestia desktop shell integration |
| **Display** | `northstar.features.display.enable` | Greetd login manager with `tuigreet` |
| **Audio** | `northstar.features.audio.enable` | PipeWire audio stack, Low-latency ALSA, and PulseAudio emu |
| **Bluetooth** | `northstar.features.bluetooth.enable` | BlueZ daemon + Blueman applet |
| **Firefox** | `northstar.features.firefox.enable` | Firefox web browser |
| **Zen Browser**| `northstar.features.zen-browser.enable` | Zen Browser flake integration |
| **Gaming** | `northstar.features.desktop.gaming.enable` | Steam, Gamemode, Gamescope, MangoHud, Wine, Lutris, controllers |
| **Power** | `northstar.features.power.enable` | UPower daemon + power-profiles-daemon |
| **udiskie** | `northstar.features.udiskie.enable` | Auto-mounting daemon for removable media & USB drives |
| **CUPS** | `northstar.features.cups.enable` | Printing support via CUPS daemon |

#### Development & AI/ML
| Module | Option | Description |
| :--- | :--- | :--- |
| **AI / ML** | `northstar.features.development.aiml.enable` | Ollama LLM server, PyTorch, Llama.cpp, JupyterLab, CUDA/ROCm SDKs |
| **DevTools** | `northstar.features.devtools.enable` | Compilers (GCC/Clang/Go/Rustup/Zig/JDK/Haskell) and LSPs |
| **Dev Defaults**| `northstar.features.dev.enable` | System-wide direnv, git, gpg, and `nix-ld` configuration |
| **Virtualization**| `northstar.features.virtualization.enable` | Docker, Libvirtd, QEMU/KVM, and Virt-Manager |
| **Emacs** | `northstar.features.emacs.enable` | Emacs daemon running under systemd |
| **Neovim** | `northstar.features.neovim.enable` | Curated Neovim editor configuration |
| **direnv** | `northstar.features.direnv.enable` | Per-directory automatic shell environments |
| **Git** | `northstar.features.git.enable` | Git configuration, aliases, and signing keys |

#### Shells, Terminals & CLI Tools
| Module | Option | Description |
| :--- | :--- | :--- |
| **Zsh** | `northstar.features.zsh.enable` | Zsh shell with plugins, autocompletions, and syntax highlighting |
| **Fish** | `northstar.features.fish.enable` | Fish shell with friendly prompt integrations |
| **Ghostty** | `northstar.features.ghostty.enable` | Ghostty GPU-accelerated terminal emulator |
| **Kitty** | `northstar.features.kitty.enable` | Kitty GPU-accelerated terminal emulator |
| **Starship** | `northstar.features.starship.enable` | Starship fast cross-shell prompt |
| **Oh My Posh**| `northstar.features.omp.enable` | Oh My Posh prompt theming engine |
| **Tmux** | `northstar.features.tmux.enable` | Tmux multiplexer with `tmux-powerkit` theme |
| **Yazi** | `northstar.features.yazi.enable` | Fast terminal file manager with image previews |
| **Eza** | `northstar.features.eza.enable` | Modern `ls` replacement with git status & icons |
| **Fzf** | `northstar.features.fzf.enable` | Fuzzy finder CLI integrations |
| **Zoxide** | `northstar.features.zoxide.enable` | Smarter `cd` command with memory-based navigation |

#### Hardware Acceleration & GPUs
| Module | Option | Description |
| :--- | :--- | :--- |
| **NVIDIA** | `northstar.nvidia.enable` | Proprietary NVIDIA drivers & CUDA support |
| **NVIDIA Prime**| `northstar.nvidia.prime.enable` | Hybrid graphics offload (NVIDIA discrete + Intel/AMD integrated) |
| **Prime Bus IDs**| `northstar.nvidia.prime.nvidiaBusId` / `intelBusId` / `amdgpuBusId` | PCI bus identifiers (auto-formatted as `PCI:X:Y:Z`) |

---

## 🛠️ Customizing a Host Configuration

Here is an example host configuration (`hosts/Makima/default.nix`):

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./disko.nix
  ];

  home-manager.users.reze = {
    imports = [ ../../home ];
    home.username = lib.mkForce "reze";
    home.homeDirectory = lib.mkForce "/home/reze";
  };

  # 1. Bootloader Selection (GRUB with DedSec theme, or modern Limine)
  northstar.features.boot.loader = "grub"; # or "limine"

  # Optional: Dual-boot chainloader entries
  boot.loader.grub.extraEntries = ''
    menuentry "Fedora Linux" {
      search --fs-uuid --set=root CB41-6695
      chainloader /EFI/fedora/shimx64.efi
    }
  '';

  # 2. User Accounts
  users.users.reze = {
    isNormalUser = true;
    description = "reze";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$6$example..."; # Generated via mkpasswd -m sha-512
  };

  # 3. Northstar Profile Presets
  northstar.profiles = {
    desktop.enable = true;
    workstation.enable = true;
    gaming.enable = true;
  };

  # 4. Granular Feature Overrides (Optional)
  northstar.features = {
    hyprland.enable = true;
    ghostty.enable = true;
    development.aiml.enable = true;
  };

  # 5. Hybrid GPU (NVIDIA Prime)
  northstar.nvidia.enable = true;
  northstar.nvidia.prime = {
    enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };

  networking.hostName = "Makima";
  system.stateVersion = "26.11";
}
```

---

## 🧪 Testing & Quality Assurance

Both the Rust TUI installer and Python installer are backed by automated unit and integration tests:

### Running the Rust Test Suite (21 Tests)
```bash
cargo test --manifest-path installer-rs/Cargo.toml
```

### Running the Python Test Suite (167 Tests)
```bash
python3 -m unittest discover tests
```

### Validating Flake Builds & Nix Evaluations
```bash
# Evaluate top-level system generation
nix eval --impure .#nixosConfigurations.Makima.config.system.build.toplevel.name

# Build the Rust installer package via Crane
nix build --impure .#rust-installer --no-link
```

---

## 📝 License
This project is licensed under the [MIT License](LICENSE).
