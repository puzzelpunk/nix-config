{ config, lib, pkgs, options, ... }:
{
  virtualisation.oci-containers.containers.gpt4free = {
    image = "hlohaus789/g4f:latest";
    ports = [
      "8080:8080"
      "1337:1337"
      "7900:7900"
    ];
    extraOptions = [
      "--shm-size=2g"
    ];
  };
}

