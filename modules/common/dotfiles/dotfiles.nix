{ config, lib, pkgs, ... }:
with lib;
let
  # Functions [ getDir files ] taken from
  # https://github.com/Infinisil/system/blob/master/config/new-modules/default.nix
  dotfiles = import ./../../utils/dotfiles.nix;
in {
  imports = [ ./modules.nix ];

  config.home-manager.users."${config.cfg.user.name}".home.file = 
    (mkMerge (dotfiles ./.dotfiles)); 
}
