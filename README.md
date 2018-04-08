# puppet-transip

[![BCH compliance](https://bettercodehub.com/edge/badge/gerardkok/puppet-transip)](https://bettercodehub.com)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [What puppet-transip affects](#what-puppet-transip-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with puppet-transip](#beginning-with-puppet-transip)
4. [Usage](#usage)
5. [Reference](#reference)
5. [Limitations](#limitations)
6. [Development](#development)

## Overview

This module allows managing dns records on [TransIP](https://www.transip.nl/) hosted domains.

## Module Description

This module provides a custom provider to manage dns records on domains hosted on TransIP's DNS servers. 
The provider uses the TransIP [API](https://www.transip.nl/transip/api/) to handle changes.

## Setup

### What puppet-transip affects

* This module potentially modifies the contents of dns records from your TransIP domains. If you also manage these records from elsewhere (for example, through the control panel), then these modifications might interfere.

### Setup Requirements
* An account to access TransIP's [control panel](https://www.transip.nl/cp/).
* API access enabled for this account. How to enable the API is described in https://www.transip.nl/vragen/205-hoe-schakel-transip-api-in/.
* A private key needs to be generated.
* The public ip address of the instance you run this module on needs to be whitelisted.
* The [savon](http://savonrb.com) ruby gem.

For Puppet 4 and 5, the savon gem needs to be installed in `/opt/puppetlabs/puppet/lib/ruby/gems` on the instance you enable this module on. You can do this manually as follows:
```bash
$ sudo /opt/puppetlabs/puppet/bin/gem install rack -v 1.6.9 # (necessary for puppet 4)
$ sudo /opt/puppetlabs/puppet/bin/gem install savon
```
Alternatively, you can set `manage_gems` to 'true', to have the module install the necessary gems for you.

Because the `transip_dns_entry` type does not reference this gem, it shouldn't be needed to install it for use with Puppet Server on your puppet master.

### Beginning with puppet-transip

This module should be enabled on one of your instances that is allowed to access the TransIP API over the Internet. It is perfectly possible to run this module on multiple instances, just be aware of interference when you're going to manage the same dns records. The TransIP API requires that you whitelist the public ip address of this instance.

Minimal usage:
```puppet
class { 'transip':
  username => 'TransIP control panel username',
  key_file => 'filename containing your TransIP private key'
}
```

The above configuration doesn't manage any dns records yet, but you can run ``puppet resource transip_dns_entry`` on the instance to get a list of all your TransIP dns records.

## Usage

### Hiera

Example configuration through hiera:
~~~
transip::username: 'TransIP control panel username'
transip::key_file: 'filename containing your TransIP private key'
transip::readwrite: true
transip::dns_entries:
  'www.my.domain/A'
    ensure: 'present'
    ttl: '300'
    content: '192.0.2.1'
  'my.domain/MX':
    ensure: 'present'
    ttl: '86400'
    content: '10 mail.my.domain.'
~~~

### Let's Encrypt

To issue Let's Encrypt certificates using the dns challenge, you can use the scripts the example scripts in the `scripts` folder. `authenticator.sh` adds the challenge to your TransIP dns records, while `cleanup.sh` removes it. Example usage with `certbot`:
```bash
$ sudo certbot --text --agree-tos --non-interactive certonly -a manual --keep-until-expiring -d <domain> --preferred-challenges dns --manual-public-ip-logging-ok --manual-auth-hook <scripts/authenticator.sh> --manual-cleanup-hook <scripts/cleanup.sh> --expand
```
Note that `authenticator.sh` has a (lengthy) timeout to give TransIP authorized nameservers ample time to propagate the challenge.

## Reference

The module provides the ``transip_dns_entry`` custom type that has an ``api`` provider.

### Parameters

#### `transip` class

##### `username`

The username used to access TransIP's control panel.

##### `key`

Private key to access the TransIP API. Get this from the API tab of your control panel. If you set both `key` and `key_file`, `key` will be used.

##### `key_file`

Filename of the file containing your private key to access the TransIP API. Get this from the API tab of your control panel. If you set both `key` and `key_file`, `key` will be used.

##### `readwrite`

Boolean. If 'false', open a readonly connection, if 'true', open a readwrite connection. Will throw an error if you attempt to modify records over a readonly connection. Default 'false' (i.e. readonly).

##### `owner`

The owner of the file containing the credentials. Default: depends on your operating system.

##### `group`

The group of the file containing the credentials. Default: depends on your operating system.

##### `manage_gems`

Boolean. If 'false', don't install the necessary gems, if 'true', do install the necessary gems. Default 'true'.

##### `dns_entries`

A hash of dns entry resources that the module will create.

#### `transip_dns_entry` type

##### `name`

The fully qualified domain name plus the type of your record, formatted like 'fqdn/type'. If you omit '/type', type defaults to 'A'.
The origin sign '@' can be omitted. For example, if you want to create an MX record for your domain, use 'my.domain/MX' as transip_dns_entry name.

##### `fqdn`

The fully qualified domain name. The fqdn will be matched against your TransIP domains, no match will result in an error. Defaults to the part of the `name` before the '/', or just `name` if `name` doesn't contain a '/'.

##### `type`

The type of the record. Possible values: 'A', 'AAAA', 'CAA', 'CNAME', 'MX', 'NS', 'SRV', 'TXT'. Defaults to the part of the `name` after the '/', or just 'A' if `name` doesn't contain a '/'.

##### `content`

The content of a record. This can be specified as an array, if this array has multiple entries, a record is created for each entry in your domain. For example, the puppet resource
```puppet
transip_dns_entry {
  'www.my.domain/A':
    ensure  => 'present',
    ttl     => '300',
    content => ['192.0.2.1', '192.0.2.2'];
}
```
will result in two A records for 'www.my.domain' in TransIP's dns tables.

If `content` is empty, or if `type` is 'CNAME' and `content` has more than one entry, an error is raised.

##### `ttl`

The TTL field of a dns record. Defaults to 3600 seconds.

## Limitations

Currently tested with a very limited number of domains and dns records.

The locations of the credentials file is currently fixed to `transip.yaml` in the [Puppet confdir](https://docs.puppet.com/puppet/latest/dirs_confdir.html).

## Development

Run `rake spec` to run all tests. The [savon](http://savonrb.com) gem is not required to run the tests.
