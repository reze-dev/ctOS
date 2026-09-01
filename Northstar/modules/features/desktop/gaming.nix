{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.desktop.gaming;
in
{
  imports = [
    (lib.mkAliasOptionModule
      [ "northstar" "features" "gaming" ]
      [ "northstar" "features" "desktop" "gaming" ]
    )
  ];

  options.northstar.features.desktop.gaming = {
    enable = lib.mkEnableOption "gaming workstation feature suite";

    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam digital distribution platform.";
      };

      remotePlay.openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open ports in the firewall for Steam Remote Play.";
      };

      dedicatedServer.openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for Source Dedicated Server.";
      };

      localNetworkGameTransfers.openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open ports in the firewall for Steam Local Network Game Transfers.";
      };

      gamescopeSession.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable GameScope driven Steam session.";
      };

      extraCompatPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ pkgs.proton-ge-bin ];
        description = "Extra compatibility packages for Steam (e.g. GE-Proton).";
      };

      protontricks.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Protontricks for managing Wine prefixes in Proton games.";
      };
    };

    gamemode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Feral Interactive GameMode daemon for optimizing system performance.";
      };

      enableRenice = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow GameMode to renice game processes to higher priority.";
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {
          general = {
            renice = 10;
          };
        };
        description = "Configuration settings for gamemode.ini.";
      };
    };

    gamescope = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Gamescope micro-compositor.";
      };

      capSysNice = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Grant CAP_SYS_NICE capability to Gamescope for real-time priority.";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Default arguments to pass to Gamescope.";
      };
    };

    mangohud = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable MangoHud overlay and Goverlay configuration tool.";
      };
    };

    wine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Wine Windows compatibility layer and Winetricks.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.wineWow64Packages.staging;
        description = "The Wine package to install (defaults to wineWow64Packages.staging).";
      };
    };

    lutris = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Lutris open gaming platform.";
      };
    };

    latencyTweaks = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply low-latency gaming kernel sysctl tweaks (vm.max_map_count, fs.file-max).";
      };
    };

    controllers = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable game controller hardware support and udev rules.";
      };

      xpadneo = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable xpadneo driver for Xbox One/Series Bluetooth wireless controllers.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # 32-bit OpenGL / Vulkan graphics acceleration
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Steam digital distribution platform
    programs.steam = lib.mkIf cfg.steam.enable {
      enable = true;
      remotePlay.openFirewall = cfg.steam.remotePlay.openFirewall;
      dedicatedServer.openFirewall = cfg.steam.dedicatedServer.openFirewall;
      localNetworkGameTransfers.openFirewall = cfg.steam.localNetworkGameTransfers.openFirewall;
      gamescopeSession.enable = cfg.steam.gamescopeSession.enable;
      extraCompatPackages = cfg.steam.extraCompatPackages;
      protontricks.enable = cfg.steam.protontricks.enable;
    };

    # Feral GameMode
    programs.gamemode = lib.mkIf cfg.gamemode.enable {
      enable = true;
      enableRenice = cfg.gamemode.enableRenice;
      settings = cfg.gamemode.settings;
    };

    # Gamescope micro-compositor
    programs.gamescope = lib.mkIf cfg.gamescope.enable {
      enable = true;
      capSysNice = cfg.gamescope.capSysNice;
      args = cfg.gamescope.args;
    };

    # Standalone Gaming Tools & Compatibility Packages
    environment.systemPackages =
      lib.optionals cfg.mangohud.enable [
        pkgs.mangohud
        pkgs.goverlay
      ]
      ++ lib.optionals cfg.wine.enable [
        cfg.wine.package
        pkgs.winetricks
      ]
      ++ lib.optionals cfg.lutris.enable [
        pkgs.lutris
      ];

    # Low-latency Kernel Tweaks
    boot.kernel.sysctl = lib.mkIf cfg.latencyTweaks.enable {
      "vm.max_map_count" = 2147483642;
      "fs.file-max" = 524288;
    };

    # Controllers & Game Hardware Support
    hardware.steam-hardware.enable = lib.mkIf cfg.controllers.enable true;
    services.udev.packages = lib.optionals cfg.controllers.enable [
      pkgs.game-devices-udev-rules
    ];
    hardware.xpadneo.enable = lib.mkIf (cfg.controllers.enable && cfg.controllers.xpadneo) true;
  };
}
