#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_PATH=$(mktemp)
CALLS=$(mktemp)
trap 'rm -f "$CONFIG_PATH" "$CALLS"' EXIT

cat > "$CONFIG_PATH" <<'JSON'
{
  "certfile": "fullchain.pem",
  "keyfile": "privkey.pem",
  "aliases": [],
  "dns_accounts": [
    {"provider": "cloudflare", "token": "cf-token", "domains": ["cf.example.com"]}
  ]
}
JSON

function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { printf 'WARN %s\n' "$*" >&2; }
function bashio::log.error() { printf 'ERROR %s\n' "$*" >&2; }
function bashio::log.trace() { :; }
function sleep() { :; }

CONFIG_PATH="$CONFIG_PATH" source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/hooks/hooks_multi.sh" noop

function dns_cloudflare_add_txt_record() { printf 'cloudflare-add|token=%s|domain=%s|value=%s\n' "$DNS_API_TOKEN" "$1" "$2" >> "$CALLS"; }
function dns_cloudflare_rm_txt_record() { printf 'cloudflare-rm|token=%s|domain=%s|value=%s\n' "$DNS_API_TOKEN" "$1" "$2" >> "$CALLS"; }

deploy_challenge cf.example.com token-file cf-value
clean_challenge cf.example.com token-file cf-value

expected=$'cloudflare-add|token=cf-token|domain=cf.example.com|value=cf-value\ncloudflare-rm|token=cf-token|domain=cf.example.com|value=cf-value'
actual=$(cat "$CALLS")
if [ "$actual" != "$expected" ]; then
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

echo "PASS Cloudflare ACME hook dispatch"
