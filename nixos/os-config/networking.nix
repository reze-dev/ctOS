{
  config,
  lib,
  pkgs,
  ...
}:

{
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  networking.extraHosts = ''
    # 192.168.122.216 gitlab.internal
    # 192.168.122.56 jenkins.internal
  '';

  # Enable networking
  networking.networkmanager.enable = true;
}
