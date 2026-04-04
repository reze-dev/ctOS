# Flake-parts module: Rust binary installer (crane)
{ self, inputs, ... }:

{
  perSystem = { pkgs, system, ... }:
    let
      craneLib = inputs.crane.lib.${system};

      # Assemble source: Rust code + embedded flake
      rustSrc = pkgs.runCommand "rust-installer-src" { } ''
        mkdir -p $out/src $out/flake
        cp ${../installer-rs}/Cargo.toml $out/
        cp ${../installer-rs}/Cargo.lock $out/ 2>/dev/null || true
        cp -r ${../installer-rs}/src/* $out/src/

        # Populate flake dir for include_dir! embed
        cp ${../flake.nix} $out/flake/
        cp ${../flake.lock} $out/flake/
        cp ${../README.md} $out/flake/
        cp -r ${../hosts} $out/flake/hosts
        cp -r ${../home} $out/flake/home
        cp -r ${../modules} $out/flake/modules
        cp -r ${../parts} $out/flake/parts
        cp -r ${../assets} $out/flake/assets
      '';

      commonArgs = {
        src = rustSrc;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.pkg-config ];
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      rustBin = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;
      });

      # Runtime tools the installer shells out to
      runtimeDeps = with pkgs; [
        git coreutils util-linux pciutils whois openssl
        parted btrfs-progs e2fsprogs nixos-install-tools
      ];
    in
    {
      packages.rust-installer = pkgs.symlinkJoin {
        name = "snowflake-installer-rs";
        paths = [ rustBin ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/snowflake-installer \
            --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
        '';
        meta = {
          description = "Snowflake NixOS installer (Rust + ratatui)";
          mainProgram = "snowflake-installer";
        };
      };

      apps.rust-install = {
        type = "app";
        program = "${self.packages.${system}.rust-installer}/bin/snowflake-installer";
        meta.description = "Rust-based Snowflake installer with ratatui TUI";
      };
    };
}
