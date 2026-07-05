{ ... }:
{
  imports = [ ../desktop-environment/desktop-environment.nix ];

  config = {
    programs.dconf.enable = true;
    services.gnome.gnome-keyring.enable = true;
    services.desktopManager.gnome.enable = true;
  };
}
