{ config, lib, pkgs, options, ... }:
let
  SECRET_KEY = "`cat ${config.age.secrets.glitchtip_key.path}`";


  rootpath = "/Volumes/Server/docker/glitchtip/";
  username = "glitchtip";
  guid = 5000;


  defaultEnvironment = {
    DATABASE_URL = "postgres://postgres:postgres@glitchtippostgres:5432/postgres";
    REDIS_URL = "redis://glitchtipredis:6379/0";
    PORT = "8000";
    EMAIL_URL = "consolemail://"; # Example smtp://email:password@smtp_url:port https://glitchtip.com/documentation/install#configuration
    GLITCHTIP_DOMAIN = "https://glitchtip.cameron.computer";
    DEFAULT_FROM_EMAIL = "contact@cameron.computer"; # Scale between 1 and 3 to prevent excessive memory usage. Change it or remove to set it to the number of cpu cores.
    CELERY_WORKER_AUTOSCALE = "1,3";
    CELERY_WORKER_MAX_TASKS_PER_CHILD = "10000";
  };

  defaultDependsOn = [ "glitchtippostgres" "glitchtipredis" ];

  dockerPrestart = ''
    ENV_FILE="${rootpath}.env.secret"

    SECRET_KEY=${SECRET_KEY}
  
    echo "SECRET_KEY=$SECRET_KEY" > $ENV_FILE

    chmod 600 $ENV_FILE
    chown ${username}:${username} $ENV_FILE
  '';
in {
  config = {
    age.secrets = {
      glitchtip_key.file = ../../../secrets/glitchtip_key.age;
    };

    users.groups."${username}" = {
      name = "${username}";
      gid = guid;
    };
    users.users."${username}" = {
      extraGroups = [ "${username}" ];
      name = "${username}";
      uid = guid;
      group = "${username}";
      isNormalUser = true;
      home = rootpath;
    };

    systemd.services.docker-glitchtip.preStart = dockerPrestart;
    systemd.services.docker-glitchtipworker.preStart = dockerPrestart;
    systemd.services.docker-glitchtipmigrate.preStart = dockerPrestart;

    virtualisation.oci-containers.containers = {
      glitchtippostgres = {
        image = "postgres:15";
        volumes = [
          "${rootpath}postgres:/var/lib/postgresql/data"
        ];
        environment = {
          POSTGRES_HOST_AUTH_METHOD = "trust";
        };
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtipredis = {
        image = "redis";
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtip = {
        image = "glitchtip/glitchtip";
        volumes = [ "${rootpath}uploads:/code/uploads" ];
        ports = [ "${defaultEnvironment.PORT}:8000" ];
        environment = defaultEnvironment;
        environmentFiles = [ "${rootpath}.env.secret" ];
        dependsOn = defaultDependsOn;
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtipworker = {
        image = "glitchtip/glitchtip";
        environment = defaultEnvironment;
        environmentFiles = [ "${rootpath}.env.secret" ];
        dependsOn = defaultDependsOn;
        volumes = [ "${rootpath}uploads:/code/uploads" ];
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
        entrypoint = "/bin/bash";
        cmd = [ "/code/bin/run-celery-with-beat.sh" ];
      };
      glitchtipmigrate = {
        image = "glitchtip/glitchtip";
        dependsOn = defaultDependsOn;
        environment = defaultEnvironment;
        environmentFiles = [ "${rootpath}.env.secret" ];
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
        entrypoint = "/usr/local/bin/python";
        cmd = [ 
          "/code/manage.py" 
          "migrate" 
        ];
      };
    };
  };
}
