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
    services.flatpak.enable = true;
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;
    programs.appimage.package = pkgs.appimage-run;
  };
}
