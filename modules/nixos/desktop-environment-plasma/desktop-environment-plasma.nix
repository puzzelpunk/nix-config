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
    services.desktopManager.plasma5.enable = true;
  };
}
