{
  config,
  lib,
  pkgs,
  northstar,
  ...
}:

{
  imports = [
    ./filesystems.nix
    (northstar.mkUser {
      username = "reze";
      groups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "docker"
      ];
      shell = pkgs.zsh;
      extraConfig.hashedPassword = "$6$6VzoJUwHF0jvIr3V$UeSeDOI.6.JcC9CjxW26V0r0W0SeCos7Ne7/AWSxL1ACNb1.goIYDQAnn8K7ODSvyUKn9zfOc9996t.OXBTBX.";
    })
  ];

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
