#!/bin/sh

/opt/puppetlabs/bin/puppet resource transip_dns_entry "_acme-challenge.${CERTBOT_DOMAIN}/TXT" ensure="absent"
