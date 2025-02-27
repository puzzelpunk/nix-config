{ config, lib, pkgs, options, ... }: 
let
  gitea_public_domain = "gitea.sanders.zone";
  gitea_dir = "/Volumes/Server/sanderszone/gitea";
  gitea_web_port = 3000;
  gitea_ssh_port = 222;
in {
  services.gitea = {
    enable = true;
    stateDir = gitea_dir;
    # dump.enable = true;
    lfs.enable = true;
    database.createDatabase = false;
  };

  services.cloudflared = {
    tunnels."${config.networking.hostName}" = {
      ingress = {
        "${gitea_public_domain}" = "http://${config.cfg.networking.static.ip_address}:${builtins.toString gitea_web_port}";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ gitea_web_port ];
}
