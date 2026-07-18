<p align="center">
  <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="120" alt="NixOS Logo"/>
</p>

<h1 align="center">❄️ Northstar-nix</h1>

<p align="center">
  A premium, modular, option-driven NixOS & Home Manager configuration built on
  <a href="https://flake.parts">flake-parts</a>,
  <a href="https://github.com/nix-community/home-manager">Home Manager</a>, and
  <a href="https://github.com/nix-community/disko">disko</a>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos&logoColor=white" alt="NixOS Unstable"/>
  <img src="https://img.shields.io/badge/flake--parts-modular-5277C3?logo=nixos" alt="flake-parts"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>
</p>

---

## ✨ Key Features

- **🎛️ Toggle-based modularity** — every system and user module is isolated behind clean `northstar.<module>.enable` options.
- **📁 Auto-discovered configurations** — drop a host directory in `hosts/` or a module anywhere in `modules/` and it is dynamically detected and wired up.
- **🛠️ Automated USB Auto-mounting** — seamless external device detection, auto-mounting, and notifications inside minimal window managers via `udisks2`, `gvfs`, and `udiskie`.
- **💻 Decoupled Development Workspace** — all programming languages, compilers, LSPs, and developer tools are isolated into a standalone `devtools` workstation module.
- **🚀 Dual Installers** — features both a TUI-based async Rust installer (Ratatui + Tokio) and an interactive Python installer.
- **💾 Dual-boot & Partitioning** — supports full-disk partitioning via `disko` or partition-only dual-boot layouts with Btrfs subvolume integration.
- **🔄 Idempotency** — both installers save execution checkpoints to securely resume from where they left off in case of interruptions.

---

## 📂 Directory Structure

The repository is organized into distinct domain layers:

```
northstar/
├── flake.nix                   # Flake entry point (inputs, flake-parts wire-up)
├── flake.lock
│
├── flake/                      # flake-parts modules
│   ├── hosts.nix               # Host discovery & module exports
│   ├── installer.nix           # Python installer package definition
│   └── rust-installer.nix      # Rust TUI installer package definition
│
├── hosts/                      # Host machine configurations
│   ├── common.nix              # Common system base config
│   └── <hostname>/             # Per-machine system settings & hardware scans
│
├── lib/                        # Shared Nix helpers and templates
│   ├── default.nix             # Module/host discovery helpers
│   └── disko/
│       └── btrfs.nix           # Shared whole-disk Btrfs disko layout
│
├── home/
│   └── default.nix             # Home Manager profile entry point
│
├── modules/                    # Option-based module definitions
│   ├── features/               # Vertical feature slices
│   │   ├── core/               # Boot, env, fonts, locale, networking, packages, shells
│   │   ├── desktop/            # Audio, display/session, browsers, Hyprland, Noctalia
│   │   ├── development/        # Dev defaults, toolchains, git, Emacs, virtualization
│   │   ├── shell/              # Fish, Zsh, Starship, Oh My Posh
│   │   ├── terminals/          # Ghostty and Kitty
│   │   └── tools/              # Eza, Fzf, Tmux, Yazi, Zoxide
│   ├── hardware/               # Hardware-specific modules (NVIDIA, Prime)
│   └── profiles/               # Feature bundles (base, desktop, workstation)
│
├── installer-rs/               # Ratatui TUI installer source (Rust)
├── installer/                  # Python interactive installer source
└── assets/                     # Wallpaper and media assets
```

---

## 🚀 Quick Start

### 1. Installation from a NixOS Live USB
Before running the installers, export the flake feature flags:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

> [!TIP]
> **Option A (Recommended): Pre-built Rust Installer Binary (No Nix required)**
> ```bash
> curl -fsSL https://github.com/reze-dev/northstar/releases/latest/download/northstar-installer -o installer
> chmod +x installer && sudo ./installer
> ```

> [!NOTE]
> **Option B: Run Rust Installer via Nix**
> ```bash
> nix run github:reze-dev/northstar#rust-install
> ```

> [!NOTE]
> **Option C: Run Python Installer via Nix**
> ```bash
> nix run github:reze-dev/northstar
> ```

---

### 2. Post-installation Rebuilding
To apply configuration changes on an installed system:

```bash
cd ~/northstar
sudo nixos-rebuild switch --flake .#<hostname>
```

For example, for the `Makima` host:
```bash
sudo nixos-rebuild switch --flake .#Makima
```

---

## 🔧 Module Reference

### Feature Modules (`northstar.features.*`)

