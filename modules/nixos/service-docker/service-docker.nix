{ config, lib, pkgs, options, ... }:
with pkgs.stdenv;
with lib; {
  imports = [ 
    ./options.nix
    (import ./dockernet-create.nix {
      config = config;
      lib = lib;
      pkgs = pkgs;
      dockernetConfig = {
        networkName = config.cfg.docker.networking.dockernet;
      };
    })
  ];

  config = {
    users.groups.docker = { };
    users.users."${config.cfg.user.name}".extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [ docker-compose docker-client ];

    virtualisation.oci-containers.backend = "docker";

    virtualisation.docker = {
      enable = true;
      storageDriver = "overlay2";
      extraOptions = ''
        --bip="${config.cfg.docker.networking.bip}" --data-root="${config.cfg.docker.storage_root}" --dns="${config.cfg.docker.networking.dns.primary}" --dns="${config.cfg.docker.networking.dns.secondary}" --iptables=${config.cfg.docker.networking.iptables}'';
    };
  };
}
