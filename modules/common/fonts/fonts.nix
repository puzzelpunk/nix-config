{ config, lib, pkgs, options, ... }: {
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.victor-mono
      corefonts
      inter
      dejavu_fonts
    ];
  };
}
