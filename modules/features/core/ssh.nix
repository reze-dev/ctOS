{ config, lib, ... }:
let
  cfg = config.northstar.features.ssh;
in
{
  options.northstar.features.ssh.enable = lib.mkEnableOption "OpenSSH daemon";

  config = lib.mkIf cfg.enable { services.openssh.enable = true; };
}
