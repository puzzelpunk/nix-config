export XDG_CONFIG_HOME="$HOME/.config"

if [ -e /Users/$USER/.nix-profile/etc/profile.d/nix.sh ]; 
  then . /Users/$USER/.nix-profile/etc/profile.d/nix.sh; 
fi
