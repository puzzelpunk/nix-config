{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with pkgs.stdenv;
with lib;
let
  staticIfaces = config.cfg.networking.static.interfaces;

  mkNmProfile = iface: {
    name = "static-${iface.name}";
    value = {
      connection = {
        type = "ethernet";
        id = "static-${iface.name}";
        interface-name = iface.name;
        autoconnect = true;
      };

      ipv4 = {
        method = "manual";
        addresses = "${iface.address}/${toString config.cfg.networking.static.prefix_length}";
        gateway = config.cfg.networking.static.default_gateway;
        dns = lib.concatStringsSep ";" [
          config.cfg.networking.domain_name_servers.primary
          config.cfg.networking.domain_name_servers.secondary
        ];
        ignore-auto-dns = true;
        ignore-auto-gateway = true;
      };
    };
  };

  mkNmInterface = iface: {
    name = iface.name;
    value = {
      ipv4.addresses = [
        {
          address = iface.address;
          prefixLength = config.cfg.networking.static.prefix_length;
        }
      ];
    };
  };

  # Turn the list of interfaces into an attribute set of profiles.
  staticProfiles = lib.listToAttrs (map mkNmProfile staticIfaces);

  # Turn the list of interfaces into an attribute set of interfaces.
  staticInterfaces = lib.listToAttrs (map mkNmInterface staticIfaces);
in
{
  imports = [ ./options.nix ];

  config.networking = mkMerge [
    {
      networkmanager = {
        enable = true;
        ethernet.macAddress = "stable";
        wifi.macAddress = "stable";
      };
    }

    (mkIf (config.cfg.networking.static.enable == true && config.cfg.networking.static.managed == false)
      {
        defaultGateway = config.cfg.networking.static.default_gateway;
        dhcpcd.enable = mkForce false;
        interfaces = staticInterfaces;
        nameservers = [
          config.cfg.networking.domain_name_servers.primary
          config.cfg.networking.domain_name_servers.secondary
        ];
        networkmanager.unmanaged = map (i: i.name) config.cfg.networking.static.interfaces;
      }
    )

    (mkIf (config.cfg.networking.static.enable == true && config.cfg.networking.static.managed == true)
      {
        networkmanager.ensureProfiles.profiles = staticProfiles;
      }
    )
  ];
}
