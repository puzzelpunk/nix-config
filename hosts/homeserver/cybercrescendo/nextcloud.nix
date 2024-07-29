{ config, lib, pkgs, options, ... }: 
let 
  nextcloud_home_dir = "/Volumes/Server/cybercrescendo/nextcloud";
  nextcloud_admin_password_file = "${nextcloud_home_dir}/.nextcloud_admin_password";
  nextcloud_public_domain = "nextcloud.cybercrescendo.com";
  nextcloud_private_domain = "homeserver.local";
  nextcloud_local_port = 8080;
in {
  age.secrets = {
    nextcloud_admin_password.file = ../../../secrets/nextcloud_admin_password.age;
  };

  ## TODO the nixos module for nextcloud does this automatically.
  # services.postgresql = {
  #   ensureDatabases = [ "nextcloud" ];
  #   ensureUsers = [
  #    { name = "nextcloud";
  #      ensureDBOwnership = true;
  #    }
  #   ];
  # };

  # Database backups.
  services.postgresqlBackup.databases = [config.services.nextcloud.config.dbname];

  # Open the Nextcloud port.
  networking.firewall.allowedTCPPorts = [ nextcloud_local_port ];

  # Create the Nextcloud admin password file.
  systemd.services.nextcloud-password-setup = {
    description = "Create Nextcloud admin password file";
    wantedBy = [ "multi-user.target" ];
    before = [ "nextcloud-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      HOME_DIR="${nextcloud_home_dir}"
      mkdir -p $HOME_DIR

      NEXTCLOUD_ADMIN_PASSWORD=`cat ${config.age.secrets.nextcloud_admin_password.path}`
      NEXTCLOUD_ADMIN_PASSWORD_FILE="${nextcloud_admin_password_file}"

      echo "$NEXTCLOUD_ADMIN_PASSWORD" > $NEXTCLOUD_ADMIN_PASSWORD_FILE

      chmod 600 $NEXTCLOUD_ADMIN_PASSWORD_FILE
      chown -R nextcloud:nextcloud $HOME_DIR
    '';
  };

  # Ensure Nextcloud admin password file exists before Nextcloud setup.
  systemd.services."nextcloud-setup" = {
    requires = ["nextcloud-password-setup.service"];
    after = ["nextcloud-password-setup.service"];
  };

  # Nextcloud nginx config
  services.nginx.virtualHosts = {
    "${nextcloud_public_domain}" = {
      ## Not using certbot because cloudflared handles the SSL.
      # enableACME = true;
      # acmeRoot = null; # Use DNS-01 Challenge.
      # forceSSL = true;
      listen = [ { 
        port = nextcloud_local_port; 
        addr = "0.0.0.0"; 
        # ssl = true; # Cloudflared handles the SSL.
      } ];
      locations."/" = { 
        proxyPass = "http://127.0.0.1:${builtins.toString nextcloud_local_port}"; 
        proxyWebsockets = true; 
      };
    };
  };

  # Cloudflared config
  services.cloudflared = {
    tunnels."07c9f962-1f28-42ec-bc26-f997937bc678" = {
      ingress = {
        "${nextcloud_public_domain}" = "http://localhost:${builtins.toString nextcloud_local_port}";
      };
    };
  };
  
  # Nextcloud config
  services.nextcloud = {
    enable = true;
    hostName = nextcloud_public_domain;
    home = nextcloud_home_dir;
    # Need to manually increment with every major upgrade.
    package = pkgs.nextcloud29;
    # Let NixOS install and configure the database automatically.
    database.createLocally = true;
    # Let NixOS install and configure Redis caching automatically.
    configureRedis = true;
    # Increase the maximum file upload size.
    maxUploadSize = "16G";

    settings = {
      # overwriteProtocol = "https"; # Cloudflared handles the SSL.
      default_phone_region = "US";
      trusted_domains = [ nextcloud_private_domain ];
    };

    config = {
      # dbuser = "nextcloud";
      # dbpassFile = nextcloud_admin_password_file;
      # adminuser = "root";
      dbtype = "pgsql";
      adminpassFile = nextcloud_admin_password_file;
    };

    # Suggested by Nextcloud's health check.
    phpOptions."opcache.interned_strings_buffer" = "16";

    # appstoreEnable = true;
    # extraApps = with config.services.nextcloud.package.packages.apps; {
    #   # List of apps we want to install and are already packaged in
    #   # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
    #   inherit calendar contacts notes onlyoffice tasks cookbook qownnotesapi;
    #   # Custom app example.
    #   socialsharing_telegram = pkgs.fetchNextcloudApp rec {
    #     url =
    #       "https://github.com/nextcloud-releases/socialsharing/releases/download/v3.0.1/socialsharing_telegram-v3.0.1.tar.gz";
    #     license = "agpl3";
    #     sha256 = "sha256-8XyOslMmzxmX2QsVzYzIJKNw6rVWJ7uDhU1jaKJ0Q8k=";
    #   };
    # };
  };
}