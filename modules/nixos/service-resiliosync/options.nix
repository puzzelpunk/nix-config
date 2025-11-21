{ config, lib, pkgs, options, ... }:
with pkgs.stdenv;
with lib; {
  options.cfg.resiliosync = {
    resilioPublicDomain = mkOption {
      type = types.str;
      default = "resilio.${config.cfg.os.hostname}.local";
      description = "The public domain name for Resilio Sync.";
    };
    storagePath = mkOption {
      type = types.str;
      default = "/var/lib/resilio-sync";
      description = "The storage path for Resilio Sync.";
    };
    directoryRoot = mkOption {
      type = types.str;
      default = "/home/${config.cfg.user.name}/";
      description = "The directory root for Resilio Sync.";
    };
    webPort = mkOption {
      type = types.int;
      default = 9000;
      description = "The web UI port for Resilio Sync.";
    };
  };
}
