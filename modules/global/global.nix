{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  imports = [ ./options.nix ];

  environment.systemPackages = with pkgs; [
    nixfmt
    git
    vim
    age
    nil
    nixd
  ];
  environment.variables.LANG = config.cfg.localization.lang;
  networking.hostName = config.cfg.os.hostname;
  nix.optimise.automatic = true;
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enable = true;
  time.timeZone = config.cfg.localization.timezone;

  # nix.settings.allowed-users = [ config.cfg.user.name ];
  nix.settings.trusted-users = [ config.cfg.user.name ];

  users.users."${config.cfg.user.name}" = (
    mkMerge [
      (
        if config.cfg.os.name == "nixos" then
          {
            createHome = true;
            extraGroups = [ "wheel" ];
            group = config.cfg.user.name;
            home = "/home/${config.cfg.user.name}";
            isNormalUser = true;
            autoSubUidGidRange = true;
          }
        else
          { }
      )
      (
        if config.cfg.os.name == "nixos" && config.cfg.user.uid != null then
          { uid = config.cfg.user.uid; }
        else
          { }
      )
      (
        if config.cfg.os.name == "macos" then
          {
            home = "/Users/${config.cfg.user.name}";
          }
        else
          { }
      )
      ({
        name = config.cfg.user.name;
        shell = pkgs.zsh;
      })
    ]
  );

  users.groups."${config.cfg.user.name}" = (
    mkMerge [
      (
        if config.cfg.os.name == "nixos" then
          {
            name = config.cfg.user.name;
          }
        else
          { }
      )
      (
        if config.cfg.os.name == "nixos" && config.cfg.user.gid != null then
          { gid = config.cfg.user.gid; }
        else
          { }
      )
      (
        if config.cfg.os.name == "macos" then
          {
            name = "staff";
          }
        else
          { }
      )
    ]
  );

  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  ''
  + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';
}
