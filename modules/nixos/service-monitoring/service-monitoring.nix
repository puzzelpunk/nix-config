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
    settings.server = {
      http_port = 3000;
      domain = "monitoring.local";
    };
  };
}