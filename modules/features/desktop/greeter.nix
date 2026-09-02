{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.greeter;
  ctosPackage = pkgs.callPackage ../../../shell/nix/package.nix { };
  greeterCommand = lib.concatStringsSep " " [
    "${pkgs.coreutils}/bin/env"
    "CTOS_MODE=greetd"
    "QT_QPA_PLATFORM=wayland"
    "${pkgs.cage}/bin/cage"
    "-D"
    "-d"
    "-s"
    "-m"
    "last"
    "--"
    "${pkgs.quickshell}/bin/qs"
    "-vv"
    "--path"
    "${ctosPackage}/share/ctos/greeter.qml"
  ];
in
{
  options.ctos.features.greeter.enable = lib.mkEnableOption "ctOS QML Greetd greeter";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ctos.features.display.enable;
        message = "ctos.features.greeter.enable requires ctos.features.display.enable";
      }
    ];

    environment.etc."ctos/greeter.config.json".text = builtins.toJSON {
      general = {
        fontFamily = "JetBrainsMono Nerd Font";
        animations = "all";
        monitor = "";
        exitOverride = [ ];
        launchOverride = [ ];
        modes = {
          greetd = {
            animations = "all";
            monitor = "";
          };
          lockd = {
            animations = "reduced";
            monitor = "";
          };
          test = {
            animations = "all";
            monitor = "";
          };
        };
      };
    };

    services.greetd.settings.default_session = {
      command = lib.mkForce greeterCommand;
      user = "greeter";
    };
  };
}
