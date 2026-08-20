{ config, lib, ... }:
let
  cfg = config.northstar.features.locales;
in
{
  options.northstar.features.locales.enable = lib.mkEnableOption "timezone and locale settings";

  config = lib.mkIf cfg.enable {
    time.timeZone = lib.mkDefault "Asia/Kolkata";

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_IN";
      LC_IDENTIFICATION = "en_IN";
      LC_MEASUREMENT = "en_IN";
      LC_MONETARY = "en_IN";
      LC_NAME = "en_IN";
      LC_NUMERIC = "en_IN";
      LC_PAPER = "en_IN";
      LC_TELEPHONE = "en_IN";
      LC_TIME = "en_IN";
    };
  };
}
