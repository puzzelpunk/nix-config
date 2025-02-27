{ config, lib, pkgs, options, ... }:
let
  resilio_public_domain = "resilio.sanders.zone";
  resilio_dir = "/Volumes/Server/sanderszone/resilio";
  resilio_web_port = 9000;
in {
  services.resilio = {
    enable = true;
    enableWebUI = true;
    storagePath = resilio_dir;
    deviceName = config.cfg.os.hostname;
    httpListenAddr = "0.0.0.0";
    httpListenPort = resilio_web_port;
    directoryRoot = "/Volumes/Storage";
  };
  
  users.users."${config.cfg.user.name}".extraGroups = [ "rslsync" ];
  users.users.rslsync.extraGroups = [ "sharedfiles" ];

  networking.firewall.allowedTCPPorts = [ resilio_web_port ];
}
