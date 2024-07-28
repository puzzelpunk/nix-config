{ config, lib, pkgs, options, ... }: {
  config = {
    age.secrets = {
      vscode_hashed_password.file = ../../../secrets/vscode_hashed_password.age;
    };

    systemd.services.docker-code-server.preStart = '' 
      ENV_FILE="/Volumes/Server/docker/vscode/.env.secret"

      HASHED_PASSWORD=`cat ${config.age.secrets.vscode_hashed_password.path}`

      echo "HASHED_PASSWORD=$HASHED_PASSWORD" > $ENV_FILE

      chmod 600 $ENV_FILE
      chown root.root $ENV_FILE
    '';

    virtualisation.oci-containers.containers = {
      code-server = {
        image = "lscr.io/linuxserver/code-server:latest";
        ports = [ "${config.cfg.networking.static.ip_address}:8443:8443" ];
        volumes = [ "/Volumes/Server/docker/vscode/config:/config" ];
        environment = {
          PUID = "1000";
          PGID = "996";
          TZ = "America/Chicago";
          # SUDO_PASSWORD_HASH= #optional
          # PROXY_DOMAIN = "code-server.cameron.computer"; #optional
          # DEFAULT_WORKSPACE=/config/workspace #optional
        };
        environmentFiles = [ /Volumes/Server/docker/vscode/.env.secret ];
        extraOptions = [ 
          "--network=${config.cfg.docker.networking.dockernet}"
          "--label=swag=enable"
        ];
      };
    };
    # networking.firewall.allowedTCPPorts = [ 8443 ];
  };
}
