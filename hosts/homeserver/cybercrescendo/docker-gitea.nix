{ config, lib, pkgs, options, ... }: {
  config = {
    virtualisation.oci-containers.containers = {
      gitea = {
        image = "gitea/gitea:1.17.1";
        ports = [ 
          "${config.cfg.networking.static.ip_address}:3000:3000"
          "${config.cfg.networking.static.ip_address}:222:22"
        ];
        volumes = [
          "/Volumes/Server/docker/cybercrescendo/gitea:/data"
          "/etc/timezone:/etc/timezone:ro"
          "/etc/localtime:/etc/localtime:ro"
        ];
        environment = {
          USER_UID = "1000";
          USER_GID = "992";
        };
        extraOptions = [ 
          "--network=cybercrescendo"
          "--label=swag=enable"
        ];
      };
    };

    # networking.firewall.allowedTCPPorts = [ 3000 222 ];
  };
}
