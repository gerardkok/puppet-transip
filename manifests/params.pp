class transip::params {
  case $::osfamily {
    'Darwin' : {
      $owner = 'root'
      $group = 'wheel'
    }
    default  : {
      $owner = 'root'
      $group = 'root'
    }
  }
}
