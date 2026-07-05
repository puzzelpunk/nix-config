{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config.services.cron = {
    mailto = config.cfg.user.email;
    enable = true;
  };
}
