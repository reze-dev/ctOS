{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./filesystems.nix
  ];

  home-manager.users.reze = {
    imports = [ ../../home ];
    home.username = lib.mkForce "reze";
    home.homeDirectory = lib.mkForce "/home/reze";
  };

  # User account
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
    hashedPassword = "$6$zNbayJKO7FeS160q$nGXbt2SP1.3TzvUbGlOh3B9mcvbMG9CUjTwN5of7uHov7dCT1iN8ot0tbV/jazKRg6onGRk8D6Jxk3R5Bu.ma1";
  };

  # NVIDIA GPU
  cryonix.nvidia.enable = true;
  cryonix.nvidia.prime = {
    enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };

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
      useOSProber = true;
    };
  };

  networking.hostName = "Makima";

  system.stateVersion = "26.05";
}
