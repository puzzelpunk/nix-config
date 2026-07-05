{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = {
    environment.systemPackages = with pkgs; [
      libimobiledevice
      ifuse
      gvfs
    ];

    programs.adb.enable = true;
    services.gvfs.enable = true;
    services.usbmuxd.enable = true;
    users.users."${config.cfg.user.name}".extraGroups = [ "adbusers" ];
  };
}
