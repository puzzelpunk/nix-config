{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [ ./modules.nix ];

  config = {
    services.desktopManager.xfce.enable = true;
  };
}
