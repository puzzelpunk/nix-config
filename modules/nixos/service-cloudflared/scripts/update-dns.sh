#!@bash@
set -euo pipefail

# Parameters substituted by Nix
CF_ACCOUNT_API="@apiPath@"
CF_ACCOUNT_EMAIL="@emailPath@"
CF_ACCOUNT_ID="@accountIdPath@"
CLOUDFLARED_HOME_DIR="@homeDir@"
CURL="@curl@"
GAWK="@gawk@"
INGRESS_DOMAINS="@ingress_domains@"
JQ="@jq@"
PING="@ping@"
TUNNEL_NAME="@tunnelName@"

# Read secrets from files at runtime
ACCOUNT_ID_CONTENT=$(cat "$CF_ACCOUNT_ID")
ACCOUNT_EMAIL_CONTENT=$(cat "$CF_ACCOUNT_EMAIL")
ACCOUNT_API_CONTENT=$(cat "$CF_ACCOUNT_API")

get_domain() {  
  domain=$1
  echo "$domain" | $GAWK -F. '{n = NF; if ($(n-1) == "co" || $(n-1) == "com") {print $(n-2) "." $(n-1) "." $n} else {print $(n-1) "." $n}}'
}

get_zone_id() {
  domain=$1
  zone_id=$($CURL -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
    -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
    -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
    | $JQ -r '.result[0].id')
  echo $zone_id
}

update_cname_record() {
  subdomain=$1
  zone_id=$2
  cname_target=$3
  echo "Setting CNAME record of $subdomain to $cname_target"

  # Check if the DNS record exists
  record_id=$($CURL -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$subdomain&type=CNAME" \
    -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
    -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
    | $JQ -r '.result[0].id')

  if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
    # Update existing CNAME record
    $CURL -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
      -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
      -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
      -H "Content-Type: application/json" \
      --data '{"type":"CNAME","name":"'"$subdomain"'","content":"'"$cname_target"'","ttl":120,"proxied":true}'

    echo "Updated CNAME for $subdomain"
  else
    # Create new CNAME record
    $CURL -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "X-Auth-Email: $ACCOUNT_EMAIL_CONTENT" \
      -H "X-Auth-Key: $ACCOUNT_API_CONTENT" \
      -H "Content-Type: application/json" \
      --data '{"type":"CNAME","name":"'"$subdomain"'","content":"'"$cname_target"'","ttl":120,"proxied":true}'

    echo "Created CNAME for $subdomain"
  fi
}

echo "Updating DNS records for: $INGRESS_DOMAINS"

# Wait for network connectivity
until $PING -c1 api.cloudflare.com; do
  echo "Waiting for network connectivity..."
  sleep 5
done

# Get tunnel ID from credentials file
TUNNEL_ID=$($JQ -r '.TunnelID' "$CLOUDFLARED_HOME_DIR/.$TUNNEL_NAME.json")
CNAME="$TUNNEL_ID.cfargotunnel.com"

# Update DNS for each ingress domain
for subdomain in $INGRESS_DOMAINS; do
  domain=$(get_domain $subdomain)
  zone_id=$(get_zone_id $domain)
  update_cname_record $subdomain $zone_id $CNAME
done

echo "DNS records updated successfully"
exit 0