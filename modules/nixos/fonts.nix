{ config, lib, pkgs, ... }:
let cfg = config.cryonix.fonts;
in {
  options.cryonix.fonts.enable = lib.mkEnableOption "Nerd Fonts and system fonts";

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      inter
      noto-fonts-cjk-sans
      source-han-sans
      source-han-serif
      nerd-fonts.jetbrains-mono
      nerd-fonts.monaspace
      nerd-fonts.caskaydia-cove
      nerd-fonts.symbols-only
      nerd-fonts.victor-mono
      maple-mono.truetype
    ];
  };
}
