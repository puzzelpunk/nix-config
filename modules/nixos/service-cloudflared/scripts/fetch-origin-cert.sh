#!@bash@
set -euo pipefail

# Parameters substituted by Nix
CF_ACCOUNT_API="@apiPath@"
CF_ACCOUNT_EMAIL="@emailPath@"
CLOUDFLARED_HOME_DIR="@homeDir@"
CURL="@curl@"
JQ="@jq@"
PING="@ping@"
SUBDOMAIN="@subdomain@"

# Read secrets from files at runtime
ACCOUNT_EMAIL_CONTENT=$(cat "$CF_ACCOUNT_EMAIL")
ACCOUNT_API_CONTENT=$(cat "$CF_ACCOUNT_API")

echo "Fetching origin certificate for: $SUBDOMAIN"

# Wait for network connectivity
until $PING -c1 api.cloudflare.com; do
  echo "Waiting for network connectivity..."
  sleep 5
done

# Fetch certificate
$CURL -X POST "https://api.cloudflare.com/client/v4/certificates" \
  -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
  -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
  -H "Content-Type: application/json" \
  --data '{"hostnames":["'"$SUBDOMAIN"'"],"requested_validity":5184000}' \
  | $JQ -r '.result.certificate' > "$CLOUDFLARED_HOME_DIR/$SUBDOMAIN.pem"

# Fetch private key
$CURL -X POST "https://api.cloudflare.com/client/v4/certificates" \
  -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
  -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
  -H "Content-Type: application/json" \
  --data '{"hostnames":["'"$SUBDOMAIN"'"],"requested_validity":5184000}' \
  | $JQ -r '.result.private_key' > "$CLOUDFLARED_HOME_DIR/$SUBDOMAIN.key"

echo "Origin certificate for $SUBDOMAIN successfully created"
exit 0