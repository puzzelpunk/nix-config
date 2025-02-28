{ config, pkgs, ... }: {
  imports = [ ./modules.nix ];
  cfg.os.version = "23.11";
  nix.maxJobs = 10;
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.useDaemon = true;
  cfg.os.hostname = "forte";
}
