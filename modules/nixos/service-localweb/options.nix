{
  lib,
  ...
}:
with lib;
{
  options.cfg.localweb = {
    enable = mkEnableOption "the shared nginx web backbone (subdomain port 80)";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the firewall for port 80 so LAN/VPN clients reach subdomain vhosts
        by name. Defaults to true — the module owns the shared HTTP port.
      '';
    };

    # ── ACME: DNS-01 certificates for TLS vhosts ────────────────────────────
    acme = mkOption {
      type = types.submodule {
        options = {
          dnsProvider = mkOption {
            type = types.str;
            default = "cloudflare";
            description = ''
              lego DNS provider id used for ACME DNS-01 challenges (the
              security.acme.certs dnsProvider value). "cloudflare" covers any
              zone with DNS on Cloudflare, including the internal
              "*.lan.<domain>" names (they live in the real zone's TXT space).
            '';
          };
          dnsCredentials = mkOption {
            type = types.attrsOf types.path;
            default = { };
            example = literalExpression ''
              {
                CLOUDFLARE_DNS_API_TOKEN = ./secrets/dns-token.age;
              }
            '';
            description = ''
              DNS API credentials for answering DNS-01 challenges, keyed by
              the env var name lego's DNS provider expects. The module
              declares each value as an age secret and assembles
              KEY=value lines into the env-style credential file lego reads
              at issuance and renewal. For cloudflare: a scoped API token
              maps to CLOUDFLARE_DNS_API_TOKEN, the global key to
              CLOUDFLARE_API_KEY + CLOUDFLARE_EMAIL. Empty = no TLS vhost
              may be declared on this host.
            '';
          };
        };
      };
      default = { };
      description = "ACME/DNS-01 settings for the TLS vhost registry.";
    };

    vhosts = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "Backend host to proxy to (the proxyPass target host).";
            };
            port = mkOption {
              type = types.port;
              description = "Backend port to proxy to (the proxyPass target port).";
            };

            # ── Generic escape hatches (no app-specific knowledge here) ────────
            scheme = mkOption {
              type = types.enum [ "http" "https" ];
              default = "http";
              description = ''
                Upstream scheme for the root proxyPass. "https" fronts an
                HTTPS upstream (e.g. authentik on :9443); the module then emits
                `proxy_ssl_verify off` on the root location so a self-signed /
                internal upstream cert is accepted. Use the `extraLocations`
                escape hatch to add any per-location ssl bits for non-root
                locations you add.
              '';
            };

            extraLocations = mkOption {
              type = types.attrsOf types.attrs;
              default = { };
              description = ''
                Extra nginx location blocks merged into this vhost's
                `locations`, keyed by location string (e.g. "/static/",
                "/ws/"). Values are location-config attrsets (proxyPass,
                alias, proxyWebsockets, extraConfig, ...) — the same shape as
                `services.nginx.virtualHosts.<name>.locations.<path>`. Lets an
                app module add its own locations (static assets, websockets,
                auth callbacks) through the registry without localweb knowing
                why. The root "/" location is owned by this module and should
                not be overridden here.
              '';
            };

            extraConfig = mkOption {
              type = types.str;
              default = "";
              description = ''
                Raw nginx config appended to the vhost's server block
                (services.nginx.virtualHosts.<name>.extraConfig). Use for ad
                hoc server-level directives none of the typed options cover.
              '';
            };

            basicAuthFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Age-encrypted htpasswd file for HTTP basic auth on this vhost.
                null = no auth. This module declares the age secret with
                group = "nginx" (so the nginx worker can read the decrypted file
                at request time) and wires the runtime path into the nginx vhost
                - callers just provide the .age file. Generate the htpasswd with e.g.
                `htpasswd -cB hermes_htpasswd <user>` then agenix-encrypt it.
                Plaintext passwords must never be in the Nix store.
              '';
            };

            forwardAuth = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  outpostUrl = mkOption {
                    type = types.str;
                    default = "http://127.0.0.1:9005";
                    description = ''
                      URL of the authentik proxy outpost HTTP listener.
                      nginx sends auth_request subrequests here.
                    '';
                  };
                };
              });
              default = null;
              description = ''
                Enable authentik forward auth (nginx auth_request) for this
                vhost. When set, unauthenticated requests redirect to authentik
                login; authenticated requests proceed to the backend. The
                authentik module auto-sets this on vhosts matching
                cfg.authentik.apps hostnames.
              '';
            };

            proxyHostHeader = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Override the Host header sent to the backend. When null, the
                default $host (the incoming request hostname) is used. Set to
                e.g. "localhost" for backends that validate the Host header
                against their bind address and reject external hostnames —
                nginx still sends X-Forwarded-Host with the original hostname
                (via recommendedProxySettings) so the backend can generate
                correct redirect URLs.
              '';
            };

            proxyWebsockets = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Enable WebSocket proxying on the root location. Adds
                proxy_set_header Upgrade and Connection upgrade headers,
                overriding the recommendedProxySettings Connection "" that
                would otherwise prevent WebSocket upgrades. Set to true for
                apps that use WebSockets (e.g. chat, live dashboards).
              '';
            };

            tls = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Terminate TLS with an ACME-issued certificate for this vhost's
                server_name. Requires cfg.localweb.acme.dnsCredentialFile (an
                age file containing a DNS API token for the zone). nginx
                serves :443 ssl and the :80 vhost 301s to https; the backend
                still receives plain http with X-Forwarded-Proto=https.
                Apps whose prod-mode cookies are forced Secure (outline)
                require this. The cert is publicly trusted (Let's Encrypt
                via DNS-01), so no CA distribution is needed on clients.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Subdomain vhosts, keyed by server_name — the nginx analog of
        cloudflared's ingress map. Service modules register their web UI here
        (one entry: backend host + port) and this module emits the nginx
        virtualHost (listen on 80, proxyPass, recommended proxy settings) and
        opens the firewall. Requires the host to run service-dns for the
        server_name to resolve on the LAN. Set basicAuthFile for a vhost that
        must be password-gated (e.g. a public-domain vhost fronting cloudflared).
        Use scheme/extraLocations/extraConfig for backends that need more than a
        plain HTTP root proxy (HTTPS upstreams, static assets, websockets).
      '';
    };
  };
}