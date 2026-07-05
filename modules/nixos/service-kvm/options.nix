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
  options.cfg.vfio = {
    passthrough = {
      gpu_video = mkOption {
        type = types.str;
        default = "pci_0000_00_00_0";
        description = "run `virsh nodedev-list --cap pci` to find id";
      };

      gpu_audio = mkOption {
        type = types.str;
        default = "pci_0000_00_00_1";
        description = "run `virsh nodedev-list --cap pci` to find id";
      };
    };
  };
}
