{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  home-manager.users.reze = {
    imports = [
      ../../home/home.nix
      ../../shell/nix/home-manager.nix
    ];
    programs.ctOS.enable = true;
    home.username = lib.mkForce "reze";
    home.homeDirectory = lib.mkForce "/home/reze";
  };

  ctos.features.boot.secureBoot.enable = true;

  users.users.reze = {
    isNormalUser = true;
    description = "reze";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
      "wireshark"
      "input"
    ];
    shell = pkgs.zsh;
    hashedPassword = "$6$7uVH9VA23imtOFPs$Rx7oc7xoN5gxBqdB6pg1ZG7xqAeX4LIzLuKjPExFOySTdfmVGdDbCD.4K/dtLLbUbdpcNJ8W5OYpeknaij6mM.";
  };

  services.udev.extraRules = "SUBSYSTEM==\"misc\", KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\", OPTIONS+=\"static_node=uinput\"";

  # ctOS profiles
  ctos.profiles = {
    desktop.enable = true;
    workstation.enable = true;
  };

  # Custom feature overrides
  ctos.features = {
    niri.enable = true;
    greeter.enable = true;
    fish.enable = true;
    emacs.enable = true;
    nvf.enable = true;
  };

  # NVIDIA GPU
  ctos.nvidia.enable = true;
  ctos.nvidia.prime = {
    enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };

  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark-cli;

  # Verbose logging for the Hyprland login failure. The desktop launcher dumps
  # its full environment to /tmp/ctos-desktop-session.log before exec'ing
  # start-hyprland, and cage runs with -D -d, so a login attempt leaves enough
  # to see what the session actually got. Turn this off once Hyprland is up.
  ctos.debug.enable = false;

  networking.hostName = "Makima";
  system.stateVersion = "26.11";
}
