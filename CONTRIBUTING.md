# Contributing to Northstar

Thanks for your interest in contributing! This guide covers the development workflow.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- Add to `~/.config/nix/nix.conf`:
  ```
  experimental-features = nix-command flakes pipe-operators
  ```

## Development Shell

Enter the dev shell for formatting, linting, and test tools:

```bash
nix develop
```

This provides `nixfmt`, `nil` (Nix LSP), `python3`, `git`, and `jq`.

## Adding a New Host

1. Copy the example template:
   ```bash
   cp -r hosts/example hosts/YourHostName
   ```

2. Generate your hardware config:
   ```bash
   sudo nixos-generate-config --show-hardware-config > hosts/YourHostName/hardware.nix
   ```

3. Edit `hosts/YourHostName/default.nix` — set your username, profiles, GPU settings, etc.

4. Configure your disk layout in `hosts/YourHostName/disko.nix` using `mkDisko`.

5. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#YourHostName
   ```

The host is **auto-discovered** — any directory in `hosts/` with both `default.nix` and `hardware.nix` is automatically registered as a NixOS configuration.

## Adding a New Feature Module

1. Create a new `.nix` file in the appropriate `modules/features/<category>/` directory.

2. Follow the standard pattern:
   ```nix
   { config, lib, ... }:
   let
     cfg = config.northstar.features.yourfeature;
   in
   {
     options.northstar.features.yourfeature.enable =
       lib.mkEnableOption "description of your feature";

     config = lib.mkIf cfg.enable {
       # Your configuration here
     };
   }
   ```

3. The module is **auto-discovered** — `lib.scanModules` picks up any `.nix` file in `modules/` (except `default.nix` and files starting with `.` or `_`).

4. Optionally add it to a profile in `modules/profiles/`.

## Running Tests

```bash
# Nix-native checks (module syntax, lib tests, eval tests)
nix flake check --impure

# Python installer tests
python3 -m unittest discover -s tests -v

# Format check
nix fmt -- --check .
```

## Code Formatting

Format all Nix files:

```bash
nix fmt
```

We use `nixfmt-rfc-style` (the RFC 166 formatter).

## PR Workflow

1. Create a feature branch: `git checkout -b feat/your-feature`
2. Make your changes
3. Run `nix fmt` to format
4. Run `nix flake check --impure` to verify
5. Commit and push
6. Open a PR against `main`

## Directory Structure

```
northstar/
├── flake.nix              # Flake entry point
├── flake/                 # flake-parts modules (hosts, installer, checks, devshell, formatter)
├── hosts/                 # Host machine configs (auto-discovered)
│   ├── common.nix         # Shared base config
│   ├── example/           # Template for new hosts
│   └── <hostname>/        # Per-machine config
├── home/
│   └── home.nix           # Base Home Manager user environment
├── lib/
│   ├── core.nix           # Shared Nix helpers (scanModules, discoverHosts, mkDisko, mkUser, mkProfile)
│   └── disko/
│       └── generator.nix  # Dynamic mkDisko partition generator
├── modules/               # Option-based modules (auto-discovered)
│   ├── features/          # Vertical feature slices (core, desktop, dev, shell, terminals, tools)
│   ├── hardware/          # Hardware drivers (NVIDIA)
│   └── profiles/          # Composable feature bundles (base, desktop, workstation, gaming)
├── installer/             # Python interactive installer
├── tests/                 # Python test suites
└── assets/                # Themes and media
```
