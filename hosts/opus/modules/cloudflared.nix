{ config, lib, pkgs, ... }:

let
  cloudflared_home_dir = "/Volumes/Server/cloudflared";
  tunnel_name = config.networking.hostName;
  cf_account_id = config.age.secrets.cf_account_id.path;
  cf_account_email = config.age.secrets.cf_account_email.path;
  cf_account_api = config.age.secrets.cf_account_api.path;

  fetchOrCreateTunnel = ''
    TUNNEL_ID=$(${pkgs.curl}/bin/curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$(cat ${cf_account_id})/cfd_tunnel" \
      -H "X-Auth-Email: $(cat ${cf_account_email})" \
      -H "X-Auth-Key: $(cat ${cf_account_api})" \
      | ${pkgs.jq}/bin/jq -r '.result[] | select(.name == "${tunnel_name}" and .deleted_at == null) | .id')

    if [ -z "$TUNNEL_ID" ]; then
      TUNNEL_ID=$(${pkgs.curl}/bin/curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$(cat ${cf_account_id})/cfd_tunnel" \
        -H "X-Auth-Email: $(cat ${cf_account_email})" \
        -H "X-Auth-Key: $(cat ${cf_account_api})" \
        -H "Content-Type: application/json" \
        --data '{"name":"${tunnel_name}","config":{}}' \
        | ${pkgs.jq}/bin/jq -r '.result.id')
    fi

    ACCOUNT_TAG=$(${pkgs.curl}/bin/curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$(cat ${cf_account_id})/cfd_tunnel/$TUNNEL_ID" \
      -H "X-Auth-Email: $(cat ${cf_account_email})" \
      -H "X-Auth-Key: $(cat ${cf_account_api})" \
      | ${pkgs.jq}/bin/jq -r '.result.account_tag')

    TUNNEL_SECRET=$(${pkgs.curl}/bin/curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$(cat ${cf_account_id})/cfd_tunnel/$TUNNEL_ID/token" \
      -H "X-Auth-Email: $(cat ${cf_account_email})" \
      -H "X-Auth-Key: $(cat ${cf_account_api})" \
      | ${pkgs.jq}/bin/jq -r '.result')

    echo "{\"AccountTag\":\"$ACCOUNT_TAG\",\"TunnelSecret\":\"$TUNNEL_SECRET\",\"TunnelID\":\"$TUNNEL_ID\"}" > ${cloudflared_home_dir}/.${tunnel_name}.json
    chmod 600  ${cloudflared_home_dir}/.${tunnel_name}.json
    chown cloudflared:cloudflared  ${cloudflared_home_dir}/.${tunnel_name}.json
  '';

  fetchOriginCert = subdomain: ''
    ${pkgs.curl}/bin/curl -X POST "https://api.cloudflare.com/client/v4/certificates" \
      -H "X-Auth-Email: $(cat ${cf_account_email})" \
      -H "X-Auth-Key: $(cat ${cf_account_api})" \
      -H "Content-Type: application/json" \
      --data '{"hostnames":["${subdomain}"],"requested_validity":5184000}' \
      | ${pkgs.jq}/bin/jq -r '.result.certificate' > ${cloudflared_home_dir}/${subdomain}.pem

    ${pkgs.curl}/bin/curl -X POST "https://api.cloudflare.com/client/v4/certificates" \
      -H "X-Auth-Email: $(cat ${cf_account_email})" \
      -H "X-Auth-Key: $(cat ${cf_account_api})" \
      -H "Content-Type: application/json" \
      --data '{"hostnames":["${subdomain}"],"requested_validity":5184000}' \
      | ${pkgs.jq}/bin/jq -r '.result.private_key' > ${cloudflared_home_dir}/${subdomain}.key
  '';

  createExecStartScript = let
    filterConfig = lib.attrsets.filterAttrsRecursive (_: v: ! builtins.elem v [ null [ ] { } ]);

    filterIngressSet = lib.filterAttrs (_: v: builtins.typeOf v == "set");
    filterIngressStr = lib.filterAttrs (_: v: builtins.typeOf v == "string");

    ingressesSet = filterIngressSet config.services.cloudflared.tunnels.${tunnel_name}.ingress;
    ingressesStr = filterIngressStr config.services.cloudflared.tunnels.${tunnel_name}.ingress;

    fullConfig = filterConfig {
      tunnel = tunnel_name;
      "credentials-file" = config.services.cloudflared.tunnels.${tunnel_name}.credentialsFile;
      warp-routing = filterConfig config.services.cloudflared.tunnels.${tunnel_name}.warp-routing;
      originRequest = filterConfig config.services.cloudflared.tunnels.${tunnel_name}.originRequest;
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
        ++ [{ service = config.services.cloudflared.tunnels.${tunnel_name}.default; }];
    };

    mkConfigFile = pkgs.writeText "cloudflared.yml" (builtins.toJSON fullConfig);
    script = ''
      #!/bin/sh
      ${config.services.cloudflared.package}/bin/cloudflared tunnel --config=${mkConfigFile} --no-autoupdate run --token '$(${pkgs.jq}/bin/jq -r '.TunnelSecret' ${cloudflared_home_dir}/.${tunnel_name}.json)'
    '';
  in ''
    echo -e "${script}" > ${cloudflared_home_dir}/${tunnel_name}_tunnel.sh
    chmod 750  ${cloudflared_home_dir}/${tunnel_name}_tunnel.sh
    chown cloudflared:cloudflared  ${cloudflared_home_dir}/${tunnel_name}_tunnel.sh
  '';

  ingressDomains = builtins.attrNames config.services.cloudflared.tunnels.${tunnel_name}.ingress;
  
  cloudflareOriginCertsScript = builtins.concatStringsSep "\n" (map fetchOriginCert ingressDomains);
  cloudflareUpdateDNSScript = ''
    get_domain() {  
      domain=$1
      echo "$domain" | ${pkgs.gawk}/bin/awk -F. '{n = NF; if ($(n-1) == "co" || $(n-1) == "com") {print $(n-2) "." $(n-1) "." $n} else {print $(n-1) "." $n}}'
    }
    get_zone_id() {
      domain=$1
      zone_id=$(${pkgs.curl}/bin/curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
        -H "X-Auth-Email: $(cat ${cf_account_email})" \
        -H "X-Auth-Key: $(cat ${cf_account_api})" \
        | ${pkgs.jq}/bin/jq -r '.result[0].id')
      echo $zone_id
    }
    
    update_cname_record() {
      subdomain=$1
      zone_id=$2
      cname_target=$3
      echo "Setting CNAME record of $subdomain to $cname_target"

      # Check if the DNS record exists

      record_id=$(${pkgs.curl}/bin/curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$subdomain&type=CNAME" \
        -H "X-Auth-Email: $(cat ${cf_account_email})" \
        -H "X-Auth-Key: $(cat ${cf_account_api})" \
        | ${pkgs.jq}/bin/jq -r '.result[0].id')

      if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        # Update existing CNAME record

        ${pkgs.curl}/bin/curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
          -H "X-Auth-Email: $(cat ${cf_account_email})" \
          -H "X-Auth-Key: $(cat ${cf_account_api})" \
          -H "Content-Type: application/json" \
          --data '{"type":"CNAME","name":"'"$subdomain"'","content":"'"$cname_target"'","ttl":120,"proxied":true}'

        echo "Updated CNAME for $subdomain"
      else
        # Create new CNAME record

        ${pkgs.curl}/bin/curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
          -H "X-Auth-Email: $(cat ${cf_account_email})" \
          -H "X-Auth-Key: $(cat ${cf_account_api})" \
          -H "Content-Type: application/json" \
          --data '{"type":"CNAME","name":"'"$subdomain"'","content":"'"$cname_target"'","ttl":120,"proxied":true}'

        echo "Created CNAME for $subdomain"
      fi
    }
    
    CNAME="$(${pkgs.jq}/bin/jq -r '.TunnelID' ${cloudflared_home_dir}/.${tunnel_name}.json).cfargotunnel.com"

    for subdomain in ${builtins.concatStringsSep " " (map (subdomain: subdomain) ingressDomains)}; do
      domain=$(get_domain $subdomain)
      zone_id=$(get_zone_id $domain)
      update_cname_record $subdomain $zone_id $CNAME
    done
  '';
in {
  age.secrets = {
    cf_account_id.file = ../../../secrets/cf_account_id.age;
    cf_account_email.file = ../../../secrets/cf_account_email.age;
    cf_account_api.file = ../../../secrets/cf_account_api.age;
  };

  systemd.services.cloudflared-tunnel-setup = {
    description = "Create or update Cloudflare tunnel";
    wantedBy = [ "multi-user.target" ];
    before = [ "cloudflared.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      ${fetchOrCreateTunnel}
      ${createExecStartScript}
    '';
  };

  systemd.services.cloudflared-origin-certs = {
    description = "Fetch Origin CA certificates for Cloudflare tunnel domains";
    wantedBy = [ "multi-user.target" ];
    before = [ "cloudflared.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = cloudflareOriginCertsScript;
  };
  systemd.services.cloudflared-update-dns = {
    description = "Update DNS records for cloudflare tunnel domains";
    wantedBy = [ "multi-user.target" ];
    after = [ "cloudflared-tunnel-${tunnel_name}.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = cloudflareUpdateDNSScript;
  };
 
  systemd.services."cloudflared-tunnel-${tunnel_name}".serviceConfig.ExecStart = lib.mkForce "${cloudflared_home_dir}/${tunnel_name}_tunnel.sh";

  services.cloudflared = {
    enable = true;
    tunnels.${tunnel_name} = {
      credentialsFile = "${cloudflared_home_dir}/.${tunnel_name}.json";
      default = "http_status:404";
      ingress = {
        # Define your ingress rules here
      };
    };
  };
}
