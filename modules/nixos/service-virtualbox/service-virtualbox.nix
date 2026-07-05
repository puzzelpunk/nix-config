{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = {
    users.users."${config.cfg.user.name}".extraGroups = [ "vboxusers" ];
    virtualisation.virtualbox.host.enable = true;
    virtualisation.virtualbox.host.enableExtensionPack = true;
  };
}
