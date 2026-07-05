{
  config,
  lib,
  pkgs,
  tsConfig,
  ...
}:
let
  tsAuthKeyPath = tsConfig.tsAuthKeyPath;
  tsAuthKeyAgePath = tsConfig.tsAuthKeyAgePath;
in
{
  config = {
    age.secrets.ts_auth_key.file = tsAuthKeyAgePath;
    # make the tailscale command usable to users
    environment.systemPackages = [ pkgs.tailscale ];

    # enable the tailscale service
    services.tailscale.enable = true;

    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      after = [
        "network-pre.target"
        "tailscale.service"
      ];
      wants = [
        "network-pre.target"
        "tailscale.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";

      script = with pkgs; ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
            exit 0
        fi

        AUTH_KEY=$(cat "${tsAuthKeyPath}")

        # otherwise authenticate with tailscale
        ${tailscale}/bin/tailscale up -authkey "$AUTH_KEY"
      '';
    };

    networking.firewall = lib.mkIf config.networking.firewall.enable {
      # always allow traffic from your Tailscale network
      trustedInterfaces = [ "tailscale0" ];

      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [ config.services.tailscale.port ];

      # let you SSH in over the public internet
      allowedTCPPorts = [ 22 ];
    };
  };
}
