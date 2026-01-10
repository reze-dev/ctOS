{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /data/kubevirt-vm-disks *(rw,sync,no_subtree_check,no_root_squash)
  '';

  networking.firewall.allowedTCPPorts = [
    111
    2049
    20048
  ];
  networking.firewall.allowedUDPPorts = [
    111
    2049
    20048
  ];
}
