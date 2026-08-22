<p align="center">
  <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="120" alt="NixOS Logo"/>
</p>

<h1 align="center">❄️ Northstar</h1>

<p align="center">
  A modular, option-driven NixOS & Home Manager configuration built on
  <a href="https://flake.parts">flake-parts</a>,
  <a href="https://github.com/nix-community/home-manager">Home Manager</a>,
  <a href="https://github.com/nix-community/disko">disko</a>, and modern
  <b>Pipe Operators</b> (<code>|&gt;</code>).
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos&logoColor=white" alt="NixOS Unstable"/>
  <img src="https://img.shields.io/badge/flake--parts-modular-5277C3?logo=nixos" alt="flake-parts"/>
  <img src="https://img.shields.io/badge/experimental-pipe--operators-orange" alt="Pipe Operators"/>
  <img src="https://img.shields.io/badge/secure--boot-limine-success" alt="Limine Secure Boot"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>
</p>

---

## ✨ Key Features

- **🎛️ Toggle-based modularity** — every module is behind `northstar.<domain>.<feature>.enable` options
- **⚡ Pipe Operator Composition** — leverages native `pipe-operators` (`|>`) for clean functional transformations
- **📁 Auto-discovery** — drop a host directory in `hosts/` or a module in `modules/` and it's automatically wired up
- **🛡️ UEFI Secure Boot** — native Secure Boot via Limine as the sole UEFI bootloader
- **💾 Dynamic Disko** — `mkDisko` generates partition configs for whole-disk or dual-boot layouts with Btrfs/Ext4
- **🤖 AI/ML & Gaming** — out-of-the-box modules for Ollama, PyTorch, CUDA/ROCm, Steam, Gamescope, and more
- **🔐 Secrets Management** — integrated sops-nix & age key management
- **🚀 Interactive Installer** — Python-based installer with hardware detection and guided setup

---

## 🚀 Quick Start

### Fresh Install from NixOS Live USB

```bash
# Enable experimental features
export NIX_CONFIG="experimental-features = nix-command flakes pipe-operators"

# Run the installer
nix run github:reze-dev/northstar --impure
```

### Adding a Host

```bash
# Clone the repo locally
git clone https://github.com/reze-dev/northstar ~/northstar
cd ~/northstar

# Run the interactive installer (creates hosts/<hostname> automatically)
nix run . --impure

# Build and switch to your host
sudo nixos-rebuild switch --flake .#<hostname>
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide on adding hosts and modules.

### Day-to-Day Workflow

```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake .#<hostname>

# Update all flake inputs
nix flake update

# Format code
nix fmt

