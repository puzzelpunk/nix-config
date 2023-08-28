with nixpkgs;
with nixpkgs.stdenv; 
with lib; 
{
  ohMyZsh = {
    enable = true;
    plugins = [ "git" ];
  };
  variables = {
    LESS_TERMCAP_mb = "$(tput bold; tput setaf 2)";
    LESS_TERMCAP_md = "$(tput bold; tput setaf 6)";
    LESS_TERMCAP_me = "$(tput sgr0)";
    LESS_TERMCAP_mh = "$(tput dim)";
    LESS_TERMCAP_mr = "$(tput rev)";
    LESS_TERMCAP_se = "$(tput rmso; tput sgr0)";
    LESS_TERMCAP_so = "$(tput bold; tput setaf 3; tput setab 4)";
    LESS_TERMCAP_ue = "$(tput rmul; tput sgr0)";
    LESS_TERMCAP_us = "$(tput smul; tput bold; tput setaf 7)";
    LESS_TERMCAP_ZN = "$(tput ssubm)";
    LESS_TERMCAP_ZO = "$(tput ssupm)";
    LESS_TERMCAP_ZV = "$(tput rsubm)";
    LESS_TERMCAP_ZW = "$(tput rsupm)";
    LESS = "--RAW-CONTROL-CHARS";
    TERMINAL = "${nixpkgs.alacritty}/bin/alacritty";
    EDITOR = "${nixpkgs.neovim}/bin/nvim";
    VISUAL = "${nixpkgs.vscode}/bin/code";
    TERM = "xterm-256color";
  };
  aliases = {
    cat = ''${nixpkgs.bat}/bin/bat'';
    cd = ''z'';
    clearhistory = ''cat /dev/null > $HOME/.zsh_history ; exit'';
    less = ''${nixpkgs.bat}/bin/bat'';
    ls = ''${nixpkgs.exa}/bin/exa --icons -h'';
    lsip = ''${nixpkgs.curl}/bin/curl http://ipecho.net/plain; echo'';
    lsnetwork = ''clear ; sudo ${nixpkgs.nmap}/bin/nmap -sS -T aggressive 192.168.0.0/24 | less'';
    lsports = ''clear ; ${nixpkgs.nmap}/bin/nmap -sS -T aggressive localhost'';
    vi = ''${nixpkgs.neovim}/bin/nvim'';
    vim = ''${nixpkgs.neovim}/bin/nvim'';
  };
  setOpts = [
    "AUTOCD"
    "AUTOPUSHD"
    "COMPLETE_ALIASES"
    "CORRECT"
    "EXTENDED_HISTORY"
    "EXTENDEDGLOB"
    "HIST_EXPIRE_DUPS_FIRST"
    "HIST_FCNTL_LOCK"
    "HIST_IGNORE_DUPS"
    "HIST_IGNORE_SPACE"
    "NOBEEP"
    "NOCASEGLOB"
    "NOCHECKJOBS"
    "NUMERICGLOBSORT"
    "PROMPT_SUBST"
    "RCEXPANDPARAM"
    "SHARE_HISTORY"
  ];
  completions = {
    accept-exact = "'*(N)'";
    cache-path = "~/.zsh/cache";
    list-colors = ''"\$\{(s.:.)LS_COLORS\}"'';
    matcher-list = "'m:{a-zA-Z}={A-Za-z}'";
    rehash = "true";
    use-cache = "on";
  };
  keybindings = {
    delete-char = "\\e[3~"; # delete
    forward-char = "^[[c"; # right key
    backward-char = "^[[d"; # left key
    forward-word = "^[[1;5C"; # ctrl + right
    backward-word = "^[[1;5D"; # ctrl + left
    backward-kill-word = "^[[1;7D"; # ctrl + alt + left
    kill-word = "^[[1;7C"; # ctrl + alt + right
    history-substring-search-down = "^[[B"; # down arrow history substring search
    history-substring-search-up = "^[[A"; # up arrow history substring search
    beginning-of-line = "^[[H"; # [Home] - Go to beginning of line
    end-of-line = "^[[F"; # [End] - Go to end of line
  };
  paths = [
    # "$HOME/scripts"
    # "$HOME/.cargo/bin"
    # "$HOME/.local/bin"
    # "/usr/local/bin"
    # "/usr/libexec/java_home"
    # "/run/current-system/sw/bin/"
  ];
  fpaths = with nixpkgs; [
    "${zsh-completions}/share/zsh/site-functions"
    "${zsh-fast-syntax-highlighting}/share/zsh/site-functions"
  ];
  sources = with nixpkgs; [
    "${zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    "${zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    "${zsh-you-should-use}/share/zsh/plugins/you-should-use/you-should-use.plugin.zsh"
  ];
  extras = [
    ''(eval "nohup ${nixpkgs.pywal}/bin/wal -Rn" > /dev/null 2>&1 &)''
    ''eval "$(${nixpkgs.starship}/bin/starship init zsh)"''
    ''eval "$(${nixpkgs.zoxide}/bin/zoxide init zsh)"''
  ];
}
