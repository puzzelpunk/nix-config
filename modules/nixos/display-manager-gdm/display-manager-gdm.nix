{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = {
    services.displayManager.gdm.enable = true;
  };
}
