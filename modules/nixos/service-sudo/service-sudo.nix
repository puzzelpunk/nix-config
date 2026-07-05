{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  # TODO: consider making nopasswd commands authorable via cfg
  SudoersGroup = "wheel";

  NoPasswdCommands = [
    "/nix/var/nix/profiles/default/bin/npm"
    "/nix/var/nix/profiles/default/bin/openvpn"
    "/nix/var/nix/profiles/default/bin/vim"
    "/run/current-system/sw/bin/du"
    "/run/current-system/sw/bin/find"
    "/run/current-system/sw/bin/locate"
    "/run/current-system/sw/bin/mount"
    "/run/current-system/sw/bin/reboot"
    "/run/current-system/sw/bin/shutdown"
    "/run/current-system/sw/bin/systemctl"
    "/run/current-system/sw/bin/umount"
    "/run/current-system/sw/bin/nix-*"
    "/run/current-system/sw/bin/nixos-*"
  ];

  getSudoConfigFile = (
    group:
    (commands: ''
      # USER DEFINED RULES

      root ALL=(ALL) NOPASSWD: ALL
       
      %${group} ALL=(ALL) ALL
         
      ${concatStringsSep "\n" (map (cmd: "%" + group + " ALL=(ALL) NOPASSWD:" + cmd) commands)}
    '')
  );
in
{
  config.security.sudo = {
    enable = true;
    configFile = "";
    extraRules = [ ];
    extraConfig = getSudoConfigFile SudoersGroup NoPasswdCommands;
  };
}
