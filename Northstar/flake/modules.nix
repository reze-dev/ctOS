# Flake-parts module: single aggregator entrypoint for all flake modules
{
  imports = [
    ./hosts.nix
    ./installer.nix
    ./checks.nix
    ./devshell.nix
    ./formatter.nix
  ];
}
