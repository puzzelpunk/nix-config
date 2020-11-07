#!/usr/bin/env bash

if [[ -n "$1" ]];
then
  _conf_path="$HOME/_unixconf_nix/systems/$1/configuration.nix"

  if [[ -e "$_conf_path" ]];
  then
    echo "Building configuration in $_conf_path"

    if [[ `uname` == "Darwin" ]];
    then
      sudo ln -sf $_conf_path $HOME/.nixpkgs/darwin-configuration.nix
      darwin-rebuild switch
    fi

    # TODO: Need to differentiate between other linux and nixos
    if [[ `uname` == "Linux" ]];
    then
      sudo ln -sf $_conf_path /etc/nixos/configuration.nix
      nixos-rebuild switch
    fi
  else
    echo "'configuration.nix' does not exists in $_conf_path"
  fi
else
  echo "System name argument missing. Please use the name of a sub-directory under the 'systems' folder."
fi
