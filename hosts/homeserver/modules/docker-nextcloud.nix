{ config, lib, pkgs, options, ... }: {
  config = {
    age.secrets = {
      nextcloud_mysql_password.file = ../../../secrets/nextcloud_mysql_password.age;
      nextcloud_mysql_root_password.file = ../../../secrets/nextcloud_mysql_root_password.age;
    };

    systemd.services.docker-nextcloud_db.preStart = '' 
      ENV_FILE="/Volumes/Server/docker/nextcloud/.env.secret"

      MYSQL_PASSWORD=`cat ${config.age.secrets.nextcloud_mysql_password.path}`
      MYSQL_ROOT_PASSWORD=`cat ${config.age.secrets.nextcloud_mysql_root_password.path}`

      echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" > $ENV_FILE
      echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> $ENV_FILE

      chmod 600 $ENV_FILE
      chown root.root $ENV_FILE
    '';

    virtualisation.oci-containers.containers = {
      nextcloud = {
        image = "lscr.io/linuxserver/nextcloud:latest";
        volumes = [
          "/Volumes/Server/docker/nextcloud/appdata:/config"
          "/Volumes/Server/docker/nextcloud/data:/data"
          "/Volumes/Storage:/Volumes/Storage" # external storage
        ];
        environment = {
          PUID = "1000";
          PGID = "996";
          TZ = "America/Chicago";
        };
        extraOptions = [ 
          "--network=${config.cfg.docker.networking.dockernet}"
          "--label=swag=enable"
        ];
        dependsOn = [ "nextcloud_db" ];
      };

      nextcloud_db = {
        image = "lscr.io/linuxserver/mariadb:latest";
        volumes = [ "/Volumes/Server/docker/nextcloud/mariadb:/config" ];
        environment = {
          PUID = "1000";
          PGID = "996";
          TZ = "America/Chicago";
          MYSQL_DATABASE = "nextcloud_db";
          MYSQL_USER = "nextcloud_db";
        };
        environmentFiles = [ /Volumes/Server/docker/nextcloud/.env.secret ];
        extraOptions = [ 
	  "--network=${config.cfg.docker.networking.dockernet}" 
	];
      };
    };
  };
}
