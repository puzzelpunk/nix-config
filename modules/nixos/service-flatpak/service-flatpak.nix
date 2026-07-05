{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = {
    xdg.portal.enable = true;
    xdg.portal.gtkUsePortal = true;
    xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    services.flatpak.enable = true;
  };
}
