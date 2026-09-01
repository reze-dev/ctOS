{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.development.aiml;

  # Hardware acceleration resolution
  effectiveBackend =
    if cfg.acceleration == "auto" then
      (if config.northstar.nvidia.enable or false then "cuda" else "none")
    else
      cfg.acceleration;

  # Ollama acceleration backend resolution
  effectiveOllamaBackend =
    if cfg.ollama.acceleration != null then
      cfg.ollama.acceleration
    else if effectiveBackend == "cuda" then
      "cuda"
    else if effectiveBackend == "rocm" then
      "rocm"
    else
      "none";

  # Dynamic Ollama package selection for modern nixpkgs
  resolvedOllamaPackage =
    if cfg.ollama.package != null then
      cfg.ollama.package
    else if effectiveOllamaBackend == "cuda" then
      pkgs.ollama-cuda
    else if effectiveOllamaBackend == "rocm" then
      pkgs.ollama-rocm
    else if effectiveOllamaBackend == "vulkan" then
      pkgs.ollama-vulkan
    else
      pkgs.ollama;

  # PyTorch backend flags
  effectivePytorchCuda = cfg.pytorch.cuda || (effectiveBackend == "cuda");
  effectivePytorchRocm = cfg.pytorch.rocm || (effectiveBackend == "rocm");

  # PyTorch package selection
  torchPackage =
    ps:
    if effectivePytorchCuda then
      ps.torchWithCuda
    else if effectivePytorchRocm then
      ps.torchWithRocm
    else
      ps.torch;

  # Python ML Environment
  mlPythonEnv = pkgs.python3.withPackages (
    ps:
    [
      (torchPackage ps)
      ps.torchvision
      ps.torchaudio
      ps.transformers
      ps.accelerate
      ps.datasets
      ps.huggingface-hub
      ps.numpy
      ps.scipy
      ps.pandas
      ps.matplotlib
      ps.scikit-learn
    ]
    ++ lib.optionals cfg.jupyter.enable [ ps.jupyterlab ]
    ++ cfg.pytorch.extraPackages
  );

  # Diagnostic and SDK tools
  cudaTools = [
    pkgs.cudaPackages.cuda_nvcc
    pkgs.cudaPackages.cudatoolkit
  ];

  rocmTools = [
    pkgs.rocmPackages.rocminfo
    pkgs.rocmPackages.rocm-smi
  ];

  commonTools = [
    pkgs.nvtopPackages.full
    pkgs.vulkan-tools
    pkgs.clinfo
    pkgs.pciutils
  ];

  diagnosticTools =
    commonTools
    ++ lib.optionals (effectiveBackend == "cuda") cudaTools
    ++ lib.optionals (effectiveBackend == "rocm") rocmTools;
in
{
  imports = [
    (lib.mkAliasOptionModule
      [ "northstar" "features" "aiml" ]
      [ "northstar" "features" "development" "aiml" ]
    )
  ];

  options.northstar.features.development.aiml = {
    enable = lib.mkEnableOption "AI/ML development suite (PyTorch, Ollama, Llama.cpp, JupyterLab, acceleration toolchains)";

    acceleration = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "cuda"
        "rocm"
        "none"
      ];
      default = "auto";
      description = "Hardware acceleration backend for AI/ML workloads. 'auto' detects NVIDIA GPU via northstar.nvidia.enable.";
    };

    ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Ollama local LLM runner service.";
      };

      acceleration = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "cuda"
            "rocm"
            "vulkan"
          ]
        );
        default = null;
        description = "Override hardware acceleration backend specifically for Ollama.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Custom Ollama package override. If null, dynamically determined by acceleration.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Network interface address for Ollama daemon to listen on.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port number for Ollama daemon.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open the firewall port for Ollama.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of model names to preload or pull on startup.";
      };
    };

    pytorch = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable PyTorch Python development environment.";
      };

      cuda = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Force CUDA support for PyTorch.";
      };

      rocm = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Force ROCm support for PyTorch.";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional Python packages to include in the ML environment.";
      };
    };

    llamaCpp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable llama.cpp CLI tools and server.";
      };
    };

    jupyter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable JupyterLab interactive notebook environment.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8888;
        description = "Default port for JupyterLab.";
      };
    };

    toolchains = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable GPU SDK diagnostic and development toolchains.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optionals cfg.pytorch.enable [ mlPythonEnv ]
      ++ lib.optionals cfg.llamaCpp.enable [ pkgs.llama-cpp ]
      ++ lib.optionals cfg.toolchains.enable diagnosticTools;

    services.ollama = lib.mkIf cfg.ollama.enable {
      enable = true;
      package = resolvedOllamaPackage;
      host = cfg.ollama.host;
      port = cfg.ollama.port;
      openFirewall = cfg.ollama.openFirewall;
      loadModels = cfg.ollama.models;
    };
  };
}
