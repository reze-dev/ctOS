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

  boot.loader.grub.extraEntries = ''
    menuentry "Fedora" {
      search --fs-uuid --set=esp CB41-6695
      chainloader /EFI/fedora/shimx64.efi
    }
  '';

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
    hashedPassword = "$6$oXzrheHsEVSMJyV3$KzMdb2T8CHzGwcAlJqE3khEVfH/b5jFs/n5vNriwifcJ9mlgbsB221oILkizsjSYcFVJ5/kkYfjt8M2QFkkNl0";
  };

  #Northstar profiles
  northstar.profiles = {
    desktop.enable = true;
    workstation.enable = true;
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
