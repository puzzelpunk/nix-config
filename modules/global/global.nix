{ config, lib, pkgs, ... }: 
with lib;
{
  imports = [ ./options.nix ];
  # TODO: probably a better way of referencing this.
  # this is a string path to a private key used to decrypt agenix secrets
  # i can't commit this private key and don't want to put private key in the nix store
  # so this is the workaround for now
  age.identityPaths = [ "${config.users.users."${config.cfg.user.name}".home}/_unixconf_nix/_/id_rsa" ];
  environment.systemPackages = with pkgs; [ nixfmt git vim age ];
  environment.variables.LANG = config.cfg.localization.lang;
  networking.hostName = config.cfg.os.hostname;
  nix.package = pkgs.nixUnstable;
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enable = true;
  time.timeZone = config.cfg.localization.timezone;

  # nix.settings.allowed-users = [ config.cfg.user.name ];
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
}
