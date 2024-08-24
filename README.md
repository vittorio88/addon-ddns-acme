# DDNS-ACME Add-on for Home Assistant

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE.md)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

[![Github Actions][github-actions-shield]][github-actions]
[![GitHub Activity][commits-shield]][commits]
[![GitHub Last Commit][last-commit-shield]][commits]

[![Community Forum][forum-shield]][forum]

Automate Dynamic DNS updates and SSL certificate management for your Home Assistant instance.

## About

The DDNS-ACME add-on simplifies two critical aspects of maintaining a publicly accessible Home Assistant instance:

1. **Dynamic DNS (DDNS) Management**: Automatically updates your DNS records when your home IP address changes.
2. **SSL/TLS Certificate Automation**: Obtains and renews Let's Encrypt certificates for secure HTTPS access.

### Key Features

- 🔄 Automatic IP address detection and DNS record updates
- 🔒 Automated Let's Encrypt SSL/TLS certificate management
- 🌐 Support for both IPv4 and IPv6
- 🔧 Flexible configuration options
- 🏷️ Multi-domain and alias support
- 🔌 Easy integration with Home Assistant

### Supported DNS Providers

- Dynu
- DuckDNS

## Installation

1. Navigate to your Home Assistant instance's Supervisor panel.
2. Click on the "Add-on Store" tab.
3. Click the menu icon (⋮) in the top right corner and select "Repositories".
4. Add this repository URL: `https://github.com/vittorio88/addon-ddns-acme`
5. Find the "DDNS-ACME add-on" in the list and click on it.
6. Click on the "INSTALL" button.

## Configuration

```yaml
acme_provider_name: lets_encrypt
acme_accept_terms: false
acme_renew_wait: 43200
certfile: fullchain.pem
keyfile: privkey.pem
dns_provider_name: dynu
dns_api_token: your_api_token_here
ipv4_update_method: query external server
ipv6_update_method: get interface address via bashio
ip_update_wait_seconds: 3600
domains:
  - your_domain.duckdns.org
aliases:
  - domain: your_domain.duckdns.org
    alias: home.your_domain.com
```

### Option: `acme_provider_name`

The ACME certificate provider. Choose between `lets_encrypt` (production) or `lets_encrypt_test` (staging).

### Option: `acme_accept_terms`

Set to `true` to accept the Let's Encrypt terms of service.

### Option: `dns_provider_name`

Your DNS provider. Currently supports `dynu` or `duckdns`.

### Option: `dns_api_token`

The API token for your DNS provider.

### Option: `domains`

A list of domains to update and obtain certificates for.

### Option: `aliases`

A list of domain aliases, if any.

For more detailed information on each configuration option, please refer to our [full documentation](https://github.com/vittorio88/addon-ddns-acme/blob/main/ddns-acme/DOCS.md).

## Support

Got questions?


In case you've found a bug, please [open an issue on our GitHub][issue].

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

Thank you for being involved! :heart_eyes:

## Authors & contributors

The original setup of this repository is by [Vittorio Alfieri][vittorio88].

## License

MIT License

Copyright (c) 2024 Vittorio Alfieri

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[commits-shield]: https://img.shields.io/github/commit-activity/y/vittorio88/addon-ddns-acme.svg
[commits]: https://github.com/vittorio88/addon-ddns-acme/commits/main
[contributors]: https://github.com/vittorio88/addon-ddns-acme/graphs/contributors
[discord-shield]: https://img.shields.io/discord/330944238910963714.svg
[discord]: https://discord.gg/c5DvZ4e
[forum-shield]: https://img.shields.io/badge/community-forum-brightgreen.svg
[forum]: https://community.home-assistant.io/
[vittorio88]: https://github.com/vittorio88
[github-actions-shield]: https://github.com/vittorio88/addon-ddns-acme/workflows/CI/badge.svg
[github-actions]: https://github.com/vittorio88/addon-ddns-acme/actions
[issue]: https://github.com/vittorio88/addon-ddns-acme/issues
[license-shield]: https://img.shields.io/github/license/vittorio88/addon-ddns-acme.svg
[last-commit-shield]: https://img.shields.io/github/last-commit/vittorio88/addon-ddns-acme.svg
[project-stage-shield]: https://img.shields.io/badge/project%20stage-production%20ready-brightgreen.svg
[releases-shield]: https://img.shields.io/github/release/vittorio88/addon-ddns-acme.svg
[releases]: https://github.com/vittorio88/addon-ddns-acme/releases
