<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->

## [1.3.0] - 2024-08-23

- Refactor DNS provider handling for better modularity
- Enhance ACME certificate renewal and IP update process by using files with timestamps.
- Add logo.png and icon.png
- Update documentation and comments for better clarity
- Merge changes with rebase from HA Example Add-on to fix builds. 
    Note: If you get git issues, nuke your repo, and clone again.
- Add install instructions to README.md

## [1.2.0] - 2024-08-21

- Add ability to use different ACME server and different DNS servers.
- Add Let's Encrypt Test Server.
- Add support for DuckDNS.
- NOTE: Please update your configuration options with the following procedure:
        a) Uninstall the addon
        b) restart home assistant supervisor
        c) Reinstall the addon

## [1.1.0] - 2024-08-20

- Update to allow for different DNS and ACME providers.
- Update to allow configurable methods to determine IPv4 and IPv6 addresses.
- NOTE: Please update your configuration options with the following procedure:
        a) Uninstall the addon
        b) restart home assistant supervisor
        c) Reinstall the addon

## [1.0.0] - 2024-02-04

- Initial release. First Version of most of the large changes that originated from other repos.
