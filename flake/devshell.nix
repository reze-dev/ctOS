# Flake-parts module: development shell for contributors
{ inputs, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    {
      devShells.default = pkgs.mkShell {
        name = "ctos-dev";
        packages = with pkgs; [
          # Nix tooling
          inputs.determinate.packages.${system}.default
          nixfmt
          nil
          nix-diff

          # General
          git
          jq
        ];

        shellHook = ''
          echo "❄️  ctOS development shell"
          echo ""
          echo "  nix flake check --impure   — run all checks"
          echo "  nix fmt                    — format all Nix files"
          echo ""
        '';
      };
    };
}
