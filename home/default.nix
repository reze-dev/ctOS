{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./apps
    ./cli-apps
    ./shell-config
  ];
}