# Run checks
nix flake check --impure
```

---

## 📂 Directory Structure

```
northstar/
├── flake.nix                  # Flake entry point (inputs + flake-parts wire-up)
├── flake/                     # flake-parts modules
│   ├── hosts.nix              # Host discovery & nixosConfigurations
│   ├── installer.nix          # Python installer package
│   ├── checks.nix             # Nix-native test checks
│   ├── devshell.nix           # Development shell
│   └── formatter.nix          # Code formatter (nixfmt-rfc-style)
│
├── hosts/                     # Host machine configurations (auto-discovered)
│   ├── common.nix             # Shared base config (flakes, HM, nix-index)
│   └── <hostname>/            # Per-machine config
│       ├── default.nix        # Host entry point (users, profiles, GPU)
│       ├── disko.nix          # Declarative partition scheme
│       └── hardware.nix       # Hardware scan (from nixos-generate-config)
│
├── lib/                       # Shared Nix helpers
│   ├── core.nix               # scanModules, discoverHosts, mkProfile, mkUser, mkDisko
│   └── disko/
│       └── generator.nix      # Dynamic mkDisko partition generator
│
├── home/
│   └── home.nix               # Base Home Manager user environment
│
├── modules/                   # Option-based modules (auto-discovered)
│   ├── features/              # Vertical feature slices
│   │   ├── core/              # Boot, env, fonts, locale, networking, packages, shells, secrets
│   │   ├── desktop/           # Audio, display, browsers, Hyprland, Niri, Noctalia, Gaming, desktop packages
│   │   ├── development/       # Dev tools, AI/ML, git, Emacs, virtualization
│   │   ├── shell/             # Fish, Zsh, Starship
│   │   ├── terminals/         # Ghostty, Kitty
│   │   └── tools/             # Eza, Fzf, Tmux, Yazi, Zoxide
│   ├── hardware/              # Hardware drivers (NVIDIA, Prime)
│   └── profiles/              # Composable feature bundles
│
├── installer/                 # Python interactive installer
├── tests/                     # Python test suites
└── assets/                    # DedSec Plymouth splash, wallpapers
```

---

## 🎛️ Profiles & Feature Bundles

Profiles are composable feature bundles. Enable them in your host config:

```nix
northstar.profiles = {
  desktop.enable = true;
  workstation.enable = true;
};
```

| Profile | Description |
| :--- | :--- |
| **Base** | Minimal system (boot, networking, SSH, neovim, shells, fonts, locales) — always enabled |
| **Desktop** | Full graphical workstation (Audio, Bluetooth, Hyprland, Niri, Noctalia, browsers, etc.) |
| **Workstation** | Developer tools, shells, editors, containers, virtualization |
| **Gaming** | Steam, Gamemode, Gamescope, MangoHud, Wine/Proton, Lutris, controllers |

---

## 🔧 Module Reference

### Core & System (`northstar.features.*`)
| Module | Description |
| :--- | :--- |
| `boot` | Bootloader (Limine), Plymouth splash, Secure Boot (Limine) |
| `networking` | NetworkManager + configurable `/etc/hosts` |
| `locales` | Timezone, keyboard, i18n |
| `fonts` | Curated Nerd Fonts |
| `packages` | Base system utilities |
| `ssh` | OpenSSH daemon |
| `env` | Environment variables (EDITOR, VISUAL, BROWSER) |
| `secrets` | sops-nix & age secret management |

### Desktop (`northstar.features.*`)
| Module | Description |
| :--- | :--- |
| `hyprland` | Dynamic tiling Wayland compositor |
| `niri` | Scrollable-tiling Wayland compositor |
| `noctalia` | Noctalia Wayland shell |
| `caelestia` | Caelestia desktop shell |
| `display` | Greetd login manager with tuigreet |
| `audio` | PipeWire audio stack |
| `bluetooth` | BlueZ + Blueman |
| `firefox` / `zen-browser` | Web browsers |
| `gaming` | Steam, Gamemode, Gamescope, Wine, Lutris |
| `xdg` | XDG portals & MIME associations |
| `desktopPackages` | Wayland/GUI desktop utilities (polkit, clipboard, screenshot, file manager) |

### Development (`northstar.features.*`)
| Module | Description |
| :--- | :--- |
| `dev` | direnv, git, gpg, nix-ld |
| `devtools` | Compilers (GCC, Clang, Go, Rust, Zig, JDK, Haskell) & LSPs |
| `development.aiml` | Ollama, PyTorch, Llama.cpp, JupyterLab, CUDA/ROCm |
| `virtualization` | Docker, Libvirtd, QEMU/KVM |
| `emacs` | Emacs daemon |

### Hardware (`northstar.nvidia.*`)
| Option | Description |
| :--- | :--- |
| `enable` | Proprietary NVIDIA drivers |
| `prime.enable` | Hybrid GPU (NVIDIA + Intel/AMD) |
| `prime.nvidiaBusId` / `intelBusId` / `amdgpuBusId` | PCI bus IDs |

---

## 💾 Disk Configuration (mkDisko)

Northstar provides `mkDisko` for declarative disk layouts:

```nix
# Whole-disk (wipes entire drive)
northstar.mkDisko {
  mode = "whole-disk";
  device = "/dev/nvme0n1";
  fsType = "btrfs";         # or "ext4"
  efiSize = "2G";           # 2GB default — safe for Limine + many NixOS generations
  swapSize = "16G";          # default 16G — "0" to disable
}

# Partition-only (dual-boot safe)
northstar.mkDisko {
  mode = "partition-only";
  nixosPart = "/dev/nvme0n1p4";
  efiDevice = "/dev/disk/by-uuid/XXXX-XXXX";
  fsType = "btrfs";
  swapSize = "16G";
}
```

---

## 🧪 Testing

```bash
# Nix-native checks (module syntax, lib tests, eval tests)
nix flake check --impure

# Python installer tests
python3 -m unittest discover -s tests -v

# Evaluate host configuration
nix eval --impure .#nixosConfigurations.Makima.config.system.build.toplevel.name
```

---

## 📝 License
This project is licensed under the [MIT License](LICENSE).
