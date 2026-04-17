{ config, lib, ... }:
let cfg = config.northstar.networking;
in {
  options.northstar.networking.enable = lib.mkEnableOption "NetworkManager and host entries";

  config = lib.mkIf cfg.enable {
    networking.extraHosts = ''
      34.57.215.58 console-openshift-console.apps.ocp.ocp-lab.satyabrata.net oauth-openshift.apps.ocp.ocp-lab.satyabrata.net
    '';

    networking.networkmanager.enable = true;
  };
}
