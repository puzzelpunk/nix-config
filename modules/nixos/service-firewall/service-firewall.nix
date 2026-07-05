{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = {
    networking.firewall.package = pkgs.iptables;
    networking.firewall.enable = true;

    # TODO: Configure fail2ban and sshguard
    # services.fail2ban.enable = true;
    # services.sshguard.enable = true;
  };
}
