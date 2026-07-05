{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with pkgs.stdenv;
with lib;
{
  imports = [ ./options.nix ];

  config = {
    users.groups.sshusers = { };
    users.users."${config.cfg.user.name}".extraGroups = [ "sshusers" ];

    services.openssh = {
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
        X11Forwarding = false;
        LogLevel = "VERBOSE";
        KbdInteractiveAuthentication = true;
      };
      allowSFTP = true;
      enable = true;
      openFirewall = true;
      ports = [ config.cfg.ssh.port ];
      startWhenNeeded = true;

      # TODO: consider remove uneeded options here
      # TODO: consider making these values configurable

      extraConfig = ''
        AllowGroups sshusers
        ClientAliveCountMax 2
        ClientAliveInterval 15
        LoginGraceTime 1m
        PermitEmptyPasswords no
        PrintLastLog yes
        PubkeyAuthentication yes
        TCPKeepAlive yes
      '';
    };

    # # PAM 2 FACTOR AUTH
    # # Users with enabled Google Authenticator (created ~/.google_authenticator) will be required to provide Google Authenticator token to log in via sshd.
    # # https://wiki.archlinux.org/index.php/Google_Authenticator
    # security.pam.services.sshd.googleAuthenticator.enable = true;
  };
}
