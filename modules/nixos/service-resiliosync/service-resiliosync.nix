{ config, lib, pkgs, ... }:
with pkgs.stdenv;
with lib;
{
  imports = [ ./options.nix ];
  config = mkMerge [
    {
      networking.firewall.allowedTCPPorts = [ config.cfg.resiliosync.webPort ];

      services.resilio = {
        enable = true;
        enableWebUI = true;
        storagePath = config.cfg.resiliosync.storagePath;
        deviceName = config.cfg.resiliosync.resilioPublicDomain;
        httpListenAddr = "0.0.0.0";
        httpListenPort = config.cfg.resiliosync.webPort;
        directoryRoot = config.cfg.resiliosync.directoryRoot;
      };
    }
    (mkIf (config.cfg.resiliosync.user == "rslsync") {
      users.users."${config.cfg.user.name}".extraGroups = [ "rslsync" ];
      users.users.rslsync.extraGroups = [ "sharedfiles" ];
    })
    (mkIf (config.cfg.resiliosync.user != "rslsync") {
      users.groups.rslsync = mkForce {};
      users.users.rslsync.enable = mkForce false;
      systemd.services.resilio.serviceConfig.User = mkForce config.cfg.resiliosync.user;
    })
  ];
}
