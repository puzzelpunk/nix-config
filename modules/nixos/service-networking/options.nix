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
  options.cfg.networking = {
    domain_name_servers = {
      primary = mkOption {
        type = types.str;
        default = "1.1.1.1";
        description = "Primary DNS Server";
      };

      secondary = mkOption {
        type = types.str;
        default = "9.9.9.9";
        description = "Secondary DNS Server";
      };
    };

    static = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Static Networking";
      };

      managed = mkOption {
        type = types.bool;
        default = false;
        description = "Allow NetworkManager to manage static networking through profiles.";
      };

      default_gateway = mkOption {
        type = types.str;
        default = "192.168.0.1";
        description = "Static Networking Default Gateway";
      };

      prefix_length = mkOption {
        type = types.int;
        default = 24;
        description = "Static Networking Subnet Mask";
      };

      interfaces = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Interface name (e.g. \"eth0\").";
              };
              address = lib.mkOption {
                type = lib.types.str;
                description = "IPv4 address for this interface.";
              };
            };
          }
        );
        default = [ ];
        description = ''
          List of static network interfaces, each with its own interface name and IPv4 address.
        '';
      };
    };
  };
}
