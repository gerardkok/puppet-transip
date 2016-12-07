class transip (
  $username,
  $ip,
  $key_file,
  $owner       = $::transip::params::owner,
  $group       = $::transip::params::group,
  $dns_records = {
  }
) inherits ::transip::params {
  file { '/etc/transip/credentials':
    ensure  => 'present',
    owner   => $owner,
    group   => $group,
    mode    => '0600',
    content => template('transip/credentials.erb');
  }

  create_resources(dns_record, $dns_records)
}