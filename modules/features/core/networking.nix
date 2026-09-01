{ config, lib, ... }:
let
  cfg = config.ctos.features.networking;
in
{
  options.ctos.features.networking = {
    enable = lib.mkEnableOption "NetworkManager and host entries";

    extraHosts = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra entries appended to /etc/hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.extraHosts = cfg.extraHosts;
    networking.networkmanager.enable = true;
  };
}
