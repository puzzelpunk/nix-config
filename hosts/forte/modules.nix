{ config, pkgs, ... }: {
  imports = [
    ../../modules/common/home/dotfiles.nix
    ../../modules/common/fonts/fonts.nix
    ../../modules/common/home/home.nix
    # ../../modules/darwin/service-yabai/service-yabai.nix
    ../../modules/macos/application-desktop/software-brew.nix
    ../../modules/macos/system-defaults/system-defaults.nix
  ];
}
