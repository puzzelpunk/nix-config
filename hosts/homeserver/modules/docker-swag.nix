{ config, lib, pkgs, options, ... }: {
  config = {
    age.secrets = {
      cf_account_id.file = ../../../secrets/cf_account_id.age;
      cf_api_token.file = ../../../secrets/cf_api_token.age;
      cf_tunnel_password.file = ../../../secrets/cf_tunnel_password.age;
      cf_zone_id.file = ../../../secrets/cf_zone_id.age;
    };

    systemd.services.docker-swag.preStart = '' 
      ENV_FILE="/Volumes/Server/docker/swag/.env.secret"

      CF_ACCOUNT_ID=`cat ${config.age.secrets.cf_account_id.path}`
      CF_TUNNEL_PASSWORD=`cat ${config.age.secrets.cf_tunnel_password.path}`
      CF_API_TOKEN=`cat ${config.age.secrets.cf_api_token.path}`
      CF_ZONE_ID=`cat ${config.age.secrets.cf_zone_id.path}`

      echo "CF_ACCOUNT_ID=$CF_ACCOUNT_ID" > $ENV_FILE
      echo "CF_TUNNEL_PASSWORD=$CF_TUNNEL_PASSWORD" >> $ENV_FILE
      echo "CF_API_TOKEN=$CF_API_TOKEN" >> $ENV_FILE
      echo "CF_ZONE_ID=$CF_ZONE_ID" >> $ENV_FILE

      chmod 600 $ENV_FILE
      chown root:root $ENV_FILE
    '';

    virtualisation.oci-containers.containers = {
      swag = {
        image = "lscr.io/linuxserver/swag";
        volumes = [ 
          "/Volumes/Server/docker/swag/config:/config"
          "/Volumes/Server/docker/swag/secrets:/secrets"
        ];
        environment = {
          PUID = "1000";
          PGID = "996";
          TZ = "America/Chicago";
          URL = "cameron.computer";
          SUBDOMAINS = "wildcard";
          VALIDATION = "dns";
          DNSPLUGIN = "cloudflare";
          EMAIL = "csanders@protonmail.com";
          DOCKER_MODS= "linuxserver/mods:swag-auto-proxy|linuxserver/mods:universal-docker|linuxserver/mods:universal-cloudflared";
          DOCKER_HOST = "dockerproxy";
          CF_TUNNEL_NAME = "cameron.computer";
          FILE__CF_TUNNEL_CONFIG = "/config/tunnelconfig.yml";
        };
        environmentFiles = [ /Volumes/Server/docker/swag/.env.secret ];
        extraOptions = [ 
          "--network=${config.cfg.docker.networking.dockernet}"
          "--add-host=cameron.computer:127.0.0.1"
          "--cap-add=NET_ADMIN"
        ];
      };

      dockerproxy = {
        image = "ghcr.io/tecnativa/docker-socket-proxy";
        volumes = [ "/var/run/docker.sock:/var/run/docker.sock:ro" ];
        environment = {
          CONTAINERS = "1";
          POST = "0"; 
        };
        extraOptions = [ 
	  "--network=${config.cfg.docker.networking.dockernet}" 
	];
      };
    };

    # networking.firewall.allowedTCPPorts = [ 443 ];
  };
}
