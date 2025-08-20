<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->

## [2.0.0] - 2025-08-20

### Security & Reliability Improvements
- Fix unbound variable issue when IPv4/IPv6 update methods are set to "skip"
- Fix variable quoting in domain loops to prevent parsing errors
- Improve curl command parameter handling for better security
- Add comprehensive error handling with retries and timeouts for network operations
- Implement proper input validation for IP addresses and domains
- Enhanced IPv4/IPv6 validation with `is_valid_ipv4()` and `is_valid_ipv6()` functions
- Improved domain validation with length limits and better error messages

## [1.3.4] - 2025-08-20

- Refactor startup initialization into dedicated `perform_startup_initialization()` function
- Extract main loop logic into `run_main_loop()` function for better code organization
- Replace temporary file I/O with global variables for improved performance
- Eliminate filesystem operations during startup IP checks
- Improve code maintainability with modular function-based architecture

## [1.3.3] - 2025-08-20

- Fix bug where addon would halt when no IP differences were detected on startup
- Improve error handling and graceful degradation for startup IP checks
- Add better DNS lookup error handling to prevent startup failures
- Isolate startup IP check in subshell to prevent any exit conditions from halting the addon
- Fix "unbound variable" error when update_dns_ip_addresses is called without parameters

## [1.3.2] - 2025-08-20

- Add IP address difference detection on addon restart
- Perform immediate DDNS update when local IP differs from DNS records on startup
- Add bind-tools package to support DNS record queries
- Prevent unnecessary DNS provider requests when IP addresses haven't changed
- Optimize IP address detection to eliminate duplicate external server queries on startup
- Restructure functions to pass IP addresses explicitly instead of using global caching
- Improve documentation to clarify when fixed IP address fields are needed
- Add validation for fixed IP address configuration to provide helpful error messages

## [1.3.1] - 2024-08-23

- Enhanced error handling and logging

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
