# Hermes Agent — Home Manager service module (litellm-style config surface).
#
# `cfg.hermes.*` is the primary config surface for a per-user coding assistant,
# translated into the upstream `services.hermes-agent.*` Home Manager options
# (PR #84178). Runs as *you*, state in ~/.hermes, a systemd user service on
# Linux or a launchd agent on macOS. The same option set as the NixOS module,
# so config transfers between them.
#
# The host must import the upstream Home Manager module alongside:
#
#   # private flake.nix
#   inputs.hermes-agent.url = "github:NousResearch/hermes-agent";
#   inputs.hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
#
#   # home.nix (pass hermes-agent via extraSpecialArgs)
#   { hermes-agent, nix-config, ... }: {
#     imports = [
#       hermes-agent.homeManagerModules.default     # defines services.hermes-agent.*
#       nix-config.commonModules.hermes             # this module
#     ];
#     cfg.hermes.enable = true;
#     cfg.hermes.model.default = "anthropic/claude-sonnet-4";
#   }
#
# Secrets: agenix wiring differs on Home Manager (user services, no root
# oneshot), so this module does not implement age-secret assembly. Provide
# decrypted env files via cfg.hermes.environmentFiles (however the host manages
# them — e.g. the agenix home-manager module, or a manually-decrypted file).
#
# Linger (Linux): a systemd user service stops at logout unless the user
# manager lingers — enable `users.users.<name>.linger = true` on the NixOS host
# (or `loginctl enable-linger <name>`). On macOS the launchd agent is unaffected.
#
# Darwin caveat: the upstream module was *evaluated* for aarch64-darwin but not
# runtime-tested on a Mac as of the merge — confirm the launchd agent starts
# before relying on it on macOS.
{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.cfg.hermes;
  terminalBackend = types.enum [
    "local"
    "docker"
    "ssh"
    "singularity"
    "modal"
    "daytona"
  ];
  modelSettings = filterAttrs (_: v: v != null) cfg.model;
  shorthandSettings = {
    model = modelSettings;
    terminal = cfg.terminal;
    memory = cfg.memory;
  };
in
{
  # ── Shared options (kept identical to service-hermes/options.nix so both ──
  # ── modules can coexist in one eval if a host imports both) ────────────────
  options.cfg.hermes = {
    enable = mkEnableOption "Hermes Agent";

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Freeform Hermes CLI config, rendered to config.yaml and deep-merged with
        the typed shorthands below. This is the full escape hatch — any key from
        cli-config.yaml.example can be set here and never lags upstream. Typed
        shorthands (model/terminal/memory) are merged underneath, so keys here
        win on leaf conflicts. Never put secrets here (Nix store is
        world-readable) — use cfg.hermes.environmentFiles with a decrypted file.
      '';
    };

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
            default = "local";
            description = ''
              Terminal tool backend. "local" (default) runs on the host — a
              workstation has a real FHS userspace. "docker" sandboxes shell
              commands in a container. Freeform keys (docker_image, ssh_host,
              cwd, timeout, ...) pass through to settings.terminal.
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
        Env-file paths merged into HERMES_HOME/.env at activation. Provide
        decrypted secret files here (however the host manages them — e.g. the
        agenix home-manager module). Unlike the NixOS module, no runtime
        age-secret assembly is performed.
      '';
    };

    # ── Home-Manager-only options ───────────────────────────────────────────
    gateway = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Run the hermes gateway as a user service (messaging platforms). Off by
        default — a workstation is usually an interactive coding surface, and
        the homelab owns the always-on gateway. Remember linger on Linux.
      '';
    };

    hermesHome = mkOption {
      type = types.str;
      default = "~/.hermes";
      description = "HERMES_HOME state directory. Default preserves an existing ~/.hermes.";
    };

    workingDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Agent working directory. Required when documents is non-empty.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra args for the hermes service.";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages on the agent's PATH.";
    };
    restart = mkOption {
      type = types.str;
      default = "on-failure";
    };
    restartSec = mkOption {
      type = types.int;
      default = 5;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.hermes-agent = {
        enable = true;
        gateway.enable = cfg.gateway;
        hermesHome = cfg.hermesHome;
        environment = cfg.environment;
        environmentFiles = cfg.environmentFiles;
        documents = cfg.documents;
        hermesHomeFiles = cfg.hermesHomeFiles;
        extraDependencyGroups = optional cfg.messaging "messaging" ++ cfg.extraDependencyGroups;
        extraArgs = cfg.extraArgs;
        extraPackages = cfg.extraPackages;
        restart = cfg.restart;
        restartSec = cfg.restartSec;
        settings = mkMerge [ shorthandSettings cfg.settings ];
      };
    }
    (mkIf (cfg.workingDirectory != null) {
      services.hermes-agent.workingDirectory = cfg.workingDirectory;
    })
    {
      assertions = [
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