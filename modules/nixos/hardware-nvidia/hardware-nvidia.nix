{
  config,
  pkgs,
  lib,
  ...
}:
with pkgs.stdenv;
with lib;
{
  config = {
    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia
    ];
    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;

    hardware.nvidia = {
      nvidiaPersistenced = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      open = false;
    };

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia-container-toolkit.enable = true;
  };
}
