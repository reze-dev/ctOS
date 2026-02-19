{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common/base.nix
  ];

  home-manager.users.loid = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "loid";
    home.homeDirectory = lib.mkForce "/home/loid";
  };

  # User account — previously in nixos/users/loid.nix, now per-host
  users.users.loid = {
    isNormalUser = true;
    description = "Loid";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  # Nvidia GPU (this host has Nvidia + AMD hybrid)
  snowflake.nvidia = {
    enable = true;
    prime = {
      enable = true;
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };

  # Hardware-specific kernel params for this host
  boot.kernelParams = [ "i8042.nokbd" ];

  networking.hostName = "Yor";

  system.stateVersion = "26.05";
}
