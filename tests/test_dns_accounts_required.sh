#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_PATH=$(mktemp)
trap 'rm -f "$CONFIG_PATH"' EXIT

cat > "$CONFIG_PATH" <<'JSON'
{
  "acme_provider_name": "lets_encrypt_test",
  "acme_accept_terms": true,
  "acme_renew_wait": 43200,
  "certfile": "fullchain.pem",
  "keyfile": "privkey.pem",
  "dns_provider_name": "dynu",
  "dns_api_token": "legacy-token",
  "ipv4_update_method": "use fixed address",
  "ipv4_fixed": "203.0.113.10",
  "ipv6_update_method": "skip update",
  "ipv6_fixed": "",
  "ip_update_wait_seconds": 3600,
  "domains": ["legacy.example.com"],
  "aliases": [],
  "log_level": "info"
}
JSON

function bashio::config() { jq -r --arg key "$1" '.[$key] | if type == "array" then .[] elif . == null then empty else . end' "$CONFIG_PATH"; }
function bashio::config.has_value() { jq -e --arg key "$1" '.[$key] != null and .[$key] != ""' "$CONFIG_PATH" >/dev/null; }
function bashio::log.level() { :; }
function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { printf 'WARN %s
' "$*" >&2; }
function bashio::log.error() { printf 'ERROR %s
' "$*" >&2; }
function bashio::log.trace() { :; }
function bashio::cache.flush_all() { :; }
function bashio::network.ipv4_address() { echo "203.0.113.10"; }
function bashio::network.ipv6_address() { echo "2001:db8::10/64"; }

source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/ddns.sh"
CONFIG_PATH="$CONFIG_PATH"

stderr_file=$(mktemp)
trap 'rm -f "$CONFIG_PATH" "$stderr_file"' EXIT

if hassio_get_config_variables 2>"$stderr_file"; then
  echo "expected legacy-only domains config to be rejected" >&2
  exit 1
fi

if ! grep -q "Old-style DNS configuration detected" "$stderr_file"; then
  echo "expected explicit old-style config error in logs" >&2
  cat "$stderr_file" >&2
  exit 1
fi

if ! grep -q "Breaking change in DDNS-ACME 3.0.0" "$stderr_file"; then
  echo "expected 3.0.0 breaking-change guidance in logs" >&2
  cat "$stderr_file" >&2
  exit 1
fi

echo "PASS dns_accounts required and legacy config emits error"
