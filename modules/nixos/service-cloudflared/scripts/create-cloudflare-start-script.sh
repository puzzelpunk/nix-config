set -euo pipefail

# Parameters substituted by Nix
CLOUDFLARED_HOME_DIR="@homeDir@"
CLOUDFLARED_PACKAGE="@cloudflared_package@"
CLOUDFLARED_USER="@user@"
JQ="@jq@"
TUNNEL_NAME="@tunnelName@"

# Create the tunnel start script
cat > "$CLOUDFLARED_HOME_DIR/${TUNNEL_NAME}_tunnel.sh" << EOF
#!/bin/sh
$CLOUDFLARED_PACKAGE/bin/cloudflared tunnel --config=@config_file@ --no-autoupdate run --token "\$($JQ -r '.TunnelSecret' $CLOUDFLARED_HOME_DIR/.$TUNNEL_NAME.json)"
EOF

chmod 750 "$CLOUDFLARED_HOME_DIR/${TUNNEL_NAME}_tunnel.sh"
chown "$CLOUDFLARED_USER:$CLOUDFLARED_USER" "$CLOUDFLARED_HOME_DIR/${TUNNEL_NAME}_tunnel.sh"

echo "Tunnel start script created successfully"
exit 0