{ config, pkgs, ... }: {
  imports = [ ./modules.nix ];
  cfg.os.version = "23.11";
  cfg.os.hostname = "silicontundra";
  nix.settings.max-jobs = 16;
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.useDaemon = true;

}
