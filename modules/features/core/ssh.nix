{ config, lib, ... }:
let
  cfg = config.ctos.features.ssh;
in
{
  options.ctos.features.ssh.enable = lib.mkEnableOption "OpenSSH daemon";

  config = lib.mkIf cfg.enable { services.openssh.enable = true; };
}
