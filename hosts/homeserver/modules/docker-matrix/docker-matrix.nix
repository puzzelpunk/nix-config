{ config, lib, pkgs, options, ... }:
let
  fgetHomeserverConfig = import ./getHomeserverConfig.nix;
  fgetLogConfig = import ./getLogConfig.nix;
  fgetElementConfig = import ./getElementConfig.nix;
  # SECRET_KEY = "`cat ${config.age.secrets.glitchtip_key.path}`";
  dockercli = "${config.virtualisation.docker.package}/bin/docker";

  rootpath = "/Volumes/Server/docker/matrix";
  username = "matrix";
  guid = 991;
  dockerNetwork = "matrix";

  homeserverConfig = {
    domain = "cameron.computer";
    subdomain = "matrix";
    port = 8008;
    # TODO: use age secrets instead for password
    postgres = {
      user = "postgres";
      pass = "postgres";
      name = "postgres";
      host = "matrix-postgres";
    };
    enableRegistration = true;
  };

  homeserverConfigText = fgetHomeserverConfig { lib = lib; pkgs= pkgs; homeserverConfig = homeserverConfig; };
  logConfigText = fgetLogConfig { lib = lib; pkgs= pkgs; homeserverConfig = homeserverConfig; };
  elementConfig = fgetElementConfig { lib = lib; pkgs= pkgs; homeserverConfig = homeserverConfig; };

  initDockerNetworkScript = ''
    # Put a true at the end to prevent getting non-zero return code, which will
    # crash the whole service.

    check=$(${dockercli} network ls | grep "${dockerNetwork}" || true)
    
    if [ -z "$check" ]; then
      ${dockercli} network create ${dockerNetwork}
    else
      echo "${dockerNetwork} already exists in docker"
    fi
  '';

  initSynapseConfigScript = ''
    DATA_DIR=${rootpath}/synapse
    HOMESERVER_CONFIG_PATH=$DATA_DIR/homeserver.yaml
    LOG_CONFIG_PATH=$DATA_DIR/${homeserverConfig.subdomain}.${homeserverConfig.domain}.log.config 
    
    mkdir -p $DATA_DIR
    
    echo -e '${homeserverConfigText}' > $HOMESERVER_CONFIG_PATH
    echo -e '${logConfigText}' > $LOG_CONFIG_PATH

    chown -R ${builtins.toString guid}:${builtins.toString guid} ${rootpath}/synapse

    chmod 644 $HOMESERVER_CONFIG_PATH
    chmod 644 $LOG_CONFIG_PATH
  '';

  initElementConfigScript = ''
    DATA_DIR=${rootpath}/element
    CONFIG_PATH=$DATA_DIR/config.json

    echo -e '${elementConfig}' > $CONFIG_PATH

    chmod 644 $CONFIG_PATH
  '';
in {
  config = {
    users.groups."${username}" = {
      name = "${username}";
      gid = guid;
    };

    users.users."${username}" = {
      extraGroups = [ "${username}" ];
      name = "${username}";
      uid = guid;
      group = "${username}";
      home = rootpath;
    };

    systemd.services.matrix-docker-network-create = {
      description = "Create the network bridge for Matrix server docker services.";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";
      script = initDockerNetworkScript;
    };

    systemd.services.docker-matrix-synapse.preStart = initSynapseConfigScript;
    # systemd.services.docker-matrix-element.preStart = initSynapseConfigScript;

    virtualisation.oci-containers.containers.matrix-synapse = {
      image = "matrixdotorg/synapse:v1.107.0";
      volumes =  [ 
        "${rootpath}/synapse:/data" 
      ];
      # TODO: don't need to expose ports because we're using cloudflare tunnel
      # ports = [ "${builtins.toString homeserverConfig.port}:${builtins.toString homeserverConfig.port}" ];
      dependsOn = [ homeserverConfig.postgres.host ];
      # environmentFiles = [ "${rootpath}.env.secret" ];
      environment = {
          UID = builtins.toString guid;
          GID = builtins.toString guid;
      };
      # autoStart = false;
      extraOptions = [ "--network=${dockerNetwork}" ];
    };
      

    # virtualisation.oci-containers.containers.matrix-element = {
    #   image = "vectorim/element-web:v1.11.67";
    #   volumes = [ "${rootpath}/element/config.json:/app/config.json" ];
    #   # ports = [ "8010:80" ];
    #   dependsOn = [ "matrix-synapse" ];
    #   # environmentFiles = [ "${rootpath}.env.secret" ];
    #   extraOptions = [ "--network=${dockerNetwork}" ];
    # };

    # TODO: use matrix-user (or matrix db user)
    # https://github.com/docker-library/docs/blob/master/postgres/README.md#arbitrary---user-notes
    virtualisation.oci-containers.containers."${homeserverConfig.postgres.host}" = {
      image = "postgres:15";
      volumes = [
        "${rootpath}/postgres:/var/lib/postgresql/data"
      ];
      environment = {
        POSTGRES_USER = homeserverConfig.postgres.user;
        # TODO: Put db password in env.secret file and don't pass here
        POSTGRES_PASSWORD = homeserverConfig.postgres.pass;
        POSTGRES_DB = homeserverConfig.postgres.name;
        POSTGRES_INITDB_ARGS = "--encoding=UTF-8 --lc-collate=C --lc-ctype=C";
      };
      # environmentFiles = [ "${rootpath}.env.secret" ];
      extraOptions = [ "--network=${dockerNetwork}" ];
    };


    # TODO automate tunnel provisioning with https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/
    virtualisation.oci-containers.containers.matrix-tunnel = {
      image = "cloudflare/cloudflared:latest";
      environment = {
        # TODO Protect tunnel token in env.secrets for cloudflare tunnel
        TUNNEL_TOKEN = "eyJhIjoiZDdlMWJjNzM1MTY4NWU2YTczYThmZTc4ODgyMTM2YWYiLCJ0IjoiMWZhZjQzZTMtODg3My00YjdlLThiMDItZTk3ZDJjOWNhNDgzIiwicyI6Ik5tUmpOREEzTUdJdE5tUmhNQzAwWXpoakxXSmtNRE10TkdFNFpUVXhNRFZoTUdZeSJ9";
      };
      # entrypoint = "/bin/sh";
      cmd = [ 
        "tunnel"
        "--no-autoupdate"
        "run"
      ];
      extraOptions = [ "--network=${dockerNetwork}" ];
    };
  };
}