#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

function bashio::log.error() { printf 'ERROR %s
' "$*" >&2; }
function bashio::log.info() { :; }
function bashio::log.debug() { :; }
function bashio::log.warning() { :; }
function bashio::log.trace() { :; }

unset DNS_API_TOKEN
source "$REPO_ROOT/ddns-acme/rootfs/usr/bin/ddns-acme/dnsapi/dns_duckdns.sh"

echo "PASS dnsapi scripts source without global token"
