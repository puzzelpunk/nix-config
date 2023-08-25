with (import <nixpkgs> {}).lib;
let
    getDir = dir: mapAttrs (file: type:
    if type == "directory" 
    then getDir "${dir}/${file}" 
    else type
  ) (builtins.readDir dir);
in
getDir