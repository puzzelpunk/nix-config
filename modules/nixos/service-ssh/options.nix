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
  options.cfg = {
    networking = {
      ssh = {
        port = mkOption {
          type = types.int;
          default = 22;
          description = "SSH Port";
        };
      };
    };
  };
}
