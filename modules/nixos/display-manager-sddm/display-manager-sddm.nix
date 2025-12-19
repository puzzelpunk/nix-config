{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = {
    services.displayManager.sddm.enable = true;
  };
}
