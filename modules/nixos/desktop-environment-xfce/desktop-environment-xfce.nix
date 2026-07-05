{ ... }:
{
  imports = [ ../desktop-environment/desktop-environment.nix ];

  config = {
    services.desktopManager.xfce.enable = true;
  };
}
