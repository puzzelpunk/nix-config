{ config, lib, pkgs, options, ... }:

let
  Packages = with pkgs; [
    # archive
    gnome3.file-roller
    # disk utils
    woeusb
    qdirstat
    gparted
    etcher
    # browsers
    brave
    chromium
    firefox
    # creative
    blender
    gthumb
    gimp-with-plugins
    inkscape
    kdeApplications.kdenlive
    krita
    # development
    zeal
    vscodium
    # network files
    qbittorrent
    # office
    libreoffice
    typora
    zathura
    protonmail-bridge
    # media
    gthumb
    handbrake
    spotify
    rhythmbox
    kazam
    vlc
    obs-studio
    # networking
    charles3
    wireshark
    linssid
    # social
    discord
  ];
in { config = { environment.systemPackages = Packages; }; }
