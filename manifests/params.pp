class transip::params {
  case $::osfamily {
    'Darwin' : {
      $owner = 'root'
      $group = 'wheel'
      $config_file = '/etc/puppetlabs/puppet/transip.yaml'
    }
    default  : {
      $owner = 'root'
      $group = 'root'
      $config_file = '/etc/puppetlabs/puppet/transip.yaml'
    }
  }
}
