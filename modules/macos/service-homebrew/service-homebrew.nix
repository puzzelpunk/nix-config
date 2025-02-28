{ config, lib, pkgs, ... }: {
  config.homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.upgrade = true;
  };
}