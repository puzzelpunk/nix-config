{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.cfg.ups;
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    power.ups = {
      enable = true;
      mode = "standalone";

      maxStartDelay = cfg.maxStartDelay;

      ups.${config.cfg.os.hostname} = {
        driver = cfg.driver;
        port = cfg.port;
        description = "Local UPS (${cfg.driver})";
        directives =
          (optional (cfg.vendorid != null) "vendorid = ${cfg.vendorid}")
          ++ (optional (cfg.productid != null) "productid = ${cfg.productid}")
          ++ (optional (cfg.serial != null) "serial = ${cfg.serial}")
          ++ [ "pollfreq = ${toString cfg.pollInterval}" ];
      };

      users.upsmon = {
        passwordFile = "/etc/nut/upsmon.password";
        upsmon = "primary";
      };

      upsmon = {
        monitor.${config.cfg.os.hostname} = {
          system = config.cfg.os.hostname;
          user = "upsmon";
          passwordFile = "/etc/nut/upsmon.password";
          type = "primary";
          powerValue = 1;
        };

        settings = mkIf cfg.shutdownEarly {
          NOTIFYCMD = mkDefault "/etc/nut/shutdown-now";
          NOTIFYFLAG = [
            [ "ONBATT" "SYSLOG+WALL+EXEC" ]
          ];
        };
      };
    };

    # NUT requires a password file even for standalone use
    environment.etc."nut/upsmon.password".text = "upsmon-local";

    # Shutdown script used by NOTIFYCMD when shutdownEarly is enabled.
    # Calls the standard NUT SHUTDOWNCMD to trigger a graceful poweroff.
    environment.etc."nut/shutdown-now" = mkIf cfg.shutdownEarly {
      mode = "0755";
      text = ''
        #!/bin/sh
        ${pkgs.systemd}/bin/shutdown now
      '';
    };


    # Wait for USB devices to be ready before starting the UPS driver
    systemd.services.upsdrvctl = {
      after = [ "network.target" "multi-user.target" ];
      wants = [ "multi-user.target" ];
    };

    # Tell the UPS to power off after the system shuts down.
    # This ensures the UPS turns off and restores power cleanly when AC returns.
    systemd.services.ups-poweroff = mkIf cfg.powerOffUPS {
      description = "Power off UPS after system shutdown";
      wantedBy = [ "shutdown.target" ];
      before = [ "shutdown.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.nut}/bin/upsdrvctl shutdown";
      };
    };
  };
}
