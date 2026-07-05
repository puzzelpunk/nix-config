{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with pkgs.stdenv;
with lib;
{
  imports = [ ../service-networking/options.nix ];

  options.cfg.docker = {
    storage_root = mkOption {
      type = types.str;
      default = "/var/lib/docker";
      description = "Docker Storage Root";
    };

    networking = {
      dockernet = mkOption {
        type = types.str;
        default = "dockernet";
        description = "Network for container to container networking";
      };

      bip = mkOption {
        type = types.str;
        default = "172.17.0.1/24";
        description = "Docker BIP";
      };

      dns = {
        primary = mkOption {
          type = types.str;
          default = config.cfg.networking.domain_name_servers.primary;
          description = "Docker Primary DNS";
        };

        secondary = mkOption {
          type = types.str;
          default = config.cfg.networking.domain_name_servers.secondary;
          description = "Docker Secondary DNS";
        };
      };

      iptables = mkOption {
        type = types.str;
        default = "true";
        description = "Docker IP Tables Control";
      };
    };
  };
}
