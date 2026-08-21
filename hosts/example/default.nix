# Example Northstar Host Configuration
#
# Copy this directory to create your own host:
#   cp -r hosts/example hosts/YourHostName
#
# Then:
#   1. Replace hardware.nix with your real hardware config:
#      sudo nixos-generate-config --show-hardware-config > hosts/YourHostName/hardware.nix
#   2. Customize default.nix below with your username, profiles, and GPU settings.
#   3. Build: sudo nixos-rebuild switch --flake .#YourHostName
#
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # ── User Account ──────────────────────────────────────────────────────
  # Create your user. Generate a hashed password with: mkpasswd -m sha-512
  users.users.youruser = {
    isNormalUser = true;
    description = "Your Name";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
    # hashedPassword = "$6$...";  # Generate with: mkpasswd -m sha-512
  };

  # ── Home Manager ──────────────────────────────────────────────────────
  home-manager.users.youruser = {
    imports = [ ../../home/home.nix ];
    home.username = lib.mkForce "youruser";
    home.homeDirectory = lib.mkForce "/home/youruser";
  };

  # ── Northstar Profiles ────────────────────────────────────────────────
  # Pick the profiles you need. base is always enabled via common.nix.
  northstar.profiles = {
    desktop.enable = true; # Graphical desktop (Hyprland, Niri, audio, etc.)
    # workstation.enable = true;  # Dev tools, shells, editors, containers
    # gaming.enable = true;       # Steam, Gamemode, Wine, controllers
  };

  # ── Optional: Granular Feature Overrides ──────────────────────────────
  # northstar.features = {
  #   hyprland.enable = true;
  #   development.aiml.enable = true;  # AI/ML suite (Ollama, PyTorch, etc.)
  # };

  # ── Optional: NVIDIA GPU ──────────────────────────────────────────────
  # northstar.nvidia.enable = true;
  # northstar.nvidia.prime = {
  #   enable = true;
  #   nvidiaBusId = "PCI:1:0:0";      # Find with: lspci | grep -i nvidia
  #   amdgpuBusId = "PCI:5:0:0";      # or intelBusId for Intel iGPU
  # };

  # ── Optional: Locale Override ─────────────────────────────────────────
  # time.timeZone = "America/New_York";

  # ── Optional: Bootloader ──────────────────────────────────────────
  # Limine is the default (and only) bootloader. Secure Boot via Lanzaboote:
  # northstar.features.boot.secureBoot.enable = true;

  networking.hostName = "example";
  system.stateVersion = "26.11";
}
