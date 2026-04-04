# Flake-parts module: installer package & app
{ self, inputs, ... }:

{
  perSystem = { pkgs, system, ... }: {
    packages = {
      installer = pkgs.writeShellApplication {
        name = "snowflake-install";
        runtimeInputs = with pkgs; [
          git
          coreutils
          util-linux     # lsblk, blkid
          pciutils       # lspci (GPU detection)
          whois          # mkpasswd
          openssl        # fallback password hashing
          parted         # partition creation (dual-boot mode)
          btrfs-progs    # mkfs.btrfs, btrfs subvolume (dual-boot mode)
        ];
        text = ''
          set -e
          TEMP_DIR=$(mktemp -d -t snowflake-install.XXXXXX)
          cleanup() { rm -rf "$TEMP_DIR"; }
          trap cleanup EXIT

          echo "Preparing Snowflake source..."
          cp -R "${self}" "$TEMP_DIR/snowflake"
          chmod -R u+w "$TEMP_DIR/snowflake"
          cd "$TEMP_DIR/snowflake"
          export SNOWFLAKE_REMOTE="$TEMP_DIR/snowflake"
          chmod +x install.sh
          exec ./install.sh
        '';
      };

      default = self.packages.${system}.installer;
    };

    apps = {
      install = {
        type = "app";
        program = "${self.packages.${system}.installer}/bin/snowflake-install";
        meta.description = "Interactive Snowflake installer";
      };

      default = self.apps.${system}.install // {
        meta.description = "Default Snowflake app (installer)";
      };
    };
  };
}
