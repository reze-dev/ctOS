{ config, lib, ... }:
let cfg = config.northstar.ssh;
in {
  options.northstar.ssh.enable = lib.mkEnableOption "OpenSSH daemon";

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
  };
}
