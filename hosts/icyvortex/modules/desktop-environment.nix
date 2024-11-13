{ config, lib, pkgs, options, ... }: {
  imports = [
    ../../../modules/nixos/desktop-environment-gnome/desktop-environment-gnome.nix
    ../../../modules/nixos/display-manager-gdm/display-manager-gdm.nix
  ];
  config = {
    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
      gnomeExtensions.just-perfection
      gnomeExtensions.appindicator
      gnomeExtensions.gsconnect
      bibata-cursors
      papirus-icon-theme
    ];
  };
}
