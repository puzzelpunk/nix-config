{ config, lib, pkgs, ... }:

with pkgs.stdenv; 
with lib;

let
  cfg = config.cfg;
  homeDir = builtins.getEnv("HOME");
in
{
  imports = [
    # ./home-manager-init.nix
    ./shell.nix 
    ./fonts.nix
    ./locale.nix
    ./development.nix
    ./utils.nix
  ];

  options = {
    cfg.systemname= mkOption {
      type = types.str;
      description = "Target system to build.";
    };

    cfg.username = mkOption {
      type = types.str;
      default = "user";
      description = "Username for the main user on the system";
    };

    cfg.userfullname = mkOption {
      type = types.str;
      default = "User";
      description = "Username for the main user on the system";
    };

    cfg.useremail = mkOption {
      type = types.str;
      default = "user@example.com";
      description = "Username for the main user on the system";
    };
    
  };

  config = {

    nix = {
      allowedUsers = [
        "@wheel" 
        "${cfg.username}"
      ];
      buildCores = 0;
    };

    nixpkgs.config.allowUnfree = true;
    networking.hostName = cfg.systemname;

    users.users."${cfg.username}" = mkMerge [
      { 
        name = "${cfg.username}";
        shell = pkgs.zsh;
        home = homeDir;
      }
    ];

   # home-manager.users."${cfg.username}" = mkMerge [
   #   {
   #     home.file.dotfiles = {
   #       source = "/home/${cfg.username}/dotfiles";
   #       target = "./";
   #       recursive = true;
   #     };
   #   }
   #   # TODO: This won't work in darwin for some reason.
   #   # {
   #   #   programs.chromium = {
   #   #     enable = true;
   #   #     package = pkgs.brave;
   #   #     extensions = [
   #   #       "eimadpbcbfnmbkopoojfekhnkhdbieeh" # dark reader
   #   #       "gppongmhjkpfnbhagpmjfkannfbllamg" # wappalyzer
   #   #       "jpcmhcelnjdmblfmjabdeclccemkghj" # view image
   #   #       "fngmhnnpilhplaeedifhccceomclgfbg" # edit this cookie
   #   #       "pkehgijcmpdhfbdbbnkijodmdjhbjlgp" # privacy badger
   #   #       "gpldannlkkicofjolkffchkpbcpioecc" # color picker
   #   #       "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
   #   #     ];
   #   #   };
   #   # }
   # ];
  };
}
