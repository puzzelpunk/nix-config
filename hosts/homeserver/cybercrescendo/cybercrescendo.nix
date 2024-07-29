{ config, lib, pkgs, options, ... }:
{
  imports = [
    ./database.nix
    ./nextcloud.nix
    ./proxy.nix
  ];
}