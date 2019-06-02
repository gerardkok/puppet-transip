#!/bin/sh


/opt/puppetlabs/bin/puppet resource transip_dns_entry "_acme-challenge.${CERTBOT_DOMAIN}/TXT" ensure="present" content="${CERTBOT_VALIDATION}" content_handling="minimum" ttl=60

sleep 360 # ensure dns change has propagated
