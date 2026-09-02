{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.greeter;
  ctosPackage = pkgs.callPackage ../../../shell/nix/package.nix { };
  greeterCommand = pkgs.writeShellScript "ctos-greeter-launch" ''
    set -u

    # greetd attaches the session to the VT, so child-process diagnostics are
    # otherwise effectively lost. Keep a readable copy for troubleshooting
    # from a TTY while retaining the normal VT output.
    log=/tmp/ctos-greeter.log
    : > "$log"
    exec >>"$log" 2>&1

    echo "ctOS greeter launcher: $(${pkgs.coreutils}/bin/date --iso-8601=seconds)"
    echo "uid=$(${pkgs.coreutils}/bin/id -u) gid=$(${pkgs.coreutils}/bin/id -g) runtime=''${XDG_RUNTIME_DIR-<unset>}"

    export CTOS_MODE=greetd
    export CTOS_DEBUG=1
    export QT_QPA_PLATFORM=wayland
    export XDG_SESSION_TYPE=wayland
    export XDG_RUNTIME_DIR=/run/user/999
    export HOME=/run/user/999
    export XDG_CACHE_HOME=/run/user/999/ctos-cache
    export XDG_CONFIG_HOME=/run/user/999/ctos-config
    ${pkgs.coreutils}/bin/mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"

    exec ${pkgs.cage}/bin/cage -D -d -s -m last -- \
      ${pkgs.quickshell}/bin/qs -vv --path ${ctosPackage}/share/ctos/greeter.qml
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
