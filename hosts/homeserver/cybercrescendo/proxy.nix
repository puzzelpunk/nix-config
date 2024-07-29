{ config, lib, pkgs, options, ... }: 
let 
  cloudflared_home_dir = "/Volumes/Server/cybercrescendo/cloudflared";
  cloudflared_credentials_file = "${cloudflared_home_dir}/.cloudflared_credentials.json";
  cloudflared_tunnel_id = "07c9f962-1f28-42ec-bc26-f997937bc678";
  cloudflared_tunnel_service = "cloudflared-tunnel-${cloudflared_tunnel_id}";
in {
  age.secrets = {
    # cf_account_api.file = ../../../secrets/cf_account_api.age;
    # cf_account_email.file = ../../../secrets/cf_account_email.age;
    cf_cc_tunnel_credentials.file = ../../../secrets/cf_cc_tunnel_credentials.age;
  };

  systemd.services.cloudflared-credentials-setup = {
    description = "Create Nextcloud admin password file";
    wantedBy = [ "multi-user.target" ];
    before = [ "${cloudflared_tunnel_service}.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      HOME_DIR="${cloudflared_home_dir}"
      mkdir -p $HOME_DIR

      CLOUDFLARED_CREDENTIALS=`cat ${config.age.secrets.cf_cc_tunnel_credentials.path}`
      CLOUDFLARED_CREDENTIALS_FILE="${cloudflared_credentials_file}"

      echo "$CLOUDFLARED_CREDENTIALS" > $CLOUDFLARED_CREDENTIALS_FILE

      chmod 600 $CLOUDFLARED_CREDENTIALS_FILE
      chown -R cloudflared:cloudflared $HOME_DIR
    '';
  };

  systemd.services."${cloudflared_tunnel_service}" = {
    requires = ["cloudflared-credentials-setup.service"];
    after = ["cloudflared-credentials-setup.service"];
  };

  services.cloudflared = {
    enable = true;
    tunnels."${cloudflared_tunnel_id}" = {
      credentialsFile = cloudflared_credentials_file;
      default = "http_status:404";
      ingress = {
        # "cybercrescendo.com" = "http://localhost:80";
        # "*.cybercrescendo.com" = "http://localhost:80";
      };
    };
  };

  ## TODO: not sure if this is needed since using cloudflared as a reverse proxy
  ## cloudflared automatically sets up ssl certificates
  # security.acme = {
  #   acceptTerms = true;
  #   defaults = {
  #     email = config.cfg.user.email;
  #     dnsProvider = "cloudflare";
  #     dnsResolver = "1.1.1.1:53";
  #     dnsPropagationCheck = true;
  #     credentialFiles = {
  #       CF_API_EMAIL_FILE = config.age.secrets.cf_account_email.path;
  #       CF_API_KEY_FILE = config.age.secrets.cf_account_api.path;
  #     };
  #     # Use staging server.
  #     # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
  #   };
  # };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };
}
