with nixpkgs.lib;
with nixpkgs.stdenv;

zshInitExtraConfig: ''
  function pathIf () {
    [ -e "$1" ] && export PATH="$PATH:$1"
  }

  function sourceIf() {
    [ -e "$1" ] && source $1
  }

  function fpathIf() {
    [ -e "$1" ] && fpath=($1 $fpath)
  }

  ${optionalString (zshInitExtraConfig.fpaths != []) ''
    ### FUNCTION PATHS

    fpathIf ${concatStringsSep "\nfpathIf " zshInitExtraConfig.fpaths}
  ''}

  ${optionalString (zshInitExtraConfig.sources != []) ''
    ### SOURCES

    sourceIf ${concatStringsSep "\nsourceIf " zshInitExtraConfig.sources}
  ''}

  ${optionalString (zshInitExtraConfig.paths != []) ''
    ### PATHS

    pathIf ${concatStringsSep "\npathIf " zshInitExtraConfig.paths}
  ''}  

  ${optionalString (zshInitExtraConfig.ohMyZsh.enable == true) ''
    ### OH-MY-ZSH
    
    export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
    
    ${optionalString (zshInitExtraConfig.ohMyZsh.plugins != []) ''
      plugins=(${concatStringsSep " " zshInitExtraConfig.ohMyZsh.plugins})
    ''}

    source $ZSH/oh-my-zsh.sh
  ''}
  
  ${optionalString (zshInitExtraConfig.variables != {}) ''
    ### VARIABLES

    ${concatStringsSep "\n" 
        (lib.attrsets.mapAttrsToList 
          (name: value: ''${name}="${value}";'') 
          zshInitExtraConfig.variables)}
  ''}

  ${optionalString (zshInitExtraConfig.aliases != {}) ''
    ### ALIASES

    ${concatStringsSep "\n" 
        (lib.attrsets.mapAttrsToList 
          (name: value: ''alias ${name}="${value}";'') 
          zshInitExtraConfig.aliases)}
  ''}

  ${optionalString (zshInitExtraConfig.setOpts != []) ''
    ### OPTIONS

    setopt ${concatStringsSep "\nsetopt " zshInitExtraConfig.setOpts}
  ''}

  ${optionalString (zshInitExtraConfig.completions != {}) ''
    ### COMPLETIONS

    ${concatStringsSep "\n" 
        (lib.attrsets.mapAttrsToList 
          (name: value: ''zstyle ':completion:*' ${name} ${value}'') 
          zshInitExtraConfig.completions)}
  ''}

  ${optionalString (zshInitExtraConfig.keybindings != {}) ''
    ### KEYBINDINGS
    ## http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Standard-Widgets
    ## showkey -a       # get keyboard keycodes
    ## zle -la | less   # get all possible commands
    ## bindkey          # get all currently bounded commands

    bindkey -e

    ${concatStringsSep "\n" 
        (lib.attrsets.mapAttrsToList 
          (name: value: ''bindkey '${value}' ${name}'') 
          zshInitExtraConfig.keybindings)}
  ''}

  ${optionalString (zshInitExtraConfig.extras != []) ''
    ### EXTRAS

    ${concatStringsSep "\n" zshInitExtraConfig.extras}
  ''}       
''