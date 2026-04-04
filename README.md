# ❄️ Snowflake

A modular NixOS configuration built with [flake-parts](https://flake.parts), [Home Manager](https://github.com/nix-community/home-manager), and [disko](https://github.com/nix-community/disko).

## Structure

```
snowflake/
├── flake.nix                 # Flake entry — inputs + mkFlake
├── parts/
│   ├── nixos.nix             # Host discovery, module wiring, flake exports
│   └── installer.nix         # Installer package + app
├── hosts/
│   ├── common.nix            # Shared base — enables all snowflake.* modules
│   ├── disko.nix             # Disko partition template
│   └── Makima/               # Host: Makima (dual-boot, NVIDIA Prime)
├── home.nix                  # Home Manager profile — enables all snowflake.home.*
├── modules/                  # Pure option declarations only
│   ├── nixos/                # snowflake.<name>.enable
│   └── home/                 # snowflake.home.<name>.enable
├── assets/wallpapers/        # Wallpaper images
└── install.sh                # Interactive installer
```

## Usage

### Rebuild system

```bash
sudo nixos-rebuild switch --flake .#Makima
```

### Toggle a module

```nix
# In your host config
snowflake.cups.enable = false;
snowflake.home.kitty.enable = false;
```

### Add a new host

1. Create `hosts/<hostname>/` with `default.nix` and `hardware.nix`
2. Auto-discovered — no flake.nix changes needed

### Use modules in another flake

```nix
{
  inputs.snowflake.url = "github:atomiksan/snowflake";

  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    modules = [ snowflake.nixosModules.default ];
  };
}
```

### Run installer

```bash
nix run github:atomiksan/snowflake
```

## NixOS Modules (`snowflake.*`)

| Module | Description |
|--------|-------------|
| `audio` | PipeWire |
| `bluetooth` | Bluetooth + Blueman |
| `boot` | GRUB + Sekiro theme |
| `cups` | Printing |
| `dev` | direnv, git, gpg, neovim, nix-ld |
| `display` | COSMIC + niri |
| `emacs` | Emacs daemon |
| `env` | EDITOR/VISUAL vars |
| `firefox` | Firefox browser |
| `fonts` | Nerd Fonts |
| `hyprland` | Hyprland WM |
| `locales` | Timezone + i18n |
| `networking` | NetworkManager |
| `nvidia` | NVIDIA + Prime |
| `packages` | System packages |
| `shells` | Fish + Zsh |
| `ssh` | OpenSSH |
| `virtualization` | libvirtd + Docker |

## Home Modules (`snowflake.home.*`)

`ghostty` · `kitty` · `fish` · `zsh` · `git` · `tmux` · `starship` · `omp` · `direnv` · `fzf` · `eza` · `zoxide`

## Inputs

| Input | Description |
|-------|-------------|
| `nixpkgs` | NixOS unstable |
| `flake-parts` | Flake output composition |
| `home-manager` | Declarative user config |
| `disko` | Declarative disk partitioning |
| `nix-index-database` | Pre-built nix-index DB |
| `zen-browser` | Zen Browser |
| `awww` | Wallpaper daemon |
| `tmux-powerkit` | Tmux plugin |
