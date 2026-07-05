{ ... }:
{
  imports = [ ../desktop-environment/desktop-environment.nix ];

  config = {
    services.desktopManager.plasma6.enable = true;
  };
}
