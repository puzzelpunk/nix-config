{ config, lib, pkgs, options, ... }:
with pkgs.stdenv;
with lib;
let
  fzshInitExtraConfig = import ./zshInitExtraConfig.nix;
  zshInitExtraConfig = fzshInitExtraConfig { config = config; lib = lib; pkgs = pkgs; };
  fgetZshInitExtra = import ./getZshInitExtra.nix;
  getZshInitExtra = fgetZshInitExtra { lib = lib; pkgs= pkgs; zshInitExtraConfig = zshInitExtraConfig; };
in {
  home-manager.users."${config.cfg.user.name}" = {
    home.stateVersion = config.cfg.os.version;

    programs.git = {
      enable = true;
      userName = config.cfg.user.name;
      userEmail = config.cfg.user.email;
    };

    programs.zsh.enable = true;
    programs.zsh.initExtra = getZshInitExtra;

    # TODO need to make this optional with options
    home.packages = with pkgs; 
      (if config.cfg.os.name == "nixos" then [
        parted # filesystems
        nettools # networking
        openvpn # networking
        killall # processes
        lshw # system info
      ] else if config.cfg.os.name == "macos" then [
      ] else []) ++ [
        coreutils-full # generic

        findutils # search

        bat # shell
        exa # shell
        zoxide # shell
      
        neofetch # system info
        lsof # system info
        htop # system info _ rust alt - ps # https://github.com/dalance/procs
      
        nmap # networking
        speedtest-cli # networking
      
        bzip2 # archives
        gzip # archives
        p7zip # archives
        unrar # archives
        unzip # archives
        zip # archives
      
        curl # file transfer
        rsync # file transfer and sync
        wget # file transfer
        lftp # file transfer
      
        pandoc # multimedia
        ffmpeg-full # multimedia
        imagemagick # multimedia
      ] ++ [
        # cmatrix 
        # cowsay
        figlet
        # lolcat
        # pipes
        toilet
        pywal
        colorz
      ];
  };

}

