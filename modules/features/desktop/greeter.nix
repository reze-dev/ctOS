{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.greeter;
  ctosPackage = pkgs.callPackage ../../../shell/nix/package.nix { };
  desktopCommand = pkgs.writeShellScript "ctos-start-hyprland" ''
    set -u



    exec ${config.programs.hyprland.package}/bin/start-hyprland
  '';
  greeterCommand = pkgs.writeShellScript "ctos-greeter-launch" ''
    set -u


    export CTOS_MODE=greetd
    export CTOS_LAUNCH_COMMAND=${desktopCommand}
    export QT_QPA_PLATFORM=wayland
    export XDG_SESSION_TYPE=wayland
    export XDG_RUNTIME_DIR=/run/user/999
    export HOME=/run/user/999
    export XDG_CACHE_HOME=/run/user/999/ctos-cache
    export XDG_CONFIG_HOME=/run/user/999/ctos-config
    ${pkgs.coreutils}/bin/mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"

    exec ${pkgs.cage}/bin/cage -s -m last -- \
      ${pkgs.quickshell}/bin/qs --path ${ctosPackage}/share/ctos/greeter.qml
  '';
in
{
  options.ctos.features.greeter.enable = lib.mkEnableOption "ctOS QML Greetd greeter";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ctos.features.display.enable;
        message = "ctos.features.greeter.enable requires ctos.features.display.enable";
      }
      {
        assertion = config.programs.hyprland.enable;
        message = "ctos.features.greeter.enable requires Hyprland for its desktop session";
      }
    ];

    environment.etc."ctos/greeter.config.json".text = builtins.toJSON {
      general = {
        fontFamily = "JetBrainsMono Nerd Font";
        animations = "all";
        monitor = "";
        exitOverride = [ ];
        launchOverride = [ "${desktopCommand}" ];
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

    # Settings persists the last greeter state here. greetd's built-in
    # greeter account has /var/empty as its home, so provision this directory
    # explicitly instead of allowing the first write to fail at runtime.
    systemd.tmpfiles.rules = [
      "d /var/lib/ctos 0755 greeter greeter -"
    ];

    services.greetd.settings.default_session = {
      command = lib.mkForce greeterCommand;
      user = "greeter";
    };
  };
}
