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
    {"provider": "dynu", "token": "dynu-token", "domains": ["dynu.example.com"]},
    {"provider": "duckdns", "token": "duck-token", "domains": ["duck.example.org"]}
  ]
}
JSON

function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { printf 'WARN %s\n' "$*" >&2; }
function bashio::log.error() { printf 'ERROR %s\n' "$*" >&2; }
function bashio::log.trace() { :; }
function sleep() { :; }

set -- noop
source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/hooks/hooks_multi.sh"

function dns_dynu_add_txt_record() { printf 'dynu|token=%s|domain=%s|value=%s\n' "$DNS_API_TOKEN" "$1" "$2" >> "$CALLS"; }
function dns_duckdns_add_txt_record() { printf 'duckdns|token=%s|domain=%s|value=%s\n' "$DNS_API_TOKEN" "$1" "$2" >> "$CALLS"; }

deploy_challenge dynu.example.com token-file dynu-value
deploy_challenge duck.example.org token-file duck-value

expected=$'dynu|token=dynu-token|domain=dynu.example.com|value=dynu-value\nduckdns|token=duck-token|domain=duck.example.org|value=duck-value'
actual=$(cat "$CALLS")
if [ "$actual" != "$expected" ]; then
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

echo "PASS multi-provider ACME hook dispatch"
