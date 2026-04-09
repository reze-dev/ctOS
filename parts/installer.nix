# Flake-parts module: installer package & app
{ self, inputs, ... }:

{
  perSystem = { pkgs, system, ... }: {
    packages = {
      installer = pkgs.writeShellApplication {
        name = "cryonix-install";
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
          TEMP_DIR=$(mktemp -d -t cryonix-install.XXXXXX)
          cleanup() { rm -rf "$TEMP_DIR"; }
          trap cleanup EXIT

          echo "Preparing Cryonix source..."
          cp -R "${self}" "$TEMP_DIR/cryonix"
          chmod -R u+w "$TEMP_DIR/cryonix"
          cd "$TEMP_DIR/cryonix"
          export CRYONIX_REMOTE="$TEMP_DIR/cryonix"
          exec python3 installer/install.py
        '';
      };

      default = self.packages.${system}.installer;
    };

    apps = {
      install = {
        type = "app";
        program = "${self.packages.${system}.installer}/bin/cryonix-install";
        meta.description = "Interactive Cryonix installer";
      };

      default = self.apps.${system}.install // {
        meta.description = "Default Cryonix app (installer)";
      };
    };
  };
}
