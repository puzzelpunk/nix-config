{ config, lib, pkgs, ... }:
with lib;
let
  # Functions [ getDir files ] taken from
  # https://github.com/Infinisil/system/blob/master/config/new-modules/default.nix


  getDir = dir: mapAttrs (file: type:
    if type == "directory" 
    then getDir "${dir}/${file}" 
    else type
  ) (builtins.readDir dir);

  files = dir: collect isString 
    (mapAttrsRecursive 
      (path: type: concatStringsSep "/" path) 
      (getDir dir));

  dotfiles = dir: (builtins.map (str: { 
      "${str}" = { 
        source = "${dir}/${str}";
      };
    }) (files dir));
in {
  config.home-manager.users."${config.cfg.user.name}".home.file = 
    (mkMerge (dotfiles ./.dotfiles)); 
}
