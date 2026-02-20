{
  description = "Snow Flakes with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    awww.url = "git+https://codeberg.org/LGFae/awww";
    tmux-powerkit.url = "github:fabioluciano/tmux-powerkit";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      myLib = import ./lib/importers.nix { inherit lib; };
    in
    {
      nixosConfigurations =
        let
          # Get all subdirectories in ./hosts, excluding "common"
          hosts = lib.filterAttrs (name: type: type == "directory" && name != "common") (
            builtins.readDir ./hosts
          );

          # Check if a host uses disko (has a disko.nix file)
          hostHasDisko = hostName: builtins.pathExists ./hosts/${hostName}/disko.nix;

          mkHost =
            hostName:
            lib.nixosSystem {
              inherit system;
              specialArgs = {
                inherit inputs;
                importers = myLib;
              };
              modules = [
                ./hosts/${hostName}/configuration.nix
                ./hosts/${hostName}/hardware-configuration.nix
                { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
              ]
              ++ (lib.optionals (hostHasDisko hostName) [
                # Only include disko for hosts that have disko.nix
                inputs.disko.nixosModules.disko
                ./hosts/common/disko-config.nix
              ]);
            };
        in
        lib.mapAttrs (name: _: mkHost name) hosts;

      # Installer package with runtime dependencies
      packages.${system} = {
        installer = pkgs.writeShellApplication {
          name = "snowflake-install";
          runtimeInputs = with pkgs; [
            git
            coreutils
            util-linux # lsblk
            pciutils # lspci (GPU detection)
            whois # mkpasswd
            openssl # fallback password hashing
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

      # App for `nix run`
      apps.${system} = {
        install = {
          type = "app";
          program = "${self.packages.${system}.installer}/bin/snowflake-install";
          meta = {
            description = "Interactive Snowflake installer";
          };
        };

        default = self.apps.${system}.install // {
          meta = {
            description = "Default Snowflake app (installer)";
          };
        };
      };
    };
}
