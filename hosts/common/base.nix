{
  inputs,
  importers,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.nix-index
  ] ++ (importers.scanPaths ../../nixos);

  home-manager.extraSpecialArgs = { inherit inputs importers; };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];
}
