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
          name = "northstar-install";
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
            TEMP_DIR=$(mktemp -d -t northstar-install.XXXXXX)
            cleanup() { rm -rf "$TEMP_DIR"; }
            trap cleanup EXIT

            echo "Preparing Northstar source..."
            cp -R "${self}" "$TEMP_DIR/northstar"
            chmod -R u+w "$TEMP_DIR/northstar"
            cd "$TEMP_DIR/northstar"
            git init -q
            git config user.name "Northstar Installer"
            git config user.email "installer@northstar.local"
            git add -A
            export NORTHSTAR_REMOTE="$TEMP_DIR/northstar"
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
          program = "${self.packages.${system}.installer}/bin/northstar-install";
          meta.description = "Interactive Northstar installer";
        };

        default = self.apps.${system}.install // {
          meta.description = "Default Northstar app (installer)";
        };
      };
    };
}
