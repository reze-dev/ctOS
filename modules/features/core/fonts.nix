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
        # "Material Symbols Outlined" (see Theme.fontFamilyMaterialIcons).
        # Apache-2.0, as is the rest of this list.
        #
        # Material Symbols rather than the older Material Icons: it carries the
        # same codepoints for the E-range the shell already uses, so switching
        # did not disturb a single existing glyph, and roughly triples the set
        # (4372 vs 1372). That is what makes glyphs like "hexagon" available at
        # all -- the classic face has no hexagon.
        material-symbols
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
