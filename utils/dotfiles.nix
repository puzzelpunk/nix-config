let files = import ./files.nix; in
dir: (builtins.map (str: { 
      "${str}" = { 
        source = "${dir}/${str}";
      };
    }) (files dir))