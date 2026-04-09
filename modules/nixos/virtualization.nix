{ config, lib, ... }:
let cfg = config.cryonix.virtualization;
in {
  options.cryonix.virtualization.enable = lib.mkEnableOption "virtualization (libvirtd, Docker)";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    virtualisation.docker.enable = true;
  };
}
