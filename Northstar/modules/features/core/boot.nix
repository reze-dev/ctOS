{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.boot;
in
{
  options.northstar.features.boot = {
    enable = lib.mkEnableOption "system bootloader and Plymouth splash";

    secureBoot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable UEFI Secure Boot support using Limine native Secure Boot.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };

      limine = {
        enable = true;
        secureBoot = {
          enable = cfg.secureBoot.enable;
          autoGenerateKeys = lib.mkDefault true;
        };
      };
    };

    environment.systemPackages = lib.optionals cfg.secureBoot.enable [
      pkgs.sbctl
    ];

    boot.plymouth = {
      enable = true;
      theme = "dedsec";

      themePackages = [
        (pkgs.stdenv.mkDerivation {
          pname = "dedsec-plymouth";
          version = "1.0";

          src = ../../../assets/dedsec-plymouth;

          installPhase = ''
            mkdir -p $out/share/plymouth/themes/dedsec
            cp * $out/share/plymouth/themes/dedsec/
          '';
        })
      ];
    };
    boot.initrd.systemd.enable = true;
    boot.kernelParams = [
      "quiet"
      "udev.log_priority=3"
    ];
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
