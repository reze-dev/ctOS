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

  home-manager.users.reze = {
    imports = [ ../../home/home.nix ];
    home.username = lib.mkForce "reze";
    home.homeDirectory = lib.mkForce "/home/reze";
  };

  # Bootloader (Limine)
  boot.loader.limine.resolution = "1920x1080";
  northstar.features.boot.secureBoot.enable = true;

  users.users.reze = {
    isNormalUser = true;
    description = "reze";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.zsh;
    hashedPassword = "$6$YfUG.LRzZA/7Lki7$Le4p6A.Wm8TJvZTMdWHUpeixcQ.fiTeeNfuvAcINk1aG1g6ZDFcR//2KEw6um9/dgOAitIigZZFMo4Ybnxqf40";
  };

  # Northstar profiles
  northstar.profiles = {
    desktop.enable = true;
    workstation.enable = true;
  };

  # Custom feature overrides
  northstar.features = {
    niri.enable = true;
    fish.enable = true;
    emacs.enable = true;
  };

  # NVIDIA GPU
  northstar.nvidia.enable = true;
  northstar.nvidia.prime = {
    enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };

  networking.hostName = "Makima";
  system.stateVersion = "26.11";
}
