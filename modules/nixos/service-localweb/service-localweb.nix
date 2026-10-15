# Local web — shared nginx backbone + the subdomain port + vhost registry.
#
# Centralizes nginx enable + recommended settings + ACME, and provides
# cfg.localweb.vhosts — a server_name → { host, port, scheme?, extraLocations?,
# extraConfig?, basicAuthFile? } map (the nginx analog of cloudflared's ingress)
# so service modules register a subdomain + backend in one entry and this module
# emits the listen/proxyPass/auth/firewall plumbing. Opens port 80 so vhosts are
# reachable on the LAN by name.
#
# The escape hatches (scheme, extraLocations, extraConfig) keep this module
# context-generic: an app that needs an HTTPS upstream (authentik on :9443),
# static assets (/static/), or websockets (/ws/) supplies those via the registry
# entry — localweb doesn't need to know about authentik. Composes with
# service-dns (dnsmasq resolves *.<internalDomain> → this host) and cloudflared
# (public domain ingress). A vhost with a basicAuthFile is password-gated — the
# module declares the age secret (group = nginx) and wires the decrypted runtime
# path; callers just supply the .age file.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  cfg = config.cfg.localweb;

  # agenix is optional — the module still works without it (no authed vhosts).
  hasAgenix = builtins.hasAttr "age" options;

  # vhosts that carry a basicAuthFile and so need an age secret declared.
  authedVhosts = filterAttrs (_: v: v.basicAuthFile != null) cfg.vhosts;

  # Stable secret name per vhost (server_name → attr key / /run/agenix filename).
  secretName = name: "localweb-${builtins.replaceStrings [ "." ] [ "-" ] name}";

  # Root "/" location for a vhost: proxyPass to the backend, recommended proxy
  # headers, and proxy_ssl_verify off when the upstream speaks HTTPS (self-signed
  # / internal certs — e.g. authentik on :9443). The root location is owned by
  # this module; app-specific extra locations go in `extraLocations`. When
  # forwardAuth is set, auth_request is added to gate access via authentik.
  rootLocation = v:
    let
      parts =
        (optional (v.scheme == "https") "proxy_ssl_verify off;")
        ++ (optional (v.forwardAuth != null) "auth_request /outpost.goauthentik.io/auth;")
        ++ (optional (v.proxyHostHeader != null) ''
          proxy_set_header Host ${v.proxyHostHeader};
          proxy_set_header Origin http://${v.proxyHostHeader};
        '');
    in
    {
      proxyPass = "${v.scheme}://${v.host}:${toString v.port}";
      recommendedProxySettings = true;
    }
    // optionalAttrs (v.proxyWebsockets) {
      proxyWebsockets = true;
    }
    // optionalAttrs (parts != [ ]) {
      extraConfig = concatStringsSep "\n" parts;
    };

  # Forward-auth locations for a vhost: the internal auth subrequest handler,
  # the public outpost proxy (for redirects/callbacks), and the named login
  # redirect. Added to the vhost's locations when forwardAuth is set.
  forwardAuthLocations = v: optionalAttrs (v.forwardAuth != null) {
    "= /outpost.goauthentik.io/auth" = {
      recommendedProxySettings = false;
      extraConfig = ''
        internal;
        proxy_pass ${v.forwardAuth.outpostUrl}/outpost.goauthentik.io/auth/nginx;
        proxy_set_header Host $host;
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Cookie $http_cookie;
      '';
    };
    "/outpost.goauthentik.io/" = {
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_pass ${v.forwardAuth.outpostUrl};
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
    "@authentik_login" = {
      extraConfig = ''
        return 302 $scheme://$http_host/outpost.goauthentik.io/start?rd=$request_uri;
      '';
    };
  };
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable (mkMerge [
    {
      security.acme.acceptTerms = true;
      security.acme.defaults.email = config.cfg.user.email;

      services.nginx = {
        enable = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
      };

            # One virtualHost per registered vhost on the shared subdomain port 80
      # (server_name routing). basicAuthFile, when set, points at the
      # agenix-decrypted htpasswd (declared below) so the nginx worker can read it.
      # scheme/extraLocations/extraConfig are passed through verbatim — this
      # module stays generic, app-specific nginx lives in the registering module.
      # forwardAuth, when set, adds auth_request + the authentik outpost locations.
      services.nginx.virtualHosts = mapAttrs (name: v:
        let
          faExtra = optionalAttrs (v.forwardAuth != null) {
            extraConfig = "error_page 401 = @authentik_login;";
          };
        in
        {
          listen = [ { addr = "0.0.0.0"; port = 80; } ];
          locations = { "/" = rootLocation v; }
            // forwardAuthLocations v
            // v.extraLocations;
        }
        // optionalAttrs (v.extraConfig != "") { extraConfig = v.extraConfig; }
        // faExtra
        // optionalAttrs (v.basicAuthFile != null && hasAgenix) {
          basicAuthFile = config.age.secrets.${secretName name}.path;
        }
      ) cfg.vhosts;

      # Shared subdomain port — every vhost is reachable by name once open.
      networking.firewall.allowedTCPPorts = optional cfg.openFirewall 80;
    }

    # Declare an age secret per authed vhost, group-readable by nginx so the
    # worker can read the decrypted htpasswd at request time.
    (mkIf hasAgenix {
      age.secrets = mapAttrs' (name: v:
        nameValuePair (secretName name) {
          file = v.basicAuthFile;
          group = "nginx";
        }
      ) authedVhosts;
    })

    # An authed vhost requires agenix on the host (to decrypt the htpasswd).
    {
      assertions = [
        {
          assertion = !(any (v: v.basicAuthFile != null) (attrValues cfg.vhosts)) || hasAgenix;
          message = "cfg.localweb.vhosts.*.basicAuthFile requires agenix on the host (to decrypt the htpasswd).";
        }
      ];
    }
  ]);
}