{ config, lib, pkgs, options, ... }:

let
  Packages = with pkgs; [
    autocutsel
    autorandr
    compton
    feh
    libnotify
    pywal
    qt5ct
    rofi
    wmctrl
    xdg_utils
    xdo
    xorg.xkill
    xorg.xrandr
    xscreensaver 
    bibata-cursors
    papirus-icon-theme
  ];
in {
  config = {
    environment.systemPackages = Packages;
    programs.dconf.enable = true;
    services.gnome3.gnome-keyring.enable = true;

    services.xserver = {
      enable = true;
      dpi = 96;
      libinput.enable = true;
      layout = "us";

      windowManager.bspwm.enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome3.enable = true;
    };
  };
}
