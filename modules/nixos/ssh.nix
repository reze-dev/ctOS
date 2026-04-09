{ config, lib, ... }:
let cfg = config.cryonix.ssh;
in {
  options.cryonix.ssh.enable = lib.mkEnableOption "OpenSSH daemon";

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
  };
}
