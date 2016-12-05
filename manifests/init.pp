class transip (
  $username,
  $ip,
  $key_file,
  $dns_records = {
  }
) {
  file { '/etc/transip/credentials':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('transip/credentials.erb');
  }

  create_resources(dns_record, $dns_records)
}