# Flake-parts module: development shell for contributors
{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        name = "northstar-dev";
        packages = with pkgs; [
          # Nix tooling
          inputs.determinate.packages.${system}.default
          nixfmt
          nil
          nix-diff

          # Python (for installer tests)
          python3

          # General
          git
          jq
        ];

        shellHook = ''
          echo "❄️  Northstar development shell"
          echo ""
          echo "  nix flake check --impure   — run all checks"
          echo "  nix fmt                    — format all Nix files"
          echo "  python3 -m unittest discover -s tests -v — run Python tests"
          echo ""
        '';
      };
    };
}
