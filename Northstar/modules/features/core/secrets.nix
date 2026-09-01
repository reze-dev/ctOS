{
  config,
  inputs ? null,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.secrets;
in
{
  imports = [
    (lib.mkAliasOptionModule
      [ "northstar" "features" "core" "secrets" ]
      [ "northstar" "features" "secrets" ]
    )
  ]
  ++ lib.optionals (inputs != null && inputs ? sops-nix) [
    inputs.sops-nix.nixosModules.sops
  ];

  options.northstar.features.secrets = {
    enable = lib.mkEnableOption "sops-nix and age secret management";

    defaultSopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Default sops file containing encrypted secrets.";
    };

    defaultSopsFormat = lib.mkOption {
      type = lib.types.enum [
        "yaml"
        "json"
        "ini"
        "dotenv"
        "binary"
      ];
      default = "yaml";
      description = "Default format of the sops file.";
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/var/lib/sops-nix/key.txt";
      description = "Path to the age secret key file used by sops-nix for decrypting secrets.";
    };

    sshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/etc/ssh/ssh_host_ed25519_key" ];
      description = "Paths to SSH host private keys used to derive age keys or decrypt secrets.";
    };

    generateKey = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to automatically generate an age key file from SSH host key if it does not exist.";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Secret definitions forwarded directly to sops.secrets.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = [
          pkgs.sops
          pkgs.age
          pkgs.ssh-to-age
        ];
      }
      (lib.optionalAttrs (inputs != null && inputs ? sops-nix) {
        sops = {
          defaultSopsFile = lib.mkIf (cfg.defaultSopsFile != null) cfg.defaultSopsFile;
          defaultSopsFormat = cfg.defaultSopsFormat;
          age = {
            keyFile = lib.mkIf (cfg.ageKeyFile != null) cfg.ageKeyFile;
            sshKeyPaths = cfg.sshKeyPaths;
            generateKey = cfg.generateKey;
          };
          secrets = lib.mkIf (cfg.secrets != { }) cfg.secrets;
        };
      })
    ]
  );
}
