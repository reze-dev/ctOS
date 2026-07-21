{ lib }:

let
  isVisibleModule =
    file:
    let
      name = file |> builtins.baseNameOf;
    in
    (file |> toString |> lib.hasSuffix ".nix")
    && name != "default.nix"
    && !(lib.hasPrefix "." name)
    && !(lib.hasPrefix "_" name);

  sortPaths = builtins.sort (a: b: toString a < toString b);

  hasFile = dir: name: (dir + "/${name}") |> builtins.pathExists;

  hostHasDisko = hostsDir: hostName: (hostsDir + "/${hostName}/disko.nix") |> builtins.pathExists;
in
rec {
  # Functional Feature & Profile Combinator
  mkProfile = features: {
    northstar.features = lib.genAttrs features (_: { enable = true; });
  };

  # User & Home-Manager Functional Combinator
  mkUser =
    {
      username,
      groups ? [ "wheel" ],
      shell ? null,
      homeDir ? "/home/${username}",
      homeConfig ? ../home,
      extraConfig ? { },
    }:
    { pkgs, ... }:
    {
      users.users.${username} = {
        isNormalUser = true;
        description = username;
        extraGroups = groups;
      } // (lib.optionalAttrs (shell != null) { inherit shell; }) // extraConfig;

      home-manager.users.${username} = {
        imports = [ homeConfig ];
        home.username = username;
        home.homeDirectory = homeDir;
      };
    };

  scanModules =
    dir:
    if dir |> builtins.pathExists then
      dir
      |> lib.filesystem.listFilesRecursive
      |> builtins.filter isVisibleModule
      |> sortPaths
    else
      [ ];

  discoverHosts =
    hostsDir:
    let
      isHost =
        name: type:
        type == "directory"
        && hasFile (hostsDir + "/${name}") "default.nix"
        && hasFile (hostsDir + "/${name}") "hardware.nix";
    in
    hostsDir
    |> builtins.readDir
    |> lib.filterAttrs isHost
    |> builtins.attrNames;

  inherit hostHasDisko;

  mkHostModules =
    {
      inputs,
      modulePaths ? scanModules ../modules,
      hostsDir ? ../hosts,
      commonModule ? ../hosts/common.nix,
      hostName,
    }:
    [
      inputs.dedsec-grub-theme.nixosModule
      (hostsDir + "/${hostName}")
      (hostsDir + "/${hostName}/hardware.nix")
      commonModule
      { nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; }
    ]
    ++ modulePaths
    ++ lib.optionals (hostHasDisko hostsDir hostName) [ inputs.disko.nixosModules.disko ];

  mkSystem =
    {
      inputs,
      hostName,
      system ? "x86_64-linux",
      hostsDir ? ../hosts,
      extraModules ? [ ],
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = (mkHostModules { inherit inputs hostsDir hostName; }) ++ extraModules;
    };
}