| Module | Option | Description |
| :--- | :--- | :--- |
| **Audio** | `northstar.features.audio.enable` | PipeWire audio stack & plugins |
| **Bluetooth** | `northstar.features.bluetooth.enable` | Bluetooth daemon + Blueman applet |
| **Boot** | `northstar.features.boot.enable` | GRUB bootloader styled with Dedsec theme |
| **CUPS** | `northstar.features.cups.enable` | Printing support (CUPS daemon) |
| **Dev** | `northstar.features.dev.enable` | System-wide direnv, git, gpg, and nix-ld configs |
| **DevTools** | `northstar.features.devtools.enable` | Languages, compilers (GCC/Clang/Go/Rustup/Zig/JDK/Haskell), and LSPs |
| **Display** | `northstar.features.display.enable` | Greetd with tuigreet + Niri compositor |
| **Emacs** | `northstar.features.emacs.enable` | Emacs daemon running under systemd |
| **Environment** | `northstar.features.env.enable` | Standard environment variables (EDITOR, VISUAL, etc.) |
| **Firefox** | `northstar.features.firefox.enable` | Firefox browser |
| **Fonts** | `northstar.features.fonts.enable` | Nerd Fonts collection |
| **Hyprland** | `northstar.features.hyprland.enable` | Hyprland Wayland compositor |
| **Locales** | `northstar.features.locales.enable` | Timezone, keyboard layout, and i18n locales |
| **Networking** | `northstar.features.networking.enable` | NetworkManager daemon + custom firewall settings |
| **NVIDIA** | `northstar.nvidia.enable` | Proprietary NVIDIA drivers |
| **NVIDIA Prime** | `northstar.nvidia.prime.enable` | Hybrid GPU offload settings (NVIDIA + Intel/AMD) |
| **Packages** | `northstar.features.packages.enable` | Curated base utility packages, `udisks2`, and `gvfs` |
| **Power** | `northstar.features.power.enable` | UPower daemon + power-profiles-daemon |
| **Shells** | `northstar.features.shells.enable` | Fish and Zsh system shells |
| **SSH** | `northstar.features.ssh.enable` | OpenSSH daemon |
| **Virtualization** | `northstar.features.virtualization.enable` | Libvirtd + QEMU/KVM + Docker daemon |
| **Ghostty** | `northstar.features.ghostty.enable` | Ghostty terminal configuration |
| **Kitty** | `northstar.features.kitty.enable` | Kitty terminal configuration |
| **Fish** | `northstar.features.fish.enable` | Fish shell, aliases, and plugin integrations |
| **Zsh** | `northstar.features.zsh.enable` | Zsh, Oh My Zsh, and customized plugins |
| **Git** | `northstar.features.git.enable` | Git user, aliases, and extra config |
| **Tmux** | `northstar.features.tmux.enable` | Tmux, shortcuts, and tmux-powerkit plugin |
| **Starship** | `northstar.features.starship.enable` | Starship shell prompt configuration |
| **Oh My Posh** | `northstar.features.omp.enable` | Oh My Posh shell prompt theme |
| **direnv** | `northstar.features.direnv.enable` | Per-directory shell environments |
| **fzf** | `northstar.features.fzf.enable` | Fzf fuzzy finder |
| **eza** | `northstar.features.eza.enable` | Eza modern `ls` alternative |
| **zoxide** | `northstar.features.zoxide.enable` | Zoxide quick jump `cd` alternative |
| **Yazi** | `northstar.features.yazi.enable` | Yazi terminal file manager + Quick-media jump (`g` + `m`) |
| **Noctalia** | `northstar.features.noctalia.enable` | Noctalia Wayland shell configuration |
| **udiskie** | `northstar.features.udiskie.enable` | udiskie auto-mount daemon for removable media |

---

## 🛠️ Customizing Modules

Modules can be enabled or disabled globally in `hosts/common.nix` or in your host-specific file:

```nix
# hosts/Makima/default.nix
northstar.features.cups.enable = false;          # Disable printing
northstar.features.kitty.enable = false;         # Disable Kitty configuration
```

### Adding a New Host Machine
1. Create a host directory:
   ```bash
   mkdir -p hosts/<hostname>
   ```
2. Create `default.nix` specifying imports, user details, and GPU options:
   ```nix
   { config, lib, pkgs, ... }:
   {
     imports = [ ./filesystems.nix ];  # or ./disko.nix for whole-disk setup
     
     home-manager.users.<username> = {
       imports = [ ../../home ];
       home.username = lib.mkForce "<username>";
       home.homeDirectory = lib.mkForce "/home/<username>";
     };

     users.users.<username> = {
       isNormalUser = true;
       description = "<username>";
       extraGroups = [ "networkmanager" "wheel" ];
       shell = pkgs.zsh;
       hashedPassword = "<hash>";  # Generated via: mkpasswd -m sha-512
     };

     networking.hostName = "<hostname>";
     system.stateVersion = "26.05";
   }
   ```
   For whole-disk installs, `hosts/<hostname>/disko.nix` should import the shared layout:
   ```nix
   {
     imports = [ ../../lib/disko/btrfs.nix ];
     disko.devices.disk.main.device = "/dev/nvme0n1";
   }
   ```
3. Generate hardware config scan:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware.nix
   ```
4. Build! Auto-discovery will automatically pick up the new host:
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

---

## 🔌 Reusing Modules in Other Flakes

Northstar feature modules are exported as a NixOS module set:

```nix
# Example external flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    northstar.url = "github:reze-dev/northstar";
  };

  outputs = { nixpkgs, northstar, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        northstar.nixosModules.default
        {
          northstar.features.hyprland.enable = true;
          northstar.features.audio.enable = true;
        }
      ];
    };
  };
}
```


---

## 🧊 Installer & Releases

### Rust TUI Installer
Built on [Ratatui](https://ratatui.rs) and [Tokio](https://tokio.rs), featuring:
- **Async Execution** — non-blocking operations with smooth progress widgets.
- **Self-Contained** — includes the entire configuration flake source at compile time using `include_dir!`.
- **JSON Checkpoints** — state serialization to save progress during power failure or reboots.

### CI/CD
GitHub Actions automatically builds and releases the Rust installer executable on version tags. It also runs checks on all pushes to `main`:
- ❄️ **Nix flake check** — `nix flake check`
- 🦀 **Rust quality assurance** — `cargo fmt`, `cargo clippy`, `cargo build`

---

## 📝 License
This project is licensed under the [MIT License](LICENSE).
