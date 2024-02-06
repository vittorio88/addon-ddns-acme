# Home Assistant Add-on: DDNS-ACME add-on

Update your DNS Providers registered IPv4 and IPv6, and then 
use ACME with the same DNS API to add a TXT record 
for verifying domain ownership with Let's Encrypt._

NOTE: Currently only support DynuDNS, but additional 
DNS providers may be easily added by adding interfaces in:
 - hooks/
 - dnsapi/
and customizing ddns.sh and acme.sh

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg



## About

[DDNS-ACME](ddns-acme) Integrated determine public addresses, update DNS records, and generate ACME certificate from Lets Encrypt.
