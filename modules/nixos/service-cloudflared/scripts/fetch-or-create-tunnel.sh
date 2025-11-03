#!@bash@
set -euo pipefail

# Parameters substituted by Nix
CF_ACCOUNT_API="@apiPath@"
CF_ACCOUNT_EMAIL="@emailPath@"
CF_ACCOUNT_ID="@accountIdPath@"
CLOUDFLARED_HOME_DIR="@homeDir@"
CLOUDFLARED_USER="@user@"
CURL="@curl@"
JQ="@jq@"
PING="@ping@"
TUNNEL_NAME="@tunnelName@"

# Read secrets from files at runtime
ACCOUNT_ID_CONTENT=$(cat "$CF_ACCOUNT_ID")
ACCOUNT_EMAIL_CONTENT=$(cat "$CF_ACCOUNT_EMAIL")
ACCOUNT_API_CONTENT=$(cat "$CF_ACCOUNT_API")

echo "Setting up tunnel: $TUNNEL_NAME"

# Wait for network connectivity
until $PING -c1 api.cloudflare.com; do
  echo "Waiting for network connectivity..."
  sleep 5
done


# Fetch existing tunnel
echo "Fetching tunnel id for $TUNNEL_NAME"

TUNNEL_ID=$($CURL -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID_CONTENT/cfd_tunnel" \
  -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
  -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
  | $JQ -r '.result[] | select(.name == "'"$TUNNEL_NAME"'" and .deleted_at == null) | .id')

# Validate TUNNEL_ID or create new tunnel
if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
  echo "Creating new tunnel: $TUNNEL_NAME"
  TUNNEL_ID=$($CURL -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID_CONTENT/cfd_tunnel" \
    -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
    -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
    -H "Content-Type: application/json" \
    --data '{"name":"'"$TUNNEL_NAME"'","config":{}}' \
    | $JQ -r '.result.id')
  
  if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
    echo "ERROR: Failed to fetch tunnel id for $TUNNEL_NAME"
    exit 1
  fi
  echo "Created tunnel with ID: $TUNNEL_ID"
else
  echo "Found existing tunnel: $TUNNEL_ID"
fi

# Fetch account tag
echo "Fetching account tag for $TUNNEL_ID"

ACCOUNT_TAG=$($CURL -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID_CONTENT/cfd_tunnel/$TUNNEL_ID" \
  -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
  -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
  | $JQ -r '.result.account_tag')

if [ -z "$ACCOUNT_TAG" ] || [ "$ACCOUNT_TAG" = "null" ]; then
  echo "ERROR: Failed to fetch account tag for tunnel $TUNNEL_ID"
  exit 1
fi

# Fetch tunnel secret/token
echo "Fetching tunnel secret for $TUNNEL_ID"

TUNNEL_RESPONSE=$($CURL -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID_CONTENT/cfd_tunnel/$TUNNEL_ID/token" \
  -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
  -H "X-Auth-Key: $ACCOUNT_API_CONTENT")

# Extract the token - the API might return it differently
TUNNEL_SECRET=$(echo "$TUNNEL_RESPONSE" | $JQ -r '.result')

if [ -z "$TUNNEL_SECRET" ] || [ "$TUNNEL_SECRET" = "null" ]; then
  echo "ERROR: Failed to fetch tunnel secret for tunnel $TUNNEL_ID"
  exit 1
fi

# Create home directory if it doesn't exist
mkdir -p "$CLOUDFLARED_HOME_DIR"
chown -R "$CLOUDFLARED_USER:$CLOUDFLARED_USER" "$CLOUDFLARED_HOME_DIR"

# Write configuration
echo "{\"AccountTag\":\"$ACCOUNT_TAG\",\"TunnelSecret\":\"$TUNNEL_SECRET\",\"TunnelID\":\"$TUNNEL_ID\"}" > "$CLOUDFLARED_HOME_DIR/.$TUNNEL_NAME.json"
chmod 600 "$CLOUDFLARED_HOME_DIR/.$TUNNEL_NAME.json"
chown "$CLOUDFLARED_USER:$CLOUDFLARED_USER" "$CLOUDFLARED_HOME_DIR/.$TUNNEL_NAME.json"
echo "Tunnel configuration successfully created"
exit 0