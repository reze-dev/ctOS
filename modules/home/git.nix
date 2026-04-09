{ config, lib, ... }:
let cfg = config.cryonix.home.git;
in {
  options.cryonix.home.git.enable = lib.mkEnableOption "Git user configuration";

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user.name = "atomiksan";
        user.email = "25588579+atomiksan@users.noreply.github.com";
        init.defaultBranch = "main";
      };
    };
  };
}
