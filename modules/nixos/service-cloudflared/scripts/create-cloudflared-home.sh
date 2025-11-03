set -euo pipefail

# Parameters substituted by Nix
CLOUDFLARED_HOME_DIR="@homeDir@"
CLOUDFLARED_USER="@user@"

echo "Creating cloudflared home directory: $CLOUDFLARED_HOME_DIR"

# Create directory and set ownership
mkdir -p "$CLOUDFLARED_HOME_DIR"
chown -R "$CLOUDFLARED_USER:$CLOUDFLARED_USER" "$CLOUDFLARED_HOME_DIR"

echo "Cloudflared home directory created successfully"
exit 0