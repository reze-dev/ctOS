# Flake-parts module: installer package & app
{ self, inputs, ... }:

{
  perSystem = { pkgs, system, ... }: {
    packages = {
      installer = pkgs.writeShellApplication {
        name = "northstar-install";
        runtimeInputs = with pkgs; [
          python3
          git
          coreutils
          util-linux     # lsblk, blkid, mkswap, swapon
          pciutils       # lspci (GPU detection)
          whois          # mkpasswd
          openssl        # fallback password hashing
          parted         # partition creation (dual-boot mode)
          btrfs-progs    # mkfs.btrfs, btrfs subvolume (dual-boot mode)
          e2fsprogs      # chattr
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
          export NORTHSTAR_REMOTE="$TEMP_DIR/northstar"
          exec python3 installer/install.py
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
