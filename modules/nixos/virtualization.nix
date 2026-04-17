{ config, lib, ... }:
let cfg = config.northstar.virtualization;
in {
  options.northstar.virtualization.enable = lib.mkEnableOption "virtualization (libvirtd, Docker)";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    virtualisation.docker.enable = true;
  };
}
