{ config, lib, ... }:
let cfg = config.snowflake.ssh;
in {
  options.snowflake.ssh.enable = lib.mkEnableOption "OpenSSH daemon";

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
  };
}
