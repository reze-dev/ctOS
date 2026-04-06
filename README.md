<p align="center">
  <img src="https://nixos.wiki/images/thumb/2/20/Home-nixos-logo.png/207px-Home-nixos-logo.png" width="100" alt="NixOS Logo"/>
</p>

<h1 align="center">❄️ Snowflake</h1>

<p align="center">
  A modular, option-driven NixOS configuration built with
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

## ✨ Features

- **Toggle-based modules** — every NixOS and Home Manager module is behind a `snowflake.*.enable` option
- **Auto-discovered hosts** — drop a directory in `hosts/` and it's wired up automatically
- **Two installers** — a Python interactive installer and a Rust binary with the entire flake embedded
- **Dual-boot support** — partition-only mode with btrfs subvolumes
- **Idempotent & resumable** — both installers save progress and can resume mid-install
- **Reusable modules** — import `snowflake.nixosModules.default` in your own flake

---

## 📂 Directory Structure

```
snowflake/
├── flake.nix                   # Flake entry — inputs + mkFlake via flake-parts
├── flake.lock
│
├── .github/workflows/
│   └── release.yml             # CI/CD — builds Rust installer + creates GitHub release
│
├── parts/                      # flake-parts modules (build logic)
│   ├── nixos.nix               # Host auto-discovery, module wiring, flake exports
│   ├── installer.nix           # Python installer package + app
│   └── rust-installer.nix      # Rust installer package + app
│
├── hosts/                      # Per-machine NixOS configurations
│   ├── common.nix              # Shared base — enables all snowflake.* modules
│   ├── disko.nix               # Disko partitioning template (whole-disk installs)
│   └── <hostname>/             # Each host gets its own directory
│       ├── default.nix         # Host-specific config (user, GPU, boot, etc.)
│       ├── hardware.nix        # Hardware scan output (nixos-generate-config)
│       └── filesystems.nix     # Filesystem mounts (dual-boot) or disko.nix (whole-disk)
│
├── home/
│   └── default.nix             # Home Manager profile — enables all snowflake.home.*
│
├── modules/                    # Pure option-based module declarations
│   ├── nixos/                  # System modules  → snowflake.<name>.enable
│   └── home/                   # User modules    → snowflake.home.<name>.enable
│
├── installer-rs/               # Rust installer source
│   ├── Cargo.toml / Cargo.lock
│   ├── src/                    # TUI, backend, embedded flake loader
│   └── flake/                  # Populated at build time with full flake source
│
├── assets/wallpapers/          # Wallpaper images
├── install.py                  # Python installer (legacy, still works)
└── README.md
```

---

## 🚀 Quick Start

### Fresh Install (from a NixOS live USB)

**Option A — Download pre-built binary** (no Nix required, recommended):

```bash
curl -fsSL https://github.com/atomiksan/snowflake/releases/latest/download/snowflake-installer -o snowflake-installer
chmod +x snowflake-installer
sudo ./snowflake-installer
```

**Option B — Via Nix** (Rust binary):

```bash
nix run github:atomiksan/snowflake#rust-install
```

**Option C — Via Nix** (Python installer):

```bash
nix run github:atomiksan/snowflake
```

Both installers will walk you through:

1. Hostname and username configuration
2. Password setup (securely hashed)
3. Installation mode — whole-disk (disko) or partition-only (dual-boot)
4. Disk and partition selection
5. Swap, filesystem, and GPU configuration
6. Partitioning, formatting, and NixOS installation
7. Copying the flake to your new system

### Rebuild After Installation

```bash
cd ~/snowflake
sudo nixos-rebuild switch --flake .#<hostname>
```

For example, for the `Makima` host:

```bash
sudo nixos-rebuild switch --flake .#Makima
```

---

## 🔧 Module Reference

### NixOS System Modules (`snowflake.*`)

| Module | Option | Description |
|--------|--------|-------------|
| Audio | `snowflake.audio.enable` | PipeWire audio stack |
| Bluetooth | `snowflake.bluetooth.enable` | Bluetooth + Blueman applet |
| Boot | `snowflake.boot.enable` | GRUB with Sekiro theme |
| CUPS | `snowflake.cups.enable` | Printing support |
| Dev | `snowflake.dev.enable` | direnv, git, gpg, neovim, nix-ld |
| Display | `snowflake.display.enable` | COSMIC greeter + niri compositor |
| Emacs | `snowflake.emacs.enable` | Emacs daemon |
| Environment | `snowflake.env.enable` | EDITOR/VISUAL environment vars |
| Firefox | `snowflake.firefox.enable` | Firefox browser |
| Fonts | `snowflake.fonts.enable` | Nerd Fonts collection |
| Hyprland | `snowflake.hyprland.enable` | Hyprland Wayland compositor |
| Locales | `snowflake.locales.enable` | Timezone + i18n settings |
| Networking | `snowflake.networking.enable` | NetworkManager + firewall |
| NVIDIA | `snowflake.nvidia.enable` | NVIDIA proprietary drivers |
| NVIDIA Prime | `snowflake.nvidia.prime.enable` | Hybrid GPU (NVIDIA + Intel/AMD) |
| Packages | `snowflake.packages.enable` | Curated system packages |
| Shells | `snowflake.shells.enable` | Fish + Zsh |
| SSH | `snowflake.ssh.enable` | OpenSSH server |
| Virtualization | `snowflake.virtualization.enable` | libvirtd + Docker |

