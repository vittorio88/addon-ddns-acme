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
    {"provider": "dynu", "token": "dynu-business-a-token", "domains": ["biz-a.example.com"]},
    {"provider": "dynu", "token": "dynu-business-b-token", "domains": ["biz-b.example.net"]}
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

function dns_dynu_add_txt_record() { printf 'dynu|token=%s|domain=%s|value=%s\n' "$DNS_API_TOKEN" "$1" "$2" >> "$CALLS"; }
function dns_duckdns_add_txt_record() { printf 'duckdns|token=%s|domain=%s|value=%s\n' "$DNS_API_TOKEN" "$1" "$2" >> "$CALLS"; }

deploy_challenge "biz-b.example.net" "token-file" "challenge-value"

expected=$'dynu|token=dynu-business-b-token|domain=biz-b.example.net|value=challenge-value'
actual=$(cat "$CALLS")
if [ "$actual" != "$expected" ]; then
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

echo "PASS same-provider multiple DNS accounts ACME hook dispatch"
