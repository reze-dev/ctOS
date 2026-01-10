{
  config,
  lib,
  pkgs,
  inputs,
  importers,
  ...
}:

{
  # Import the required config files here
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.nix-index
    #{
    #  home-manager.useGlobalPkgs = true;
    #  home-manager.useUserPackages = true;
    #}
  ] ++ (importers.scanPaths ../../nixos);

  home-manager.extraSpecialArgs = { inherit inputs importers; };
  home-manager.users.loid = {
    # Import your modular Home Manager configuration:
    imports = [ ../../home.nix ];

    # Optionally add more Home Manager settings here:
    # You can also set other options, e.g.:
    # home.sessionVariables = { ... };
  };

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
