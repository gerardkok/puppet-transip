class transip (
  String $username,
  String $ip,
  String $key_file,
  String $owner     = $::transip::params::owner,
  String $group     = $::transip::params::group,
  Hash $dns_records = {}
) inherits ::transip::params {
  file {
    $::transip::params::config_file:
      ensure  => 'present',
      owner   => $owner,
      group   => $group,
      mode    => '0600',
      content => template('transip/transip.yaml.erb');
  }

  create_resources(dns_record, $dns_records)
}
