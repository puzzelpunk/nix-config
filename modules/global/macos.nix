{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  cfg.os.name = "macos";
  stdenv.hostPlayform.system.stateVersion = 4;
  stdenv.hostPlayform.system.primaryUser = config.cfg.user.name;
}
