{ config, lib, pkgs, options, ... }: {
  config = {
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportRoot = false;
    networking.hostId = "619456fe";
  };
}
