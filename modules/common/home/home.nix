{ config, lib, pkgs, options, ... }:
with pkgs.stdenv;
with lib;
let
  zshInitExtraConfig = import ./zshInitExtraConfig.nix;
  getZshInitExtra = import ./getZshInitExtra.nix;
in {
  
  # TODO need to scope this to the home environment
  environment.systemPackages = with pkgs; [
    zoxide
    neovim
  ];

  home-manager.users."${config.cfg.user.name}" = {
    home.stateVersion = config.cfg.os.version;

    programs.git = {
      enable = true;
      userName = config.cfg.user.name;
      userEmail = config.cfg.user.email;
    };

    programs.zsh.enable = true;
    programs.zsh.initExtra = getZshInitExtra initExtraConfig;
  };

  # TODO need to make this optional with options
  home-manager.users."${config.cfg.user.name}".home.packages = with pkgs; [
    cmatrix 
    cowsay
    figlet
    lolcat
    pipes
    toilet
    pywal
    colorz
  ];

  # TODO need to make this optional with options
  home-manager.users."${config.cfg.user.name}".home.packages = with pkgs; 
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
      ripgrep # search _ rust alt - find + grep # https://github.com/BurntSushi/ripgrep

      bat # shell _ rust alt - cat & less # https://github.com/sharkdp/bat
      exa # shell _ rust alt - ls # https://github.com/ogham/exa
      zoxide # shell _ rust alt - cd # https://github.com/ajeetdsouza/zoxide
    
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
      youtube-dl # file transfer and downloader downloader
      lftp # file transfer
    
      pandoc # multimedia
      ffmpeg-full # multimedia
      imagemagick # multimedia
    ];
}

