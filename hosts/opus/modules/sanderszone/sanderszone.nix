{ config, lib, pkgs, options, ... }:
{
  imports = [
    ./docker.nix
    ./gitea.nix
    ./resiliosync.nix
  ];
}