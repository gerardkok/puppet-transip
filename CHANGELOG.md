## Release 0.3.1

- converted to PDK
- simplified the 'from_soap' and 'to_soap' methods in the Transip module
- fixed a (theoretical) error in retrieval of TransIP managed domains

## Release 0.3.0

- now only depends on the [savon](http://savonrb.com) gem, instead of the [transip](https://github.com/joost/transip) gem (fewer dependencies is better)
- added more rspec tests
- added 'CAA' record type (it works, although the api doesn't list it)
- 'ip' parameter no longer necessary (it is still necessary to whitelist your external ip address)
- added 'readwrite' parameter, this allows for readonly or readwrite access
- added 'manage_gems' parameter, indicating if you want puppet to install the necessary gems
- you can now pass either a private key directly or a name of a file containing your private key
- renamed 'dns_record' to 'transip_dns_entry'
- added Let's Encrypt example scripts

## Release 0.2.0

- puppet 4 support (although this only affects init.pp)
- added more rspec tests
- bugfixes for bugs found with the above
- added 'transip_configured' feature
- moved everything related to [transip](https://github.com/joost/transip) to [client.rb](lib/puppet_x/transip/client.rb) (this allows for running the tests without installing the gem)

## Release 0.1.0

Initial release.
