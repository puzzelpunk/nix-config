{
  config,
  lib,
  pkgs,
  ...
}:
with pkgs.stdenv;
with lib;
{
  options.cfg.os = {
    name = mkOption {
      type = types.str;
      default = "nixos";
      description = "Operating System Name";
    };

    version = mkOption {
      type = types.str;
      default = "latest";
      description = "Operating System Version";
    };

    hostname = mkOption {
      type = types.str;
      default = config.cfg.os.name;
      description = "System Hostname";
    };
  };

  options.cfg.localization = {
    lang = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      description = "System Language";
    };

    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "System Default Timezone";
    };

    keymap = mkOption {
      type = types.str;
      default = "us";
      description = "Console Keymap";
    };

    longitude = mkOption {
      type = types.flt;
      default = 0.0;
      description = "Location Long";
    };

    latitude = mkOption {
      type = types.flt;
      default = 0.0;
      description = "Location Lat";
    };

    measurement = mkOption {
      type = types.str;
      default = "Metric";
      description = "Measurement Units";
    };

    temperature = mkOption {
      type = types.str;
      default = "Celsius";
      description = "Temperature Units";
    };
  };

  options.cfg.user = {
    name = mkOption {
      type = types.str;
      default = "user";
      description = "Username for the main user on the system";
    };

    fullname = mkOption {
      type = types.str;
      default = "User";
      description = "Username for the main user on the system";
    };

    email = mkOption {
      type = types.str;
      default = "user@example.com";
      description = "Email for the main user on the system";
    };
  };
  options.cfg.shareduser = {
    name = mkOption {
      type = types.str;
      default = "shared";
      description = "Username for the shared files user on the system";
    };
    group = mkOption {
      type = types.str;
      default = "shared";
      description = "Group for the shared files user on the system";
    };
  };
}
