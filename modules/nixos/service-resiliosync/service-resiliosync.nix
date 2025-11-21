{ config, lib, pkgs, ... }:
{
  imports = [
    ./options.nix
  ];
  services.resilio = {
    enable = true;
    enableWebUI = true;
    storagePath = config.cfg.resiliosync.storagePath;
    deviceName = config.cfg.resiliosync.resilioPublicDomain;
    httpListenAddr = "0.0.0.0";
    httpListenPort = config.cfg.resiliosync.webPort;
    directoryRoot = config.cfg.resiliosync.directoryRoot;
  };
  
  users.users."${config.cfg.user.name}".extraGroups = [ "rslsync" ];
  users.users.rslsync.extraGroups = [ "sharedfiles" config.cfg.user.name ];

  networking.firewall.allowedTCPPorts = [ config.cfg.resiliosync.webPort ];
}
