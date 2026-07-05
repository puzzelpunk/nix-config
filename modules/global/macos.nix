{
  config,
  lib,
  pkgs,
  ...
}:
{
  cfg.os.name = "macos";
  stdenv.hostPlatform.system.stateVersion = 4;
  stdenv.hostPlatform.system.primaryUser = config.cfg.user.name;
}
