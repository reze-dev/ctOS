{ config, lib, ... }:

{
  options.ctos.debug = {
    enable = lib.mkEnableOption "verbose debug logging across ctOS components";
  };
}
