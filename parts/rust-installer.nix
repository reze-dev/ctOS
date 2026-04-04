# Flake-parts module: Rust binary installer (crane)
{ self, inputs, ... }:

{
  perSystem = { pkgs, system, ... }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      # Use the installer-rs directory directly so crane can read Cargo.toml
      # at eval time. We'll populate the flake/ dir in the build phase.
      rustSrc = pkgs.lib.cleanSourceWith {
        src = ../installer-rs;
        filter = path: type:
          (craneLib.filterCargoSources path type)
          || builtins.baseNameOf path == "PLACEHOLDER";
      };

      # Assemble the full flake source as a derivation
      flakeSrc = pkgs.runCommand "snowflake-flake-src" { } ''
        mkdir -p $out
        cp ${../flake.nix} $out/flake.nix
        cp ${../flake.lock} $out/flake.lock
        cp ${../README.md} $out/README.md
        cp -r ${../hosts} $out/hosts
        cp -r ${../home} $out/home
        cp -r ${../modules} $out/modules
        cp -r ${../parts} $out/parts
        cp -r ${../assets} $out/assets
      '';

      commonArgs = {
        src = rustSrc;
        pname = "snowflake-installer";
        version = "2.0.0";
        strictDeps = true;
        nativeBuildInputs = [ pkgs.pkg-config ];

        # Populate flake/ dir before cargo build so include_dir! works
        preBuild = ''
          rm -rf flake/*
          cp -r ${flakeSrc}/* flake/
        '';
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
