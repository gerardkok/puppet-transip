# puppet-transip

[![BCH compliance](https://bettercodehub.com/edge/badge/gerardkok/puppet-transip)](https://bettercodehub.com)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with reposado](#setup)
    * [What reposado affects](#what-reposado-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with reposado](#beginning-with-reposado)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This module allows managing dns records on [TransIP](https://www.transip.nl/) hosted domains.

## Module Description

This module provides a custom provider to manage dns records on domains hosted on TransIP's DNS servers. 
The provider uses the TransIP [API](https://www.transip.nl/transip/api/) to handle changes.

## Setup

### What puppet-transip affects

* This module potentially modifies the contents of dns records from your TransIP domains. If you also manage these records from elsewhere (for example, through the control panel), then these modifications might interfere.

### Setup Requirements
* An account to access TransIP's [control panel](https://www.transip.nl/cp/) is required, and API access needs to be enabled for this account. How to enable the API is described in https://www.transip.nl/vragen/205-hoe-schakel-transip-api-in/.
* The [transip](https://github.com/joost/transip) ruby gem.

### Beginning with puppet-transip

This module should be enabled on one of your instances that is allowed to access the TransIP API over the Internet. It is perfectly possible to run this module on multiple instances, just be aware of interference when you're going to manage the same dns records. The TransIP API requires that you whitelist the public ip address of this instance.

Minimal usage:
```puppet
class { 'transip':
  username => 'TransIP control panel username',
  ip => 'TransIP API whitelisted ip address',
  key_file => 'filename containing your TransIP private key'
}
```

The above configuration doesn't manage any dns records yet, but you can run ``puppet resource dns_record`` on the instance to get a list of all your TransIP dns records.

## Usage

Example configuration through hiera:
~~~
transip::username: 'TransIP control panel username'
transip::ip: 'TransIP API whitelisted ip address'
transip::key_file: 'filename containing your TransIP private key'
transip::dns_records:
  'www.my.domain/A'
    ensure: 'present'
    ttl: '300'
    content: '192.0.2.1'
  'my.domain/MX':
    ensure: 'present'
    ttl: '86400'
    content: '10 mail.my.domain.'
~~~

## Reference

The module provides the ``dns_record`` custom type that has an ``api`` provider.

### Parameters

#### `transip` class

##### `username`

The username used to access TransIP's control panel.

##### `ip`

A public ip address whitelisted to use TransIP's API. Set this on the [API tab of the control panel](https://www.transip.nl/cp/account/api/)

##### `key_file`

Filename of the file containing your private key to access the TransIP API. Get this from the API tab of your control panel.

#### `dns_record` type

##### `name`

The fully qualified domain name plus the type of your record, formatted like 'fqdn/type'. If you omit '/type', type defaults to 'A'.
The origin sign '@' can be omitted. For example, if you want to create an MX record for your domain, use 'my.domain/MX' as dns_record name.

##### `fqdn`

The fully qualified domain name. The fqdn will be matched against your TransIP domains, no match will result in an error. Defaults to the part of the `name` before the '/', or just `name` if `name` doesn't contain a '/'.

##### `type`

The type of the record. Possible values: 'A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SRV'. Defaults to the part of the `name` after the '/', or just 'A' if `name` doesn't contain a '/'.

##### `content`

The content of a record. This can be specified as an array, if this array has multiple entries, a record is created for each entry in your domain. For example, the puppet resource
```puppet
dns_record {
  'www.my.domain/A':
    ensure => 'present',
    ttl => '300',
    content => ['192.0.2.1', '192.0.2.2'];
}
```
will result in two A records for 'www.my.domain' in TransIP's dns tables.

##### `ttl`

The TTL field of a dns records. Defaults to 3600 seconds.

## Limitations

Currently tested on Ubuntu 16.04 only, with a very limited number of domains and dns records.

## Release Notes

First release, no fancy options yet.

## Disclaimer

Use at your own risk.
