# { config, lib, pkgs, options, ... }: 
# let
#   # nginx_proxy_conf = builtins.readFile ./docker-nextcloud-nginx.conf;
#   # nginx_proxy_conf_path = pkgs.writeText "nginx_proxy_conf" nginx_proxy_conf;
# in {
#   config = {
#     age.secrets = {
#       nextcloud_mysql_password.file = ../../../secrets/nextcloud_mysql_password.age;
#       nextcloud_mysql_root_password.file = ../../../secrets/nextcloud_mysql_root_password.age;
#     };

#     # systemd.services.docker-nextcloud_db.preStart = ''
#     #   SWAG_DIR="/Volumes/Server/docker/cybercrescendo/swag"
#     #   NGINX_PROXY_CONF_DIR="$SWAG_DIR/config/nginx/proxy-confs"
#     #   mkdir -p $NGINX_PROXY_CONF_DIR

#     #   # NGIX_PROXY_CONF_FILE=`cat ${nginx_proxy_conf_path}`
#     #   # echo "$NGIX_PROXY_CONF_FILE" > $NGINX_PROXY_CONF_DIR/nextcloud.subdomain.conf

#     #   ENV_FILE="/Volumes/Server/docker/cybercrescendo/nextcloud/.env.secret"

#     #   MYSQL_PASSWORD=`cat ${config.age.secrets.nextcloud_mysql_password.path}`
#     #   MYSQL_ROOT_PASSWORD=`cat ${config.age.secrets.nextcloud_mysql_root_password.path}`

#     #   echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" > $ENV_FILE
#     #   echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> $ENV_FILE

#     #   chmod 600 $ENV_FILE
#     #   chown root.root $ENV_FILE
#     # '';

#     virtualisation.oci-containers.containers = {
#       nextcloud = {
#         image = "lscr.io/linuxserver/nextcloud:latest";
#         volumes = [
#           "/Volumes/Server/docker/cybercrescendo/nextcloud/appdata:/config"
#           "/Volumes/Server/docker/cybercrescendo/nextcloud/data:/data"
#           # "/Volumes/Storage:/Volumes/Storage" # external storage
#         ];
#         environment = {
#           PUID = "1000";
#           PGID = "996";
#           TZ = "America/Chicago";
#         };
#         extraOptions = [ 
#           "--network=cybercrescendo"
#           "--label=swag=enable"
#         ];
#         dependsOn = [ "nextcloud_db" ];
#       };

#       nextcloud_db = {
#         image = "lscr.io/linuxserver/mariadb:latest";
#         volumes = [ "/Volumes/Server/docker/cybercrescendo/nextcloud/mariadb:/config" ];
#         environment = {
#           PUID = "1000";
#           PGID = "996";
#           TZ = "America/Chicago";
#           MYSQL_DATABASE = "nextcloud_db";
#           MYSQL_USER = "nextcloud_db";
#         };
#         environmentFiles = [ /Volumes/Server/docker/cybercrescendo/nextcloud/.env.secret ];
#         extraOptions = [ "--network=cybercrescendo" ];
#       };
#     };
#   };
# }
