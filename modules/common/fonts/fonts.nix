{ config, lib, pkgs, options, ... }: {
  fonts = {
    fonts = with pkgs; [
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.victor-mono
      corefonts
      inter
      dejavu_fonts
    ];
  };
}
