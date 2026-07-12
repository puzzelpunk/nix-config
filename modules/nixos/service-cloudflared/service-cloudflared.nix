{
  config,
  lib,
  pkgs,
  cloudflaredConfig,
  ...
}:
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
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  gawk = "${pkgs.gawk}/bin/awk";
  bash = "${pkgs.bash}/bin/bash";
  ping = "${pkgs.iputils}/bin/ping";

  createCloudflaredHome = pkgs.replaceVars ./scripts/create-cloudflared-home.sh {
    homeDir = homeDir;
    user = user;
  };

  fetchOrCreateTunnel = pkgs.replaceVars ./scripts/fetch-or-create-tunnel.sh {
    tunnelName = tunnelName;
    homeDir = homeDir;
    user = user;
    accountIdPath = accountIdPath;
    emailPath = emailPath;
    apiPath = apiPath;
    curl = curl;
    jq = jq;
    bash = bash;
    ping = ping;
  };

  cloudflareUpdateDNSScript = pkgs.replaceVars ./scripts/update-dns.sh {
    tunnelName = tunnelName;
    homeDir = homeDir;
    accountIdPath = accountIdPath;
    emailPath = emailPath;
    apiPath = apiPath;
    ingress_domains = lib.concatStringsSep " " (
      builtins.attrNames config.services.cloudflared.tunnels.${tunnelName}.ingress
    );
    curl = curl;
    jq = jq;
    gawk = gawk;
    bash = bash;
    ping = ping;
  };

  createExecStartScript =
    let
      filterConfig = lib.attrsets.filterAttrsRecursive (
        _: v:
        !builtins.elem v [
          null
          [ ]
          { }
        ]
      );

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
          (map (
            key:
            {
              hostname = key;
            }
            // lib.getAttr key (filterConfig (filterConfig ingressesSet))
          ) (lib.attrNames ingressesSet))
          ++ (map (key: {
            hostname = key;
            service = lib.getAttr key ingressesStr;
          }) (lib.attrNames ingressesStr))
          ++ [ { service = config.services.cloudflared.tunnels.${tunnelName}.default; } ];
      };

      mkConfigFile = pkgs.writeText "cloudflared.yml" (builtins.toJSON fullConfig);
    in
    pkgs.replaceVars ./scripts/create-cloudflare-start-script.sh {
      tunnelName = tunnelName;
      homeDir = homeDir;
      user = user;
      cloudflared_package = config.services.cloudflared.package;
      jq = jq;
      config_file = mkConfigFile;
    };
in
{
  age.secrets = {
    cf_account_id.file = accountIdAgePath;
    cf_account_email.file = emailAgePath;
    cf_account_api.file = apiAgePath;
  };

  systemd.services."cloudflared-tunnel-setup-${tunnelName}" = {
    description = "Create or update Cloudflare tunnel ${tunnelName}";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    script = ''
      ${bash} ${createCloudflaredHome}
      ${bash} ${fetchOrCreateTunnel}
      ${bash} ${createExecStartScript}
    '';
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
  };

  systemd.services."cloudflared-update-dns-${tunnelName}" = {
    description = "Update DNS records for cloudflare tunnel ${tunnelName} domains";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "cloudflared-tunnel-${tunnelName}.service"
    ];
    requires = [ "network-online.target" ];
    script = ''
      ${bash} ${cloudflareUpdateDNSScript}
    '';
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
  };

  systemd.services."cloudflared-tunnel-${tunnelName}" = {
    after = [
      "network-online.target"
      "cloudflared-tunnel-setup-${tunnelName}.service"
    ];
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
