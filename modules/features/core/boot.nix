{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.boot;
in
{
  options.ctos.features.boot = {
    enable = lib.mkEnableOption "system bootloader and Plymouth splash";

    secureBoot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable UEFI Secure Boot support.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };

      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        dedsec-theme = {
          enable = true;
          style = "legion";
          icon = "color";
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
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
