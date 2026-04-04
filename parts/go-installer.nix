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

        # Copy flake files for embedding
        cp ${../flake.nix} $out/flake/
        cp ${../flake.lock} $out/flake/
        cp ${../install.py} $out/flake/
        cp ${../README.md} $out/flake/
        cp -r ${../hosts} $out/flake/hosts
        cp -r ${../home} $out/flake/home
        cp -r ${../modules} $out/flake/modules
        cp -r ${../parts} $out/flake/parts
        cp -r ${../assets} $out/flake/assets
      '';
    in
    {
      packages.go-installer = pkgs.buildGoModule {
        pname = "snowflake-installer";
        version = "1.0.0";
        src = goSrc;
        vendorHash = null;

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
