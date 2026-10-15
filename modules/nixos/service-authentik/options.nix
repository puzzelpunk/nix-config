{
  lib,
  ...
}:
with lib;
{
  options.cfg.authentik = {
    enable = mkEnableOption "Authentik identity provider";

    # ── Freeform config (full authentik config.yml surface) ──────────────
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Freeform authentik config, rendered to /etc/authentik/config.yml and
        deep-merged with the typed shorthands below (email, database). This is
        the full escape hatch — any key from authentik's config reference can
        be set here and never lags upstream. Typed shorthands are merged
        underneath, so keys here win on leaf conflicts. Never put secrets here
        (the Nix store is world-readable) — use cfg.authentik.secrets.
      '';
    };

    # ── Typed shorthands ──────────────────────────────────────────────────
    email = mkOption {
      type = types.submodule {
        freeformType = types.attrs;
        options = {
          host = mkOption {
            type = types.str;
            default = "localhost";
            description = "SMTP host.";
          };
          port = mkOption {
            type = types.port;
            default = 25;
            description = "SMTP port.";
          };
          username = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              SMTP username. The password is NOT set here — declare it via
              cfg.authentik.secrets.AUTHENTIK_EMAIL__PASSWORD.
            '';
          };
          use_tls = mkOption {
            type = types.bool;
            default = false;
            description = "Use STARTTLS for SMTP.";
          };
          use_ssl = mkOption {
            type = types.bool;
            default = false;
            description = "Use implicit TLS (SMTPS) for SMTP.";
          };
          from = mkOption {
            type = types.str;
            default = "authentik@localhost";
            description = "From address for authentik email.";
          };
        };
      };
      default = { };
      description = ''
        Email shorthand → settings.email. The SMTP password is a secret —
        declare it via cfg.authentik.secrets.AUTHENTIK_EMAIL__PASSWORD (the env
        var authentik reads for the password).
      '';
    };

    database = mkOption {
      type = types.submodule {
        options = {
          create = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Let this module provision a local postgresql database + user via
              services.authentik.createDatabase. Set false to use an external
              database (configure settings.postgresql yourself via
              cfg.authentik.settings). The local postgres data lives at
              services.postgresql.dataDir (default /var/lib/postgresql) —
              relocate it separately if you need it on an external drive; this
              option does not manage the postgres data directory.
            '';
          };
        };
      };
      default = { };
      description = "Database configuration shorthand.";
    };

    # ── Secrets (agenix) ─────────────────────────────────────────────────
    secrets = mkOption {
      type = types.attrsOf types.path;
      default = { };
      example = literalExpression ''
        {
          AUTHENTIK_SECRET_KEY = ./secrets/authentik-secret-key.age;
          AUTHENTIK_EMAIL__PASSWORD = ./secrets/authentik-email.age;
        }
      '';
      description = ''
        Age-encrypted secrets injected as environment variables at runtime.
        Each attribute maps an env var name (as authentik expects it, e.g.
        AUTHENTIK_SECRET_KEY, AUTHENTIK_EMAIL__PASSWORD) to an age-encrypted
        file containing the raw value. The module declares the age secrets and
        assembles them into a single environment file consumed by
        services.authentik.environmentFile — values are decrypted to /run/agenix
        and never written to the Nix store. Requires agenix on the host.

        AUTHENTIK_SECRET_KEY is mandatory (authentik won't start without it);
        generate one with `openssl rand -base64 60`.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Non-secret environment variables for the authentik server/worker/migrate
        (written to the Nix store — do NOT put secrets here). Applied via systemd
        Environment, not the env file (which is secrets only). Bootstrap email
        (AUTHENTIK_BOOTSTRAP_EMAIL) is added here automatically.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a pre-existing environment file (systemd EnvironmentFile format)
        — the escape hatch for another secrets backend. Used only when
        cfg.authentik.secrets is empty (otherwise the module's assembled env file
        is used). Provide AUTHENTIK_SECRET_KEY (and any other required vars) in it.
      '';
    };

    # ── Outposts ─────────────────────────────────────────────────────────
    outposts = mkOption {
      type = types.submodule {
        options = {
          proxy = {
            enable = mkEnableOption "the authentik proxy outpost";
            # The proxy outpost serves nginx auth_request forward auth for apps
            # registered in cfg.authentik.apps (the forward-auth wiring lands in
            # a follow-up; enabling the outpost now makes it available).
            listenHTTP = mkOption {
              type = types.str;
              default = "127.0.0.1:9005";
              description = ''
                Listen address for the proxy outpost HTTP server. nginx
                auth_request subrequests hit this. The default binds IPv4
                loopback — nginx (on the same host) reaches it; the browser
                reaches it via the /outpost.goauthentik.io/ location on the
                app vhost.
              '';
            };
            tokenKeyFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Age-encrypted file containing the raw outpost token key. The
                module auto-provisions the outpost + token in authentik's
                database on every boot via an `ak shell` oneshot, setting the
                token key to this value — no admin UI step needed and
                reprovision-safe (the key is in the age secret, not
                auto-generated). Generate with e.g. `openssl rand -hex 32`,
                agenix-encrypt the raw value. Required when
                outposts.proxy.enable is true.
              '';
            };
          };
          ldap = {
            enable = mkEnableOption "the authentik LDAP outpost";
            listen = mkOption {
              type = types.str;
              default = "0.0.0.0:3389";
              description = ''
                Listen address for the LDAP outpost. LDAP clients (Nextcloud,
                Gitea, Jellyfin, ...) bind here. The default 0.0.0.0:3389
                exposes it on the LAN — gate it via firewall or bind loopback +
                a tunnel for apps that don't run on this host. Port 3389 avoids
                the privileged 389.
              '';
            };
            tokenKeyFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Age-encrypted file containing the raw outpost token key. Same
                convention as outposts.proxy.tokenKeyFile. Required when
                outposts.ldap.enable is true.
              '';
            };
          };
        };
      };
      default = { };
      description = ''
        Authentik outposts. The proxy outpost serves nginx forward auth
        (auth_request) for web apps; the LDAP outpost serves apps that
        authenticate via LDAP. Each enabled outpost needs a token key —
        declare it via outposts.<name>.tokenKeyFile (an age-encrypted file
        with the raw key). The module auto-provisions the outpost + token in
        authentik's database on every boot via an `ak shell` oneshot, so no
        admin UI step is needed and the setup is reprovision-safe.
      '';
    };

    # ── NixOS-only: service knobs ────────────────────────────────────────
    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/authentik";
      description = ''
        On-disk location of authentik state (the database is separate — see
        cfg.authentik.database). Upstream uses systemd StateDirectory=authentik
        with DynamicUser, which is kept intact; when this is not the default
        /var/lib/authentik, the module adds a bind mount
        /var/lib/authentik ← stateDir so the bytes physically live on the
        configured path (e.g. /Volumes/Server/authentik) while upstream's
        StateDirectory handling keeps working. Place this on a backup-covered
        path to survive a reimage.

        NB: the parent of stateDir must already be mounted (the bind mount
        depends on it). For /Volumes/Server/authentik that means /Volumes/Server
        — already mounted by the host's filesystems config.
      '';
    };

    # ── Admin web UI (authentik's own dashboard) ──────────────────────────
    dashboard = mkOption {
      type = types.submodule {
        options = {
          domain = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              server_name for the authentik admin UI nginx vhost. When null
              and service-dns (cfg.localdns) is enabled, this defaults to
              "auth" under the internal zone (auth.<internalDomain>) — so a
              homelab running service-dns only needs cfg.authentik.enable, no
              explicit domain. Set explicitly to override the auto-derived
              subdomain. Requires service-localweb on the host (the admin UI
              is fronted by nginx on the shared port 80, not by upstream's
              services.authentik.nginx, which this module leaves off). nginx
              proxies to authentik's HTTP listener (loopback:9000) so the
              external scheme is driven by X-Forwarded-Proto (http on port 80,
              https if the vhost is later TLS-fronted) — see the adminVhost
              comment in service-authentik.nix for why :9000 not :9443.
            '';
          };

          publicDomain = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Public domain for the authentik admin UI via cloudflared (e.g.
              auth.example.com). When set, registers a SECOND localweb vhost
              keyed by this domain (same backend) and points the cloudflared
              ingress at nginx (port 80). Requires service-cloudflared on the
              host. The admin UI is gated by authentik's own login — no nginx
              basicAuth is added (unlike a raw web app, authentik authenticates
              itself).
            '';
          };
        };
      };
      default = { };
      description = ''
        Authentik's own admin web UI. Local access is automatic when
        service-localweb + service-dns are on the host (an "auth" subdomain is
        registered on port 80). nginx proxies to authentik's HTTP listener
        (loopback:9000); the external scheme follows X-Forwarded-Proto. Public
        access is via dashboard.publicDomain (cloudflared) — authentik's own
        login gates the admin UI.
      '';
    };

    # ── Forward-auth app registry → auto-generated proxy blueprint ──────────
    apps = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          host = mkOption {
            type = types.str;
            description = ''
              External host URL for the app (e.g.
              "http://my-app.lan.example.com"). Used as the proxy provider's
              external_host — the URL users access the app at, and the
              server_name nginx matches for the auth_request subrequest.
            '';
          };
          internalHost = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Internal backend URL for the app (e.g.
              "http://127.0.0.1:8080"). Only used in proxy mode (the
              outpost itself proxies traffic). Leave null for forward_auth
              mode (nginx proxies, the outpost only handles auth_request).
            '';
          };
          mode = mkOption {
            type = types.enum [ "forward_single" "forward_domain" "proxy" ];
            default = "forward_single";
            description = ''
              Proxy provider mode. `forward_single` is the standard nginx
              auth_request pattern (one subdomain per app). `forward_domain`
              is for wildcard/domain-level forward auth. `proxy` makes the
              outpost itself proxy traffic to internalHost (no nginx needed).
            '';
          };
          metaLaunchUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Launch URL for the app in authentik's app launcher. Defaults to
              the host URL.
            '';
          };
        };
      });
      default = { };
      description = ''
        Applications registered for authentik proxy forward auth. Each app
        auto-generates a ProxyProvider + Application in authentik via a
        blueprint (applied on every boot), and is assigned to the proxy
        outpost. No admin UI step needed — the blueprint is the source of
        truth. Requires outposts.proxy.enable + outposts.proxy.tokenKeyFile.
      '';
    };

    # ── Bootstrap: one-time akadmin seed (skips the /setup flow) ───────────
    bootstrap = mkOption {
      type = types.submodule {
        options = {
          email = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Email for the akadmin user, seeded on first start (while no admin
              exists). Non-secret — stored in the Nix store. Set together with a
              password to skip the /setup flow and pre-create the admin.
            '';
          };
          passwordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Age-encrypted file containing the plaintext akadmin password
              (mapped to AUTHENTIK_BOOTSTRAP_PASSWORD, read only on first
              start). Mutually exclusive with passwordHashFile. The file is
              decrypted to /run and assembled into the root-only env file —
              never the Nix store.
            '';
          };
          passwordHashFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Age-encrypted file containing a pre-hashed akadmin password (the
              value of AUTHENTIK_BOOTSTRAP_PASSWORD_HASH). Preferred over
              passwordFile. Generate the hash with the upstream `ak` helper
              (e.g. `ak hash_password`). Mutually exclusive with passwordFile.
            '';
          };
          tokenFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Age-encrypted file containing an API token for akadmin
              (AUTHENTIK_BOOTSTRAP_TOKEN), seeded on first start. Lets you drive
              authentik via API/Terraform after bootstrap without a GUI login.
            '';
          };
        };
      };
      default = { };
      description = ''
        One-time bootstrap of the akadmin user (skips the /setup flow). Read by
        authentik only on the first startup while no admin exists; afterwards
        ignored (manage the admin via the UI/API/blueprints). For ongoing
        declarative config (apps, providers, flows, outposts), use
        cfg.authentik.blueprints.
      '';
    };

    # ── Blueprints: declarative config-as-code ───────────────────────────────
    blueprints = mkOption {
      type = types.attrsOf (types.either types.path types.attrs);
      default = { };
      example = literalExpression ''
        {
          hermes-forward-auth = {
            version = 1;
            metadata.name = "hermes-forward-auth";
            metadata.labels."blueprints.goauthentik.io/instantiate" = "true";
            entries = [ { ... } ];
          };
        }
      '';
      description = ''
        Custom authentik blueprints, keyed by filename (without .yaml). Each
        value is either a path to a YAML file or (preferred) a Nix attrset
        rendered to YAML — so the config lives in Nix and is validated at build.
        Blueprints are auto-discovered and applied on startup (and re-applied
        periodically); use them to declaratively define applications, providers
        (proxy/LDAP/OIDC), outposts, flows, users, groups, brands. The module
        assembles these with the system blueprints into blueprints_dir. Each
        blueprint needs
          metadata.labels."blueprints.goauthentik.io/instantiate" = "true"
        to auto-apply. Schema: https://goauthentik.io/blueprints/schema.json
      '';
    };

    # ── Provider client secrets (the outpost-token pattern for OAuth2) ───────
    providerSecrets = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        OAuth2 provider client secrets to enforce, keyed by provider NAME —
        each value is an age-encrypted file holding the raw client secret.
        A boot-time oneshot (authentik-provider-secret-setup) waits for the
        provider to exist (declare it via cfg.authentik.blueprints, or make
        it in the UI) and overwrites its client_secret with the file's value
        — the outpost-token pattern: the age file is the single source of
        truth for authentik AND the consumer app, so no UI copy step exists.
        Consumer units should order after
        authentik-provider-secret-setup.service. Requires agenix.
      '';
    };

    # ── Fleet users: declarative authentik users ────────────────────────────
    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          email = mkOption {
            type = types.str;
            description = ''
              Account email. OIDC apps match users by this claim and
              authentik's login asks for it — pick a value worth typing.
            '';
          };
          givenName = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Display name; defaults to the username.";
          };
          type = mkOption {
            type = types.enum [ "internal" "external" "service" ];
            default = "internal";
            description = ''
              internal = interactive human account; service = machine account
              (no password expected, authenticate via API tokens instead).
            '';
          };
          passwordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Age-encrypted file holding the raw password. A boot-time oneshot
              (authentik-user-password-setup) poll-waits for the user (the
              users blueprint applies via the worker asynchronously) and
              hashes+sets the password ONLY when it differs — rotating the
              age file + rebuild changes the password; untouched, nothing
              rehashes and no sessions drop. authentik hashes passwords
              server-side; the declared file remains the single source of
              truth.
            '';
          };
        };
      });
      default = { };
      description = ''
        Declarative users, keyed by username. The module generates a users
        blueprint (applied on worker boot) and a password-sync oneshot per
        user with a passwordFile. akadmin (seeded by cfg.bootstrap) remains
        the break-glass admin, not a daily driver. Consumer modules may add
        their own entries — attrsOf merges across modules.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the firewall for the LDAP outpost (3389) when it is enabled and
        LAN-bound. The authentik server (9000/9443) binds loopback and is
        fronted by service-localweb on port 80 (opened there), so no extra
        firewall hole is needed for the admin UI. Disable if you tunnel
        everything.
      '';
    };
  };
}