# Local DNS (dnsmasq) — split-horizon zone for *.<internalDomain> → host IP.
#
# Serves a wildcard A record so every vhost server_name under the internal
# zone resolves to this host without per-service DNS records — the standard
# building block for subdomain-based access to local web services. Non-local
# queries are forwarded to cfg.networking.domain_name_servers (set by
# service-networking), so upstream resolution is unchanged. The host's own
# resolver can optionally be repointed at the local dnsmasq (useAsHostResolver)
# so the host resolves its own zone.
#
# For LAN clients to use this resolver, the network's DHCP DNS must point at
# this host — that step is environment-specific (router/gateway config) and
# belongs in the host config, not this module.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  cfg = config.cfg.localdns;
in
{
  imports = [ ./options.nix ];

  config = mkMerge [
    # Computed read-only value, set unconditionally so other modules and the
    # host can reference config.cfg.localdns.internalDomain even when disabled.
    { cfg.localdns.internalDomain = "${cfg.label}.${cfg.domain}"; }

    (mkIf cfg.enable {
      services.dnsmasq = {
        enable = true;
        settings = {
          # Hygiene: don't forward bare hostnames or RFC1918 reverse lookups.
          domain-needed = true;
          bogus-priv = true;

          # Only use the explicit `server=` lines below, not /etc/resolv.conf —
          # avoids a loop when useAsHostResolver repoints the host to 127.0.0.1.
          no-resolv = true;

          # Keep the internal zone local (never forwarded upstream).
          local = [ "/${cfg.internalDomain}/" ];

          # Wildcard: *.internalDomain AND internalDomain → address.
          address =
            [ "/${cfg.internalDomain}/${cfg.address}" ]
            ++ (mapAttrsToList (name: ip: "/${name}/${ip}") cfg.extraRecords);

          # Upstream forwarders — compose with service-networking's
          # domain_name_servers (the host's existing upstream/gateway).
          server = [
            config.cfg.networking.domain_name_servers.primary
            config.cfg.networking.domain_name_servers.secondary
          ];
        };
      };

      # Repoint the host's own resolver at the local dnsmasq so the host
      # resolves its own internal zone. mkForce wins over service-networking's
      # static `networking.nameservers = [...]` (plain assignment, priority 100).
      # dnsmasq forwards non-local queries to the original upstreams, so nothing
      # is lost.
      networking.nameservers = mkIf cfg.useAsHostResolver (mkForce [ "127.0.0.1" ]);

      networking.firewall = mkIf cfg.openFirewall {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      };
    })
  ];
}