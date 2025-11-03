{ config, lib, pkgs, cloudflaredConfig, ... }:
let
  homeDir = cloudflaredConfig.homeDir;
  user = cloudflaredConfig.user or "cloudflared";
  tunnelName = cloudflaredConfig.tunnelName;
  accountIdAgePath = cloudflaredConfig.accountIdAgePath;
  accountIdPath = cloudflaredConfig.accountIdPath;
  apiAgePath = cloudflaredConfig.apiAgePath;
  apiPath = cloudflaredConfig.apiPath;
  emailAgePath = cloudflaredConfig.emailAgePath;
  emailPath = cloudflaredConfig.emailPath;

  createCloudflaredHome = pkgs.substituteAll {
    src = ./scripts/create-cloudflared-home.sh;
    isExecutable = true;
    homeDir = homeDir;
    user = user;
  };

  fetchOrCreateTunnel = pkgs.substituteAll {
    src = ./scripts/fetch-or-create-tunnel.sh;
    isExecutable = true;
    tunnelName = tunnelName;
    homeDir = homeDir; 
    user = user;
    accountIdPath = accountIdPath;
    emailPath = emailPath;
    apiPath = apiPath;
    curl = "${pkgs.curl}/bin/curl";
    jq = "${pkgs.jq}/bin/jq";
    bash = "${pkgs.bash}/bin/bash";
    ping = "${pkgs.iputils}/bin/ping";
  };

  fetchOriginCert = subdomain: pkgs.substituteAll {
    src = ./scripts/fetch-origin-cert.sh;
    isExecutable = true;
    subdomain = subdomain;
    homeDir = homeDir;
    accountIdPath = accountIdPath;
    emailPath = emailPath;
    apiPath = apiPath;
    curl = "${pkgs.curl}/bin/curl";
    jq = "${pkgs.jq}/bin/jq";
    bash = "${pkgs.bash}/bin/bash";
    ping = "${pkgs.iputils}/bin/ping";
  };

  cloudflareUpdateDNSScript = pkgs.substituteAll {
    src = ./scripts/update-dns.sh;
    isExecutable = true;
    tunnelName = tunnelName;
    homeDir = homeDir;
    accountIdPath = accountIdPath;
    emailPath = emailPath;
    apiPath = apiPath;
    ingress_domains = lib.concatStringsSep " " (builtins.attrNames config.services.cloudflared.tunnels.${tunnelName}.ingress);
    curl = "${pkgs.curl}/bin/curl";
    jq = "${pkgs.jq}/bin/jq";
    gawk = "${pkgs.gawk}/bin/awk";
    bash = "${pkgs.bash}/bin/bash";
    ping = "${pkgs.iputils}/bin/ping";
  };

  createExecStartScript = let
    filterConfig = lib.attrsets.filterAttrsRecursive (_: v: ! builtins.elem v [ null [ ] { } ]);

    filterIngressSet = lib.filterAttrs (_: v: builtins.typeOf v == "set");
    filterIngressStr = lib.filterAttrs (_: v: builtins.typeOf v == "string");

    ingressesSet = filterIngressSet config.services.cloudflared.tunnels.${tunnelName}.ingress;
    ingressesStr = filterIngressStr config.services.cloudflared.tunnels.${tunnelName}.ingress;

    fullConfig = filterConfig {
      tunnel = tunnelName;
      "credentials-file" = config.services.cloudflared.tunnels.${tunnelName}.credentialsFile;
      warp-routing = filterConfig config.services.cloudflared.tunnels.${tunnelName}.warp-routing;
      originRequest = filterConfig config.services.cloudflared.tunnels.${tunnelName}.originRequest;
      ingress =
        (map
          (key: {
            hostname = key;
          } // lib.getAttr key (filterConfig (filterConfig ingressesSet)))
          (lib.attrNames ingressesSet))
        ++
        (map
          (key: {
            hostname = key;
            service = lib.getAttr key ingressesStr;
          })
          (lib.attrNames ingressesStr))
        ++ 
        [{ service = config.services.cloudflared.tunnels.${tunnelName}.default; }];
    };

    mkConfigFile = pkgs.writeText "cloudflared.yml" (builtins.toJSON fullConfig);
  in pkgs.substituteAll {
    src = ./scripts/create-cloudflare-start-script.sh;
    isExecutable = true;
    tunnelName = tunnelName;
    homeDir = homeDir;
    user = user;
    cloudflared_package = config.services.cloudflared.package;
    jq = "${pkgs.jq}/bin/jq";
    config_file = mkConfigFile;
  };

  ingressDomains = builtins.attrNames config.services.cloudflared.tunnels.${tunnelName}.ingress;
  
  cloudflareOriginCertsScript = builtins.concatStringsSep "\n" (map fetchOriginCert ingressDomains);
in {
  age.secrets = {
    cf_account_id.file = accountIdAgePath;
    cf_account_email.file = emailAgePath;
    cf_account_api.file = apiAgePath;
  };

  systemd.services."cloudflared-tunnel-setup-${tunnelName}" = {
    description = "Create or update Cloudflare tunnel ${tunnelName}";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    # requires = [ "network-online.target" ];
    script = ''
      ${createCloudflaredHome}
      ${fetchOrCreateTunnel}
      ${createExecStartScript}
    '';
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
  };

  systemd.services."cloudflared-origin-certs-${tunnelName}" = {
    description = "Fetch Origin CA certificates for Cloudflare tunnel ${tunnelName} domains";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    # requires = [ "network-online.target" ];
    script = ''
      ${cloudflareOriginCertsScript}
    '';
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
  };

  systemd.services."cloudflared-update-dns-${tunnelName}" = {
    description = "Update DNS records for cloudflare tunnel ${tunnelName} domains";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "cloudflared-tunnel-${tunnelName}.service" ];
    # requires = [ "network-online.target" ];
    script = ''
      ${cloudflareUpdateDNSScript}
    '';
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
  };
 
  systemd.services."cloudflared-tunnel-${tunnelName}" = {
    after = [ "network-online.target" "cloudflared-tunnel-setup-${tunnelName}.service" ];
    requires = [ "cloudflared-tunnel-setup-${tunnelName}.service" ];
    serviceConfig = {
      Restart = "on-failure";
      ExecStart = lib.mkForce "${homeDir}/${tunnelName}_tunnel.sh";
      User = user;
      Group = user;
      WorkingDirectory = homeDir;
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = "HOME=${homeDir}";
    };
  };

  users.users.${user} = {
    isSystemUser = true;
    group = user;
    home = homeDir;
  };
  
  users.groups.${user} = { };

  services.cloudflared = {
    enable = true;
    tunnels.${tunnelName} = {
      credentialsFile = "${homeDir}/.${tunnelName}.json";
      default = "http_status:404";
    };
  };
}