### Home Manager Modules (`snowflake.home.*`)

| Module | Option | Description |
|--------|--------|-------------|
| Ghostty | `snowflake.home.ghostty.enable` | Ghostty terminal |
| Kitty | `snowflake.home.kitty.enable` | Kitty terminal |
| Fish | `snowflake.home.fish.enable` | Fish shell + plugins |
| Zsh | `snowflake.home.zsh.enable` | Zsh + Oh My Zsh |
| Git | `snowflake.home.git.enable` | Git configuration |
| Tmux | `snowflake.home.tmux.enable` | Tmux + powerkit |
| Starship | `snowflake.home.starship.enable` | Starship prompt |
| Oh My Posh | `snowflake.home.omp.enable` | Oh My Posh prompt theme |
| direnv | `snowflake.home.direnv.enable` | Per-directory environments |
| fzf | `snowflake.home.fzf.enable` | Fuzzy finder |
| eza | `snowflake.home.eza.enable` | Modern `ls` replacement |
| zoxide | `snowflake.home.zoxide.enable` | Smart `cd` |

### Toggling Modules

Disable any module from your host config or `common.nix`:

```nix
# hosts/<hostname>/default.nix or hosts/common.nix
snowflake.cups.enable = false;
snowflake.home.kitty.enable = false;
```

---

## 🏠 Adding a New Host

1. **Create the host directory:**

   ```bash
   mkdir -p hosts/<hostname>
   ```

2. **Create `default.nix`** with your user, password hash, and any host-specific settings:

   ```nix
   { config, lib, pkgs, ... }:
   {
     imports = [ ./filesystems.nix ];  # or ./disko.nix for whole-disk

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
       hashedPassword = "<hash>";  # mkpasswd -m sha-512
     };

     networking.hostName = "<hostname>";
     system.stateVersion = "26.05";
   }
   ```

3. **Generate `hardware.nix`:**

   ```bash
   nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware.nix
   ```

4. **Build:** The host is auto-discovered — no changes to `flake.nix` needed!

   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

> **Tip:** The installer generates all of this for you automatically. You only need to do this manually when setting up a host without the installer.

---

## 🔌 Using Modules in Another Flake

Snowflake exports its modules so you can use them in your own NixOS config:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    snowflake.url = "github:atomiksan/snowflake";
  };

  outputs = { nixpkgs, snowflake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        snowflake.nixosModules.default
        {
          snowflake.hyprland.enable = true;
          snowflake.audio.enable = true;
          snowflake.fonts.enable = true;
        }
      ];
    };
  };
}
```

Home Manager modules are also exported:

```nix
home-manager.sharedModules = [ snowflake.homeManagerModules.default ];
```

---

## 📦 Flake Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `nixpkgs` | `nixos-unstable` | NixOS package set |
| `flake-parts` | [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts) | Modular flake output composition |
| `home-manager` | [nix-community/home-manager](https://github.com/nix-community/home-manager) | Declarative user environment management |
| `disko` | [nix-community/disko](https://github.com/nix-community/disko) | Declarative disk partitioning |
| `nix-index-database` | [nix-community/nix-index-database](https://github.com/nix-community/nix-index-database) | Pre-built `nix-index` database |
| `zen-browser` | [0xc000022070/zen-browser-flake](https://github.com/0xc000022070/zen-browser-flake) | Zen Browser |
| `awww` | [LGFae/awww](https://codeberg.org/LGFae/awww) | Wallpaper daemon |
| `tmux-powerkit` | [fabioluciano/tmux-powerkit](https://github.com/fabioluciano/tmux-powerkit) | Tmux status line plugin |

---

## 🧊 Installer Details

### Rust Installer (`nix run .#rust-install`)

A compiled Rust binary built with [Ratatui](https://ratatui.rs) + [Tokio](https://tokio.rs). Features:

- Fully async TUI — all operations run on tokio, zero blocking
- Ratatui rendering with progress gauge, animated spinner, and streaming log
- Compile-time flake embedding via `include_dir!` — single self-contained binary
- Arrow-key wizard navigation with icy snow color theme
- Exponential backoff retry on failures
- JSON checkpoint state for resume after power loss

### Python Installer (`nix run .#install`)

The original interactive installer. It uses the same install flow but runs as a Python script with the flake source copied to a temp directory.

### Releases (CI/CD)

GitHub Actions automatically builds the Rust installer binary when you push a version tag:

```bash
git tag v3.0.0
git push origin v3.0.0
```

This triggers `.github/workflows/release.yml` which:

1. Populates `installer-rs/flake/`
2. Builds an optimized `snowflake-installer` binary
3. Creates a GitHub release with the binary attached

Download the binary on a NixOS live USB and run it — no Nix required:

```bash
curl -fsSL https://github.com/atomiksan/snowflake/releases/latest/download/snowflake-installer -o installer
chmod +x installer && sudo ./installer
```

CI also runs **2 parallel checks** on every push to `main`:
- 🧊 **Nix flake evaluation** — `nix flake check`
- 🦀 **Rust CI** — `cargo fmt`, `cargo clippy`, `cargo build`

---

## 📝 License

MIT
