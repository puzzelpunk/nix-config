{
  config,
  lib,
  pkgs,
  dockernetConfig,
  ...
}:

let
  networkName = dockernetConfig.networkName;
in
{
  systemd.services.dockernet-create = {
    description = "Create the network bridge dockernet container to container networking.";
    after = [
      "network.target"
      "docker.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";
    script =
      let
        dockercli = "${config.virtualisation.docker.package}/bin/docker";
      in
      ''
        # Put a true at the end to prevent getting non-zero return code, which will
        # crash the whole service.

        check=$(${dockercli} network ls | grep "${networkName}" || true)

        if [ -z "$check" ]; then
          ${dockercli} network create ${networkName}
        else
          echo "${networkName} already exists in docker"
        fi
      '';
  };
}
