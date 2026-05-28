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
    hashedPassword = "$6$6VzoJUwHF0jvIr3V$UeSeDOI.6.JcC9CjxW26V0r0W0SeCos7Ne7/AWSxL1ACNb1.goIYDQAnn8K7ODSvyUKn9zfOc9996t.OXBTBX.";
  };

  # NVIDIA GPU
  northstar.nvidia.enable = true;
  northstar.nvidia.prime = {
    enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };

  networking.hostName = "Makima";

  boot.loader.grub.extraEntries = ''
    menuentry "Kali Linux" --class kali --class gnu-linux --class os {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --fs-uuid --set=esp 238D-76D7
      chainloader ($esp)/EFI/kali/grubx64.efi
    }
  '';

  system.stateVersion = "26.05";
}
