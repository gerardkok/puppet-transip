class transip (
  String $username           = '',
  Optional[String] $key      = undef,
  Optional[String] $key_file = undef,
  Boolean $readwrite         = false,
  String $owner              = $::transip::params::owner,
  String $group              = $::transip::params::group,
  Boolean $manage_gems       = true,
  Hash $dns_entries          = {}
) inherits ::transip::params {
  if $manage_gems {
    package {
      'savon':
        ensure   => 'present',
        provider => 'puppet_gem';
    }
  }

  file {
    $::transip::params::config_file:
      ensure  => 'present',
      owner   => $owner,
      group   => $group,
      mode    => '0600',
      content => template('transip/transip.yaml.erb');
  }

  create_resources(transip_dns_entry, $dns_entries)
}
