{ config, lib, pkgs, ... }: 
with pkgs.stdenv;
with lib; {
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
      default = "America/Chicago";
      description = "System Default Timezone";
    };

    keymap = mkOption {
      type = types.str;
      default = "us";
      description = "Console Keymap";
    };

    longitude = mkOption {
      type = types.flt;
      default = 32.0;
      description = "Location Long";
    };

    latitude = mkOption {
      type = types.flt;
      default = -96.0;
      description = "Location Lat";
    };

    measurement = mkOption {
      type = types.str;
      default = "Inches";
      description = "Measurement Units";
    };

    temperature = mkOption {
      type = types.str;
      default = "Fahrenheit";
      description = "Temperature Units";
    };
  };

  options.cfg.user = {
    name = mkOption {
      type = types.str;
      default = "cameron";
      description = "Username for the main user on the system";
    };

    fullname = mkOption {
      type = types.str;
      default = "Cameron Sanders";
      description = "Username for the main user on the system";
    };

    email = mkOption {
      type = types.str;
      default = "csanders@protonmail.com";
      description = "Email for the main user on the system";
    };
  };
}
