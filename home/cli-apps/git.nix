{
  config,
  pkgs,
  ...
}:

{
  # Git config
  programs.git = {
    enable = true;
    settings = {
      user.name = "atomiksan";
      user.email = "25588579+atomiksan@users.noreply.github.com";
      init.defaultBranch = "main";
    };
  };
}
