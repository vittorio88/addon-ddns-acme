#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_PATH=$(mktemp)
CALLS=$(mktemp)
WORK_DIR_TMP=$(mktemp -d)
SSL_DIR=$(mktemp -d)
trap 'rm -f "$CONFIG_PATH" "$CALLS"; rm -rf "$WORK_DIR_TMP" "$SSL_DIR"' EXIT

cat > "$CONFIG_PATH" <<'JSON'
{
  "acme_provider_name": "lets_encrypt_test",
  "acme_accept_terms": true,
  "certfile": "fullchain.pem",
  "keyfile": "privkey.pem",
  "aliases": [],
  "dns_accounts": [
    {"provider": "dynu", "token": "dynu-token", "domains": ["fv-hass.figvic.com"]},
    {"provider": "cloudflare", "token": "cf-token", "domains": ["lb-rtr1.lagohoa.org"]}
  ]
}
JSON

function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { printf 'WARN %s\n' "$*" >&2; }
function bashio::log.error() { printf 'ERROR %s\n' "$*" >&2; }
function bashio::log.trace() { :; }

source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/acme.sh"
CONFIG_PATH="$CONFIG_PATH"
WORK_DIR="$WORK_DIR_TMP"
LAST_ACME_OP_FILE="$WORK_DIR_TMP/last_acme_op"
DNS_ACCOUNTS_JSON=$(jq -c '[.dns_accounts[]]' "$CONFIG_PATH")
export DNS_ACCOUNTS_JSON

function certificate_needs_renewal() {
  if [ "$1" != "fullchain.pem" ]; then
    echo "unexpected certfile $1" >&2
    return 1
  fi
  shift
  printf 'DOMAINS:%s\n' "$*" >> "$CALLS"
  return 1
}

function acme_register_if_needed() {
  echo REGISTER >> "$CALLS"
}

function dehydrated() {
  echo "DEHYDRATED $*" >> "$CALLS"
}

acme_renew lets_encrypt_test true ""

actual=$(cat "$CALLS")
if ! grep -q 'DOMAINS:fv-hass.figvic.com lb-rtr1.lagohoa.org' <<< "$actual"; then
  echo "expected one combined certificate domain set" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi
if grep -q 'REGISTER\|DEHYDRATED' <<< "$actual"; then
  echo "valid combined certificate should skip account registration and ACME order" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi
if [ ! -s "$LAST_ACME_OP_FILE" ]; then
  echo "expected cooldown marker to be touched on valid-cert skip" >&2
  exit 1
fi

echo "PASS combined certificate ACME guard"
