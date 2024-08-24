#!/bin/sh

aider --sonnet \
--no-auto-commit \
README.md \
ddns-acme/config.yaml \
ddns-acme/rootfs/usr/bin/ddns-acme/acme.sh \
ddns-acme/rootfs/usr/bin/ddns-acme/ddns.sh \
ddns-acme/rootfs/usr/bin/ddns-acme/run.sh \
ddns-acme/rootfs/usr/bin/ddns-acme/dnsapi/dns_dynu.sh \
ddns-acme/rootfs/usr/bin/ddns-acme/dnsapi/dns_duckdns.sh \
ddns-acme/rootfs/usr/bin/ddns-acme/hooks/hooks_duckdns.sh \
ddns-acme/rootfs/usr/bin/ddns-acme/hooks/hooks_dynu.sh
