# Flake-parts module: installer package & app
{ self, inputs, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      nixConfigFeatures = "experimental-features = nix-command flakes pipe-operators";
    in
    {
      packages = {
        installer = pkgs.writeShellApplication {
          name = "ctos-install";
          runtimeInputs = with pkgs; [
            inputs.determinate.packages.${system}.default
            nixos-install-tools
            age
            ssh-to-age
            sops
            util-linux
            coreutils
            python3
            git
            pciutils
            whois
            openssl
            parted
            btrfs-progs
            e2fsprogs
          ];
          text = ''
            set -e
            TEMP_DIR=$(mktemp -d -t ctos-install.XXXXXX)
            cleanup() { rm -rf "$TEMP_DIR"; }
            trap cleanup EXIT

            echo "Preparing ctOS source..."
            cp -R "${self}" "$TEMP_DIR/ctos"
            chmod -R u+w "$TEMP_DIR/ctos"
            cd "$TEMP_DIR/ctos"
            git init -q
            git config user.name "ctOS Installer"
            git config user.email "installer@ctos.local"
            git add -A
            export CTOS_REMOTE="$TEMP_DIR/ctos"
            if [ -n "''${NIX_CONFIG:-}" ]; then
              NIX_CONFIG="$(printf '%s\n%s' "$NIX_CONFIG" "${nixConfigFeatures}")"
            else
              NIX_CONFIG="${nixConfigFeatures}"
            fi
            export NIX_CONFIG
            exec python3 installer/install.py "$@"
          '';
        };

        default = self.packages.${system}.installer;
      };

      apps = {
        install = {
          type = "app";
          program = "${self.packages.${system}.installer}/bin/ctos-install";
          meta.description = "Interactive ctOS installer";
        };

        default = self.apps.${system}.install // {
          meta.description = "Default ctOS app (installer)";
        };
      };
    };
}
