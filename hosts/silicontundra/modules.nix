{ config, pkgs, ... }: {
  imports = [
    ../../modules/common/home/dotfiles.nix 
    ../../modules/common/fonts/fonts.nix
    ../../modules/common/home/home.nix
    ../../modules/macos/application-desktop/application-desktop.nix
    ../../modules/macos/system-defaults/system-defaults.nix
  ];
}
