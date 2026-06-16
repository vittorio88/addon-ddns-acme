# Home Assistant Add-on: DDNS-ACME

DDNS-ACME keeps DNS records current for one or more domains and manages a Let's Encrypt certificate for Home Assistant using DNS-01 validation.

## What it does

- Updates IPv4 and/or IPv6 DNS records when your public address changes.
- Issues and renews a Home Assistant-compatible certificate at `/ssl/fullchain.pem` and `/ssl/privkey.pem` by default.
- Uses DNS-01 ACME challenges, so certificate issuance does not require exposing Home Assistant on port 80.
- Supports multiple DNS provider accounts in one add-on configuration.
- Skips unnecessary ACME orders when the installed certificate is still valid and already covers the configured DNS names.

## Supported DNS providers

- Cloudflare
- Dynu
- DuckDNS

## Basic configuration

```yaml
acme_provider_name: lets_encrypt
acme_accept_terms: true
acme_renew_wait: 43200
certfile: fullchain.pem
keyfile: privkey.pem
ipv4_update_method: query external server
ipv4_fixed: ""
ipv6_update_method: get interface address via bashio
ipv6_fixed: ""
ip_update_wait_seconds: 3600
dns_accounts:
  - provider: cloudflare
    token: your-cloudflare-token
    domains:
      - hass.example.com
  - provider: dynu
    token: your-dynu-token
    domains:
      - backup.example.net
aliases: []
log_level: info
```

`dns_accounts` is required. Each entry contains a provider, token, and the domains managed by that provider account. Multiple entries may use the same provider when different domains use different accounts or tokens.

Legacy top-level `dns_provider_name`, `dns_api_token`, and `domains` options are not supported in current releases.

## Home Assistant HTTPS configuration

Configure Home Assistant Core to use the generated certificate:

```yaml
http:
  ssl_certificate: /ssl/fullchain.pem
  ssl_key: /ssl/privkey.pem
```

## More documentation

See [`DOCS.md`](DOCS.md) for full option details, provider notes, and troubleshooting.

## Source

Repository: <https://github.com/vittorio88/addon-ddns-acme>
