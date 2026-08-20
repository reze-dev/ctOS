# Stub hardware configuration
#
# Replace this file with your real hardware config:
#   sudo nixos-generate-config --show-hardware-config > hosts/YourHostName/hardware.nix
#
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # These will be filled in by nixos-generate-config
  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
