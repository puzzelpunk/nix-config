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
    httpListenAddr = "0.0.0.0";
    httpListenPort = resilio_web_port;
    directoryRoot = "/Volumes/Storage";
  };
  
  users.users."${config.cfg.user.name}".extraGroups = [ "rslsync" ];

  networking.firewall.allowedTCPPorts = [ resilio_web_port ];
  # virtualisation.oci-containers.containers = {
  #   resilio-sync = {
  #     image = "linuxserver/resilio-sync";
  #     ports = [ 
  #       "${config.cfg.networking.static.ip_address}:8888:8888" 
  #       "${config.cfg.networking.static.ip_address}:55555:55555" 
  #     ];
  #     volumes = [
  #       "/Volumes/Server/docker/resiliosync/config:/config"
  #       "/Volumes/Server/docker/resiliosync/downloads:/downloads"
  #       "/Volumes/Storage:/sync"
  #     ];
  #     environment = {
  #       PUID = "1000";
  #       PGID = "996";
  #       TZ = "America/Chicago";
  #     };
  #     extraOptions = [ 
  #       "--network=${config.cfg.docker.networking.dockernet}" 
  #       "--label=swag=enable" 
  #     ];
  #   };
  # };

  # networking.firewall.allowedTCPPorts = [
  #   8888
  #   55555
  # ];
}
