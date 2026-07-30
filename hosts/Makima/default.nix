{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./disko.nix
  ];

  home-manager.users.reze = {
    imports = [ ../../home ];
    home.username = lib.mkForce "reze";
    home.homeDirectory = lib.mkForce "/home/reze";
  };

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
    hashedPassword = "$6$Fbr/jW8KWBKk15qS$vYqAkhbPbRZ0XQ7gbEZWYF.1qQRauhfKwXKPhAjJiSdpzU1ChjpBl34E.Lup6glq2rjVLdB6glr7RHC9bjHBV1";
  };

  northstar.profiles = {
    desktop.enable = true;
    workstation.enable = true;
  };

  # NVIDIA GPU
  northstar.nvidia.enable = true;
  northstar.nvidia.prime = {
    enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:0:2:0";
  };

  networking.hostName = "Makima";
  system.stateVersion = "26.11";
}
