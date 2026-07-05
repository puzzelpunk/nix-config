{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [ ../service-avahi/service-avahi.nix ];
}
