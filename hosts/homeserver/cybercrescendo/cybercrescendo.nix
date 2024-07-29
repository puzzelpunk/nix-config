{ config, lib, pkgs, options, ... }:
{
  imports = [ 
    ./nextcloud.nix
    ./proxy.nix
  ];
}