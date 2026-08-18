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

    loader = lib.mkOption {
      type = lib.types.enum [
        "grub"
        "limine"
      ];
      default = "grub";
      description = "The bootloader to use (grub with DedSec theme, or modern Limine).";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };

      grub = lib.mkIf (cfg.loader == "grub") {
        enable = true;
        useOSProber = true;
        efiSupport = true;
        device = "nodev";

        dedsec-theme = {
          enable = true;
          style = "sitedown";
          icon = "color";
          resolution = "1080p";
        };
      };

      limine = lib.mkIf (cfg.loader == "limine") {
        enable = true;
      };
    };

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
