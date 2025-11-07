{ config, lib, pkgs, options, ... }: {
  config.homebrew.taps = [];
  config.homebrew.brews = [ "colima" "docker" "docker-compose" ];
  config.homebrew.casks = [
    "appcleaner"
    "balenaetcher"
    "basictex"
    "bitwig-studio"
    "brave-browser"
    "discord"
    "disk-drill"
    "element"
    "firefox"
    "geekbench"
    "gimp"
    "grandperspective"
    "handbrake"
    "inkscape"
    "karabiner-elements"
    "krita"
    "launchcontrol"
    "libreoffice"
    "little-snitch"
    "obs"
    "obsidian"
    {
      name = "ollama";
      start_service = true;
    }
    "resilio-sync"
    "the-unarchiver"
    "transmission"
    "utm"
    "vlc"
    "vscodium"
    "zed"
    # "blender"
    # "charles"
    # "darktable"
    # "dash"
    # "docker"
    # "musescore"
    # "wireshark"
  ];
}
