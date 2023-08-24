{ config, lib, pkgs, ... }:
with pkgs.stdenv; 
with lib; {
  imports = [ ./modules.nix ./options.nix ];

  nix.settings.allowed-users = [ config.cfg.user.name ];
  nix.settings.trusted-users = [ config.cfg.user.name ];

  users.users."${config.cfg.user.name}" = (mkMerge [
    (if config.cfg.os.name == "nixos" then {
      createHome = true;
      extraGroups = [ "wheel" ];
      group = config.cfg.user.name;
      home = "/home/${config.cfg.user.name}";
      isNormalUser = true;
    } else {})
    ( if config.cfg.os.name == "macos" then {
      home = "/Users/${config.cfg.user.name}";
    } else {})
    ({
      name = config.cfg.user.name;
      shell = pkgs.zsh;
    })
  ]);

  users.groups."${config.cfg.user.name}" = (mkMerge [
    (if config.cfg.os.name == "nixos" then { 
      name = config.cfg.user.name; 
    } else {})
    (if config.cfg.os.name == "macos" then { 
      name = "staff"; 
    } else {})
  ]);

  home-manager.users."${config.cfg.user.name}" = {
    home.stateVersion = config.cfg.os.version;
    
    programs.git = {
      enable = true;
      userName = config.cfg.user.name;
      userEmail = config.cfg.user.email;
    };
  };
}
