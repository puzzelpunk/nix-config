{ config, lib, pkgs, ... }: {
  services.prometheus = {
    enable = true;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd"];
      };
    };
  };

  services.grafana = {
    enable = true;
    port = 4000;
    addr = "0.0.0.0";
    domain = "grafana.${config.cfg.domain}";
  };
}