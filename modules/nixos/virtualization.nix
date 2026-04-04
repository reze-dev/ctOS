{ config, lib, ... }:
let cfg = config.snowflake.virtualization;
in {
  options.snowflake.virtualization.enable = lib.mkEnableOption "virtualization (libvirtd, Docker)";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    virtualisation.docker.enable = true;
  };
}
