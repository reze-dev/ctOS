{ config, lib, ... }:
let
  cfg = config.northstar.networking;
in
{
  options.northstar.networking.enable = lib.mkEnableOption "NetworkManager and host entries";

  config = lib.mkIf cfg.enable {
    networking.extraHosts = ''
      10.250.18.140 console-openshift-console.apps.nonprod.odisha.gov.in oauth-openshift.apps.nonprod.odisha.gov.in
    '';

    networking.networkmanager.enable = true;
  };
}
