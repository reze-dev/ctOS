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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  # Enable all snowflake NixOS modules
  snowflake = {
    boot.enable = true;
    hyprland.enable = true;
    packages.enable = true;
    dev.enable = true;
    shells.enable = true;
    firefox.enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    cups.enable = true;
    display.enable = true;
    emacs.enable = true;
    ssh.enable = true;
    virtualization.enable = true;
    env.enable = true;
    fonts.enable = true;
    locales.enable = true;
    networking.enable = true;
  };
}
