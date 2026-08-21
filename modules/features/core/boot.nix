{
  config,
  inputs ? null,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.boot;
in
{
  imports = lib.optionals (inputs != null && inputs ? lanzaboote) [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  options.northstar.features.boot = {
    enable = lib.mkEnableOption "system bootloader and Plymouth splash";

    secureBoot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable UEFI Secure Boot support using Lanzaboote.";
      };

      pkiBundle = lib.mkOption {
        type = lib.types.str;
        default = "/etc/secureboot";
        description = "Path to the Lanzaboote Secure Boot PKI keys and certificates directory.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        boot.loader = {
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot/efi";
          };

          limine = lib.mkIf (!cfg.secureBoot.enable) {
            enable = true;
          };

          systemd-boot.enable = lib.mkIf cfg.secureBoot.enable (lib.mkForce false);
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
      }
      (lib.optionalAttrs (inputs != null && inputs ? lanzaboote) {
        boot.lanzaboote = lib.mkIf cfg.secureBoot.enable {
          enable = true;
          pkiBundle = cfg.secureBoot.pkiBundle;
        };
      })
    ]
  );
}
