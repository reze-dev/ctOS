{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./filesystems.nix
    ../common/base.nix
  ];

  home-manager.users.atomik = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "atomik";
    home.homeDirectory = lib.mkForce "/home/atomik";
  };

  # User account
  users.users.atomik = {
    isNormalUser = true;
    description = "atomik";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$6$TNpl8IIaySZaN12R$gxxDmE63zbhtrD4DW3NCynxwUv0FugzawdLaD9twSROPTPruwl4EVssynOiHFwjqUcr11U6SXZS3o8.uRNhba0";
  };

  # NVIDIA GPU
  snowflake.nvidia.enable = true;

  # Boot — use existing EFI bootloader (dual-boot safe)
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;  # Detect Windows and other OSes
    };
  };

  # Hostname
  networking.hostName = "Makima";

  system.stateVersion = "26.05";
}
