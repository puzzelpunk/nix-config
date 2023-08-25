with (import <nixpkgs> {}).lib;
let getDir = import ./getDir.nix; in
dir: collect isString 
    (mapAttrsRecursive 
      (path: type: concatStringsSep "/" path) 
      (getDir dir))