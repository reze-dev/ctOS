{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.toolkit;

  # Grouped to match ToolkitService.groups in the shell, with one important
  # asymmetry: this list is nixpkgs *package* names and the shell's is bare
  # *command* names on PATH, and those are not the same set. `bind` provides
  # dig, host and delv; `nettools` provides other legacy net tools. So a group
  # here and its counterpart there are deliberately not identical, and the
  # mismatch is written down rather than papered over -- the shell reports what it
  # can actually execute, which is the only question a readout can answer.
  groups = {
    recon = [
      "nmap"
      "masscan"
      "whois"
      "bind" # provides dig, host, delv
      "nettools"
    ];
    capture = [
      "tshark"
      "tcpdump"
      "socat"
    ];
    wireless = [
      "aircrack-ng"
    ];
    credentials = [
      "john"
      "hashcat"
      "hydra"
    ];
    web = [
      "sqlmap"
    ];
    forensics = [
      "binwalk"
      "exiftool"
      "file"
    ];
    diagnostics = [
      "iperf3"
      "mtr"
      "traceroute"
      "jq"
    ];
  };

  # Two mappings to keep flat, because attrset keys cannot collide silently --
  # a name appearing under two groups would just drop one of them.
  nameToGroup = lib.listToAttrs (
    lib.concatMap (
      group:
      map (name: {
        name = name;
        value = group;
      }) groups.${group}
    ) (lib.attrNames groups)
  );
  duplicates = lib.filter (
    name: lib.length (lib.filter (g: g == nameToGroup.${name}) (lib.attrNames groups)) > 1
  ) (lib.attrNames nameToGroup);
in
{
  options.ctos.features.toolkit.enable = lib.mkEnableOption "ctOS security and diagnostic toolkit";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = duplicates == [ ];
        message = ''
          ctOS toolkit: these tools are listed under more than one group: ${toString (lib.concatStringsSep ", " duplicates)}.
          Each tool belongs to exactly one group, or ToolkitService would count it once
          and the group tallies would not add up.
        '';
      }
    ];

    home-manager.sharedModules = [
      (
        { ... }:
        {
          # Only the nixpkgs names, not pkgs.<name> -- the shell resolves tools by
          # bare command name on PATH, and the home-manager profile is what puts
          # them there. Deriving both halves from `groups` keeps the module and
          # ToolkitService in step without duplicating the list.
          home.packages = map (name: pkgs.${name}) (lib.attrNames nameToGroup);
        }
      )
    ];
  };
}
