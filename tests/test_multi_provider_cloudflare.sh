#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_PATH=$(mktemp)
CALLS=$(mktemp)
LAST_FILE=$(mktemp)
trap 'rm -f "$CONFIG_PATH" "$CALLS" "$LAST_FILE"' EXIT

cat > "$CONFIG_PATH" <<'JSON'
{
  "acme_provider_name": "lets_encrypt_test",
  "acme_accept_terms": true,
  "acme_renew_wait": 43200,
  "certfile": "fullchain.pem",
  "keyfile": "privkey.pem",
  "ipv4_update_method": "use fixed address",
  "ipv4_fixed": "203.0.113.10",
  "ipv6_update_method": "skip update",
  "ipv6_fixed": "",
  "ip_update_wait_seconds": 3600,
  "aliases": [],
  "log_level": "info",
  "dns_accounts": [
    {"provider": "cloudflare", "token": "cf-token", "domains": ["cf.example.com"]},
    {"provider": "dynu", "token": "dynu-token", "domains": ["dynu.example.com"]}
  ]
}
JSON

function bashio::config() { jq -r --arg key "$1" '.[$key] | if type == "array" then .[] elif . == null then empty else . end' "$CONFIG_PATH"; }
function bashio::config.has_value() { jq -e --arg key "$1" '.[$key] != null and .[$key] != ""' "$CONFIG_PATH" >/dev/null; }
function bashio::log.level() { :; }
function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { printf 'WARN %s\n' "$*" >&2; }
function bashio::log.error() { printf 'ERROR %s\n' "$*" >&2; }
function bashio::log.trace() { :; }
function bashio::cache.flush_all() { :; }
function bashio::network.ipv4_address() { echo "203.0.113.10"; }
function bashio::network.ipv6_address() { echo "2001:db8::10/64"; }

source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/ddns.sh"
LAST_IP_UPDATE_FILE="$LAST_FILE"
CONFIG_PATH="$CONFIG_PATH"

function dns_cloudflare_update() { printf 'cloudflare|token=%s|domain=%s|ipv4=%s|ipv6=%s\n' "$DNS_API_TOKEN" "$1" "$2" "$3" >> "$CALLS"; }
function dns_dynu_update_ipv4_ipv6() { printf 'dynu|token=%s|domain=%s|ipv4=%s|ipv6=%s\n' "$DNS_API_TOKEN" "$1" "$2" "$3" >> "$CALLS"; }
function dns_duckdns_update() { printf 'duckdns|token=%s|domain=%s|ipv4=%s|ipv6=%s\n' "$DNS_API_TOKEN" "$1" "$2" "$3" >> "$CALLS"; }

hassio_get_config_variables
update_dns_ip_addresses "203.0.113.10" ""

expected=$'cloudflare|token=cf-token|domain=cf.example.com|ipv4=203.0.113.10|ipv6=\ndynu|token=dynu-token|domain=dynu.example.com|ipv4=203.0.113.10|ipv6='
actual=$(cat "$CALLS")
if [ "$actual" != "$expected" ]; then
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

echo "PASS Cloudflare DDNS dispatch"
