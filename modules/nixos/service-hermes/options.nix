{
  lib,
  ...
}:
with lib;
let
  terminalBackend = types.enum [
    "local"
    "docker"
    "ssh"
    "singularity"
    "modal"
    "daytona"
  ];
in
{
  options.cfg.hermes = {
    enable = mkEnableOption "Hermes Agent";

    # ── Freeform config (full cli-config.yaml surface) ──────────────────────
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Freeform Hermes CLI config, rendered to config.yaml and deep-merged with
        the typed shorthands below. This is the full escape hatch — any key from
        cli-config.yaml.example can be set here and never lags upstream. Typed
        shorthands (model/terminal/memory) are merged underneath, so keys here
        win on leaf conflicts. Never put secrets here (Nix store is
        world-readable) — use cfg.hermes.secrets.
      '';
    };

    # ── Typed shorthands ────────────────────────────────────────────────────
    model = mkOption {
      type = types.submodule {
        freeformType = types.attrs;
        options = {
          default = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default model id (provider-prefixed for OpenRouter, e.g. \"anthropic/claude-sonnet-4\").";
          };
          provider = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Inference provider (auto/openrouter/anthropic/nous/...).";
          };
          base_url = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Provider API base URL.";
          };
        };
      };
      default = { };
      description = "Model shorthand → settings.model. Null fields are omitted.";
    };

    terminal = mkOption {
      type = types.submodule {
        freeformType = types.attrs;
        options = {
          backend = mkOption {
            type = terminalBackend;
            default = "docker";
            description = ''
              Terminal tool backend. "docker" (default) runs shell commands in a
              persistent FHS container (the "option 1" architecture); "local"
              runs on the host. Freeform keys (docker_image, ssh_host, cwd,
              timeout, container_persistent, ...) pass through to settings.terminal.
            '';
          };
        };
      };
      default = { };
      description = "Terminal tool config → settings.terminal.";
    };

    memory = mkOption {
      type = types.submodule {
        freeformType = types.attrs;
        options = {
          memory_enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Agent personal notes (MEMORY.md).";
          };
          user_profile_enabled = mkOption {
            type = types.bool;
            default = true;
            description = "User profile (USER.md).";
          };
        };
      };
      default = { };
      description = "Persistent memory config → settings.memory.";
    };

    documents = mkOption {
      type = types.attrsOf (types.either types.str types.path);
      default = { };
      description = ''
        Workspace files (e.g. AGENTS.md), installed into workingDirectory.
        Requires cfg.hermes.workingDirectory to be set when non-empty.
      '';
    };

    hermesHomeFiles = mkOption {
      type = types.attrsOf (types.either types.str types.path);
      default = { };
      description = ''
        Files installed into HERMES_HOME (e.g. SOUL.md, memories/USER.md).
        Distinct from documents (workspace) per PR #84178 — a SOUL.md in
        documents is NOT loaded as the agent identity.
      '';
    };

    messaging = mkOption {
      type = types.bool;
      default = false;
      description = "Enable messaging adapters (Discord/Telegram/Slack) via extraDependencyGroups = [\"messaging\"].";
    };

    extraDependencyGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Extra pyproject.toml optional extras (e.g. [\"hindsight\" \"voice\"]).
        Concatenated with the messaging group when cfg.hermes.messaging is true.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Non-secret env vars (written to the Nix store — do NOT put secrets here).";
    };

    environmentFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Static env-file paths merged into HERMES_HOME/.env at activation
        (upstream mechanism). For age-encrypted secrets, use cfg.hermes.secrets
        instead — those are assembled at runtime and injected via systemd
        EnvironmentFile, not activation-merge.
      '';
    };

    # ── NixOS-only: full container mode ─────────────────────────────────────
    container = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Run the entire gateway inside an OCI container with a writable
              apt/pip layer. Separate axis from the docker terminal backend
              (which only sandboxes the terminal tool, not the gateway process).
            '';
          };
          backend = mkOption {
            type = types.enum [ "docker" "podman" ];
            default = "docker";
          };
          image = mkOption {
            type = types.str;
            default = "ubuntu:24.04";
          };
          extraVolumes = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          extraOptions = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          hostUsers = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Host users who get a ~/.hermes symlink to the service stateDir (container mode).";
          };
        };
      };
      default = { };
      description = "Full container mode (gateway isolation). Off by default.";
    };

    # ── NixOS-only: agenix secrets ──────────────────────────────────────────
    secrets = mkOption {
      type = types.attrsOf types.path;
      default = { };
      example = literalExpression ''
        {
          OPENROUTER_API_KEY = ./secrets/openrouter.age;
          ANTHROPIC_API_KEY = ./secrets/anthropic.age;
        }
      '';
      description = ''
        Age-encrypted secrets injected as environment variables at runtime via
        agenix. Each attribute maps an env var name to an age-encrypted file.
        Values are decrypted to /run/agenix and assembled into a systemd
        EnvironmentFile — never written to the Nix store. Requires agenix on
        the host. JSON content (e.g. service-account keys) is written to a file
        and the env var set to the path, avoiding EnvironmentFile escape issues.
      '';
    };

    # ── NixOS-only: service knobs ───────────────────────────────────────────
    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/hermes";
      description = ''
        State directory (HERMES_HOME parent). Place this on a path covered by
        your backup config (e.g. /Volumes/Server/...) so agent memory/sessions
        survive a reimage.
      '';
    };
    workingDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Agent working directory. Defaults to \${stateDir}/workspace upstream.";
    };
    user = mkOption {
      type = types.str;
      default = "hermes";
    };
    group = mkOption {
      type = types.str;
      default = "hermes";
    };
    addToSystemPackages = mkOption {
      type = types.bool;
      default = true;
      description = "Put hermes CLI on system PATH and set HERMES_HOME system-wide (SSH CLI shares state with the gateway).";
    };
    hostUsers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Host users added to the `hermes` group so they can read/write the shared
        state directory (0750/2770 hermes:hermes) when running `hermes`
        interactively. `container.hostUsers` only does this in container mode;
        this option is the native-mode equivalent. A main admin user that
        operates via sudo need not be listed.
      '';
    };
    restart = mkOption {
      type = types.str;
      default = "always";
    };
    restartSec = mkOption {
      type = types.int;
      default = 5;
    };
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra args for `hermes gateway`.";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages on the agent's PATH.";
    };

    # ── NixOS-only: web dashboard (separate service) ───────────────────────
    dashboard = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "the Hermes web dashboard as a separate service";

          host = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = ''
              Address the dashboard binds. Use 0.0.0.0 to expose on the LAN
              (then gate it via nginx/VPN). Defaults to loopback so an explicit
              ingress choice is required to reach it.
            '';
          };

          port = mkOption {
            type = types.port;
            default = 8765;
            description = "Port the dashboard listens on (the `hermes dashboard --port` value).";
          };

          nginx = {
            enable = mkEnableOption "a local nginx reverse proxy to the dashboard";

            domain = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Local domain for the nginx virtualHost proxying to the dashboard
                (e.g. hermes.ultracore.local). Recommended for LAN/VPN access.
                Requires nginx enabled on the host (services.nginx).
              '';
            };
          };
        };
      };
      default = { };
      description = ''
        Web dashboard, run as a separate `hermes-dashboard` service alongside
        the gateway (the upstream `backend.mode` is one-process, so the dashboard
        must be its own unit to coexist with the gateway). Ingress is opt-in:
        nginx (local, recommended) via dashboard.nginx, or cloudflared (public)
        via cfg.hermes.domain.
      '';
    };

    domain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Public domain for the web dashboard via cloudflared (e.g.
        hermes.example.com). When set, adds a cloudflared ingress entry → the
        dashboard port — requires service-cloudflared on the host, the dashboard
        enabled (cfg.hermes.dashboard.enable), AND dashboard auth configured
        (cfg.hermes.settings.dashboard.oauth). The dashboard is OAuth-gated
        upstream (Nous Portal or self-hosted OIDC); the assertion prevents
        exposing an unauthenticated public endpoint. Leave null and use
        cfg.hermes.dashboard.nginx for local/VPN access instead.
      '';
    };
  };
}