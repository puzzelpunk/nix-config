{ config, lib, pkgs, options, ... }:

with lib;
let
  cfg = config.cfg;

  Packages = with pkgs; [
    ansible
    docker
    docker-machine
    vagrant
    
    git
    nodejs-12_x
    nodePackages.node2nix
    python
    python3
    rustc
    sassc
    vim
  ];
in {
  config = {
    environment.systemPackages = Packages;

    environment.variables = { 
      TERMINAL = "kitty";
      EDITOR = "vim";
      VISUAL = "code";
    };

    # home-manager.users."${cfg.username}" = mkMerge [
    #   {
    #     programs.git = {
    #       enable = true;
    #       userName = cfg.username;
    #       userEmail = cfg.useremail;
    #     };
    #   }
    # ];
  };
}
