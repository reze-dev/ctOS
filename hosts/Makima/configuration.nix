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
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
      "kvm"
    ];
    shell = pkgs.zsh;
    hashedPassword = "$6$TNpl8IIaySZaN12R$gxxDmE63zbhtrD4DW3NCynxwUv0FugzawdLaD9twSROPTPruwl4EVssynOiHFwjqUcr11U6SXZS3o8.uRNhba0";
  };

  # NVIDIA GPU
  snowflake.nvidia.enable = true;

  # Hostname
  networking.hostName = "Makima";

  # Hardware-specific kernel params for this host
  boot.kernelParams = [ "i8042.nokbd" ];

  system.stateVersion = "26.05";
}
