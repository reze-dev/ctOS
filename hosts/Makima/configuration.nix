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

  home-manager.users.Reze = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "Reze";
    home.homeDirectory = lib.mkForce "/home/Reze";
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  # User account
  users.users.Reze = {
    isNormalUser = true;
    description = "Reze";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.zsh;
    hashedPassword = "$6$w6d6g8tYaUXmoN8U$Dfavhm1Na0BsH4Cl2ZLXZSlfewRmXRacTfa3bfAICm2h7sykp7A6Q6h9MlmU86N8T0mOoTRFf3RQol3cz6TJM1";
  };

  # NVIDIA GPU
  snowflake.nvidia.enable = true;
  snowflake.nvidia.prime = {
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
      useOSProber = true; # Detect Windows and other OSes
    };
  };

  # Hostname
  networking.hostName = "Makima";

  system.stateVersion = "26.05";
}
