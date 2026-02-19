{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.snowflake.nvidia;
in
{
  options.snowflake.nvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU drivers";

    prime = {
      enable = lib.mkEnableOption "NVIDIA Prime (hybrid GPU) support";

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "PCI Bus ID of the NVIDIA GPU (e.g., PCI:1:0:0)";
      };

      intelBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "PCI Bus ID of the Intel iGPU (e.g., PCI:0:2:0)";
      };

      amdgpuBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "PCI Bus ID of the AMD iGPU (e.g., PCI:5:0:0)";
      };
    };

    openKernelModule = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use NVIDIA open source kernel module (Turing+ only)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable OpenGL
    hardware.graphics.enable = true;

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = cfg.openKernelModule;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;

      prime = lib.mkIf cfg.prime.enable {
        sync.enable = true;
        nvidiaBusId = cfg.prime.nvidiaBusId;
        intelBusId = lib.mkIf (cfg.prime.intelBusId != "") cfg.prime.intelBusId;
        amdgpuBusId = lib.mkIf (cfg.prime.amdgpuBusId != "") cfg.prime.amdgpuBusId;
      };
    };
  };
}
