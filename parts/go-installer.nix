# Flake-parts module: Go binary installer
{ self, inputs, ... }:

{
  perSystem = { pkgs, system, ... }:
    let
      # Assemble source: Go code + embedded flake files
      goSrc = pkgs.runCommand "go-installer-src" { } ''
        mkdir -p $out/flake
        cp ${../installer}/*.go $out/
        cp ${../installer}/go.mod $out/
        cp ${../installer}/go.sum $out/

        # Copy flake files for embedding
        cp ${../flake.nix} $out/flake/
        cp ${../flake.lock} $out/flake/
        cp ${../README.md} $out/flake/
        cp -r ${../hosts} $out/flake/hosts
        cp -r ${../home} $out/flake/home
        cp -r ${../modules} $out/flake/modules
        cp -r ${../parts} $out/flake/parts
        cp -r ${../assets} $out/flake/assets
      '';

      # Runtime tools the installer shells out to
      runtimeDeps = with pkgs; [
        git
        coreutils
        util-linux     # lsblk, blkid, mkswap, swapon, mountpoint
        pciutils       # lspci (GPU detection)
        whois          # mkpasswd
        openssl        # fallback password hashing
        parted         # partition creation (dual-boot mode)
        btrfs-progs    # mkfs.btrfs, btrfs subvolume
        e2fsprogs      # chattr
        nixos-install-tools
      ];

      goBin = pkgs.buildGoModule {
        pname = "snowflake-installer-unwrapped";
        version = "1.0.0";
        src = goSrc;
        vendorHash = "sha256-XgOllUod/bFhbbTNtu8ZNW+VjiNd4rCDMyqBSTr2Sm4=";
      };
    in
    {
      packages.go-installer = pkgs.symlinkJoin {
        name = "snowflake-installer";
        paths = [ goBin ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/snowflake-installer \
            --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
        '';
        meta = {
          description = "Snowflake NixOS installer (Go binary with embedded flake)";
          mainProgram = "snowflake-installer";
        };
      };

      apps.go-install = {
        type = "app";
        program = "${self.packages.${system}.go-installer}/bin/snowflake-installer";
        meta.description = "Go-based Snowflake installer with embedded flake";
      };
    };
}

