{ config, lib, pkgs, options, ... }: 
let 
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
in {
  config = {
    hardware.graphics.enable = true;
    hardware.opengl.driSupport32Bit = true;
    
    hardware.nvidia = {
      nvidiaPersistenced = false;
      package = nvidiaPackage;
      modesetting.enable = true;
      open = false;
    };

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia-container-toolkit.enable = true;
  };
}
