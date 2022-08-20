#!/usr/bin/env sh
version=`nixos-version | cut -d"." -f 1,2`

sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-${version}.tar.gz home-manager
sudo nix-channel --update