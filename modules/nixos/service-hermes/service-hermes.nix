# Hermes Agent — NixOS service module (litellm-style config surface).
#
# `cfg.hermes.*` is the primary config surface; this module translates it into
# the upstream `services.hermes-agent.*` options (defined by
# `hermes-agent.nixosModules.default`, which the host imports alongside — see
# the pattern in service-ssh/service-ntfy for setting options on another
# module's surface). The upstream module supplies the uv2nix package, systemd
# unit, config.yaml generation, managed-mode guards, and container lifecycle.
#
# Host wiring (private repo):
#
#   # flake.nix
#   inputs.hermes-agent.url = "github:NousResearch/hermes-agent";
#   inputs.hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
#   specialArgs.hermes-agent = inputs.hermes-agent;
#
#   # host modules.nix
#   { hermes-agent, nix-config, ... }: {
#     imports = [
#       hermes-agent.nixosModules.default       # defines services.hermes-agent.*
#       nix-config.nixosModules.service-hermes  # this module
#     ];
#     cfg.hermes.enable = true;
#     cfg.hermes.model.default = "anthropic/claude-sonnet-4";
#     cfg.hermes.secrets.OPENROUTER_API_KEY = ./secrets/openrouter.age;
#   }
#
# Out of the box this defaults to the "option 1" homelab-gateway persona (docker
# terminal backend, addToSystemPackages, persistent memory, restart=always) but
# everything is overridable. The docker *terminal* backend needs the Docker
# daemon — enable it via the existing service-docker module (not managed here).
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  cfg = config.cfg.hermes;

  # agenix is optional — the module still works without it (use environmentFiles).
  hasAgenix = builtins.hasAttr "age" options;
  secretName = name: "hermes_${toLower name}";
  hasSecrets = cfg.secrets != { };

  # Runtime env file assembled from age-decrypted secrets. Lives in its own
  # RuntimeDirectory (hermes-secrets, owned by the oneshot) because systemd
  # loads EnvironmentFile before the hermes service's ExecStart — the file must
  # exist at start time. The official hermes module merges its `environmentFiles`
  # into .env at *activation* (rebuild time), which cannot see a runtime file,
  # so agenix secrets go via systemd EnvironmentFile (process env) instead — the
  # same mechanism the community module used.
  secretsRuntimeDir = "/run/hermes-secrets";
  secretsEnvFile = "${secretsRuntimeDir}/secrets.env";
  jsonSecretsDir = "${secretsRuntimeDir}/json";

  secretEntries =
    if hasAgenix then
      mapAttrsToList (name: _: {
        inherit name;
        path = config.age.secrets.${secretName name}.path;
      }) cfg.secrets
    else
      [ ];

  # Reads each decrypted age secret and writes a systemd EnvironmentFile. JSON
  # content is copied to a file and the env var set to the path (avoids
  # EnvironmentFile backslash-escape corrupting multi-line JSON); plain values
  # are written as KEY=<value>. Runs as root (the oneshot has no User=) so it can
  # read /run/agenix/* (root-owned) and write to its own RuntimeDirectory. The
  # hermes process never reads the file directly — systemd (PID 1) loads it and
  # injects the vars into the process environment.
  secretsEnvScript = pkgs.writeShellScript "hermes-secrets-env" ''
    set -eu
    : > ${secretsEnvFile}
    mkdir -p ${jsonSecretsDir}
    ${concatStringsSep "\n" (map (entry: ''
      if ${pkgs.jq}/bin/jq -e . ${entry.path} >/dev/null 2>&1; then
        cp ${entry.path} ${jsonSecretsDir}/${entry.name}.json
        chmod 600 ${jsonSecretsDir}/${entry.name}.json
        printf '${entry.name}=${jsonSecretsDir}/${entry.name}.json\n' >> ${secretsEnvFile}
      else
        printf '${entry.name}=' >> ${secretsEnvFile}
        cat ${entry.path} >> ${secretsEnvFile}
        printf '\n' >> ${secretsEnvFile}
      fi
    '') secretEntries)}
    chmod 600 ${secretsEnvFile}
  '';

  # Shorthand settings: only emit non-null model fields so empty shorthands
  # contribute nothing via the upstream's recursiveUpdate deep-merge.
  modelSettings = filterAttrs (_: v: v != null) cfg.model;
  shorthandSettings = {
    model = modelSettings;
    terminal = cfg.terminal;
    memory = cfg.memory;
  };

  # Hermes' package, resolved from the upstream module (avoids needing the
  # flake input directly here). Used by the separate dashboard service.
  hermesPackage = config.services.hermes-agent.package;

  # State paths reused across the gateway, dashboard, and log relay.
  hermesHome = "${cfg.stateDir}/.hermes";
  errorsLog = "${hermesHome}/logs/errors.log";
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable (mkMerge [
    {
      services.hermes-agent = {
        enable = true;
        addToSystemPackages = cfg.addToSystemPackages;
        restart = cfg.restart;
        restartSec = cfg.restartSec;
        extraArgs = cfg.extraArgs;
        extraPackages = cfg.extraPackages;
        stateDir = cfg.stateDir;
        environment = cfg.environment;
        environmentFiles = cfg.environmentFiles;
        documents = cfg.documents;
        hermesHomeFiles = cfg.hermesHomeFiles;
        extraDependencyGroups = optional cfg.messaging "messaging" ++ cfg.extraDependencyGroups;
        container = cfg.container;
        settings = mkMerge [ shorthandSettings cfg.settings ];
      };
    }

    # workingDirectory is nullOr upstream-side; only set it when configured.
    (mkIf (cfg.workingDirectory != null) {
      services.hermes-agent.workingDirectory = cfg.workingDirectory;
    })

    # user/group are NixOS-only upstream options; only set when overridden.
    (optionalAttrs (cfg.user != "hermes" || cfg.group != "hermes") {
      services.hermes-agent.user = cfg.user;
      services.hermes-agent.group = cfg.group;
    })

    # ── native-mode host users → hermes group ───────────────────────────────
    # The state dir is 0750/2770 hermes:hermes; container.hostUsers only adds
    # users to the group in container mode. This is the native-mode equivalent
    # so listed users can run `hermes` interactively and read/write shared state.
    (mkIf (cfg.hostUsers != [ ]) {
      users.users = listToAttrs (
        map (u: nameValuePair u { extraGroups = [ "hermes" ]; }) cfg.hostUsers
      );
    })

    # ── agenix secret declaration ───────────────────────────────────────────
    (mkIf (hasSecrets && hasAgenix) {
      age.secrets = mapAttrs' (name: agePath: {
        name = secretName name;
        value = {
          file = agePath;
        };
      }) cfg.secrets;
    })

    # ── secrets oneshot + EnvironmentFile wiring ────────────────────────────
    (mkIf (hasSecrets && hasAgenix) {
      systemd.services.hermes-secrets = {
        description = "Generate Hermes secrets environment file";
        before = [ "hermes-agent.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "hermes-secrets";
          RuntimeDirectoryMode = "0755";
          ExecStart = "${secretsEnvScript}";
        };
      };
      systemd.services.hermes-agent = {
        requires = [ "hermes-secrets.service" ];
        after = [ "hermes-secrets.service" ];
        serviceConfig.EnvironmentFile = [ secretsEnvFile ];
      };
    })

    # ── restart on config change ────────────────────────────────────────────
    # The upstream merges config.yaml at activation (rebuild), but that does not
    # restart the running gateway — without this, a settings change leaves it on
    # stale config until you manually `systemctl restart`.
    {
      systemd.services.hermes-agent.restartTriggers = [
        (pkgs.writeText "hermes-agent-settings" (builtins.toJSON config.services.hermes-agent.settings))
        (pkgs.writeText "hermes-agent-hermesHomeFiles" (builtins.toJSON cfg.hermesHomeFiles))
        (pkgs.writeText "hermes-agent-documents" (builtins.toJSON cfg.documents))
      ];
    }

    # ── log relay: mirror errors.log into the journal ───────────────────────
    # Hermes logs ONLY to files (RotatingFileHandler under HERMES_HOME/logs) and
    # writes nothing to stdout, so `journalctl -u hermes-agent` returns zero
    # records. This tails errors.log into the journal as `hermes-errors` so
    # journal-based tooling/alerting can see it. `tail -F` (follow-by-name with
    # retry) survives the RotatingFileHandler's rename-and-recreate and a
    # not-yet-created file on first boot; `-n 0` starts at the tail so the
    # on-disk backlog isn't replayed into the journal on every restart.
    {
      systemd.services.hermes-agent-log-relay = {
        description = "Mirror Hermes file logs (errors.log) into the journal";
        after = [ "hermes-agent.service" ];
        wants = [ "hermes-agent.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          Type = "simple";
          ExecStart = "${pkgs.coreutils}/bin/tail -F -n 0 ${errorsLog}";
          SyslogIdentifier = "hermes-errors";
          StandardOutput = "journal";
          StandardError = "journal";
          Restart = "always";
          RestartSec = 5;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ ];
        };
      };
    }

    # ── web dashboard as a separate service ──────────────────────────────────
    # The upstream `backend.mode` is one-process (gateway XOR dashboard), so the
    # dashboard needs its own unit to coexist with the gateway. Runs as the
    # hermes user, shares HERMES_HOME and the secrets env with the gateway.
    (mkIf cfg.dashboard.enable {
      systemd.services.hermes-dashboard = {
        description = "Hermes Agent web dashboard";
        after = [ "hermes-agent.service" ];
        wants = [ "hermes-agent.service" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          HOME = cfg.stateDir;
          HERMES_HOME = hermesHome;
        };
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          Type = "simple";
          ExecStart =
            "${hermesPackage}/bin/hermes dashboard --host ${cfg.dashboard.host} --port ${toString cfg.dashboard.port} --no-open";
          Restart = "always";
          RestartSec = 5;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.stateDir ];
        };
      };
    })

    # Dashboard needs the same secrets env as the gateway.
    (mkIf (cfg.dashboard.enable && hasSecrets && hasAgenix) {
      systemd.services.hermes-dashboard.serviceConfig.EnvironmentFile = [ secretsEnvFile ];
    })

    # ── local nginx reverse proxy to the dashboard (recommended) ──────────────
    (mkIf (cfg.dashboard.enable && cfg.dashboard.nginx.enable && cfg.dashboard.nginx.domain != null) {
      services.nginx.virtualHosts.${cfg.dashboard.nginx.domain}.locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.dashboard.port}";
        recommendedProxySettings = true;
      };
    })

    # ── public cloudflared ingress to the dashboard (optional) ───────────────
    (mkIf (config.services.cloudflared.enable && cfg.domain != null && cfg.dashboard.enable) {
      services.cloudflared.tunnels."${config.networking.hostName}".ingress."${cfg.domain}" =
        "http://127.0.0.1:${toString cfg.dashboard.port}";
    })

    # ── assertions ──────────────────────────────────────────────────────────
    {
      assertions = [
        {
          assertion = cfg.domain == null || cfg.dashboard.enable;
          message = "cfg.hermes.domain requires cfg.hermes.dashboard.enable (cloudflared targets the dashboard service).";
        }
        {
          assertion = cfg.domain == null || (cfg.settings ? dashboard && cfg.settings.dashboard ? oauth);
          message = ''
            cfg.hermes.domain is set but dashboard auth is not configured. The
            web dashboard is OAuth-gated upstream (Nous Portal or self-hosted
            OIDC). Set cfg.hermes.settings.dashboard.oauth before exposing
            publicly, e.g.:
              cfg.hermes.settings.dashboard.oauth = {
                provider = "self-hosted";
                self_hosted = { issuer = "..."; client_id = "hermes-dashboard"; };
              };
          '';
        }
        {
          assertion = !(cfg.dashboard.nginx.enable && cfg.dashboard.nginx.domain == null);
          message = "cfg.hermes.dashboard.nginx.enable requires cfg.hermes.dashboard.nginx.domain to be set.";
        }
        {
          assertion = cfg.documents == { } || cfg.workingDirectory != null;
          message = ''
            cfg.hermes.documents is non-empty but cfg.hermes.workingDirectory is
            null. Workspace files require an explicit working directory (per
            upstream PR #84178) — set cfg.hermes.workingDirectory.
          '';
        }
      ];
    }
  ]);
}