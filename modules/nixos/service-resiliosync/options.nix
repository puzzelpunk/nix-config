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
  options.cfg.resiliosync = {
    user = mkOption {
      type = types.str;
      default = "rslsync";
      description = "The user resilio sync should run as.";
    };
    deviceName = mkOption {
      type = types.str;
      default = "resilio.${config.cfg.os.hostname}.local";
      description = "The domain name for Resilio Sync.";
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
      default = 8888;
      description = ''
        The web UI port for Resilio Sync. Defaults to 8888 (Resilio's
        conventional port) — NOT 9000, which collides with authentik's
        default HTTP listener (AUTHENTIK_LISTEN__HTTP) on hosts running both.
      '';
    };
    httpListenAddr = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Address for the Resilio Sync web UI to listen on.
        Defaults to 127.0.0.1 (localhost only) for security.
        Set to 0.0.0.0 to expose on all interfaces (not recommended
        unless you have other access controls in place).
      '';
    };
  };
}
