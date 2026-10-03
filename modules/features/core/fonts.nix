{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.fonts;
in
{
  options.ctos.features.fonts.enable = lib.mkEnableOption "Nerd Fonts and system fonts";

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      inter
      # Functional glyphs for the shell, referenced by family name as
      # "Material Icons Outlined" (see Theme.fontFamilyMaterialIcons).
      # Apache-2.0, as is the rest of this list.
      material-icons
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
