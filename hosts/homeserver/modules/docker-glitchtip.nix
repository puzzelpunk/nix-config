{ config, lib, pkgs, options, ... }:
let
  DATABASE_URL = "postgres://postgres:postgres@postgres:5432/postgres";
  SECRET_KEY = "`cat ${config.age.secrets.glitchtip_key.path}`";
  PORT = "8000";
  # Example smtp://email:password@smtp_url:port https://glitchtip.com/documentation/install#configuration
  EMAIL_URL = "consolemail://";
  GLITCHTIP_DOMAIN = "https://glitchtip.cameron.computer";
  DEFAULT_FROM_EMAIL = "contact@cameron.computer";
  # Scale between 1 and 3 to prevent excessive memory usage. Change it or remove to set it to the number of cpu cores.
  CELERY_WORKER_AUTOSCALE = "1,3";
  CELERY_WORKER_MAX_TASKS_PER_CHILD = "10000";

  POSTGRES_HOST_AUTH_METHOD = "trust";

  defaultDependsOn = [ "glitchtip_postgres" "glitchtip_redis" ];
in {
  config = {
    age.secrets = {
      glitchtip_key.file = ../../../secrets/glitchtip_key.age;
    };

    systemd.services.docker-glitchtip.preStart = ''
      ENV_FILE="/Volumes/Server/docker/glitchtip/.env.secret"

      SECRET_KEY=${SECRET_KEY}
      DATABASE_URL="${DATABASE_URL}"
      PORT="${PORT}"
      EMAIL_URL="${EMAIL_URL}"
      GLITCHTIP_DOMAIN="${GLITCHTIP_DOMAIN}"
      DEFAULT_FROM_EMAIL="${DEFAULT_FROM_EMAIL}"
      CELERY_WORKER_AUTOSCALE="${CELERY_WORKER_AUTOSCALE}"
      CELERY_WORKER_MAX_TASKS_PER_CHILD="${CELERY_WORKER_MAX_TASKS_PER_CHILD}"

      echo "DATABASE_URL=$DATABASE_URL" > $ENV_FILE
      echo "SECRET_KEY=$SECRET_KEY" >> $ENV_FILE
      echo "PORT=$PORT" >> $ENV_FILE
      echo "EMAIL_URL=$EMAIL_URL" >> $ENV_FILE
      echo "GLITCHTIP_DOMAIN=$GLITCHTIP_DOMAIN" >> $ENV_FILE
      echo "DEFAULT_FROM_EMAIL=$DEFAULT_FROM_EMAIL" >> $ENV_FILE
      echo "CELERY_WORKER_AUTOSCALE=$CELERY_WORKER_AUTOSCALE" >> $ENV_FILE
      echo "CELERY_WORKER_MAX_TASKS_PER_CHILD=$CELERY_WORKER_MAX_TASKS_PER_CHILD" >> $ENV_FILE

      chmod 600 $ENV_FILE
      chown root.root $ENV_FILE
    '';

    virtualisation.oci-containers.containers = {
      glitchtip_postgres = {
        image = "postgres:15";
        volumes = [
          "/Volumes/Server/docker/glitchtip/postgres:/var/lib/postgresql/data"
        ];
        environment = {
          POSTGRES_HOST_AUTH_METHOD = "${POSTGRES_HOST_AUTH_METHOD}";
        };
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtip_redis = {
        image = "redis";
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtip_web = {
        image = "glitchtip/glitchtip";
        volumes = [ "/Volumes/Server/docker/glitchtip/uploads:/code/uploads" ];
        ports = [ "${PORT}:8000" ];
        environmentFiles = [ "/Volumes/Server/docker/glitchtip/.env.secret" ];
        dependsOn = defaultDependsOn;
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtip_worker = {
        image = "glitchtip/glitchtip";
        entrypoint = "./bin/run-celery-with-beat.sh";
        environmentFiles = [ "/Volumes/Server/docker/glitchtip/.env.secret" ];
        dependsOn = defaultDependsOn;
        volumes = [ "/Volumes/Server/docker/glitchtip/uploads:/code/uploads" ];
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
      glitchtip_migrate = {
        image = "glitchtip/glitchtip";
        entrypoint = "./manage.py migrate";
        dependsOn = defaultDependsOn;
        environmentFiles = [ "/Volumes/Server/docker/glitchtip/.env.secret" ];
        extraOptions =
          [ "--network=${config.cfg.docker.networking.dockernet}" ];
      };
    };
  };
}
