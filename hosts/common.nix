{
  inputs,
  homeModulePaths,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.nix-index
  ];

  home-manager.extraSpecialArgs = { inherit inputs homeModulePaths; };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "reze"
    ];
  };

  northstar.profiles.base.enable = true;
}
