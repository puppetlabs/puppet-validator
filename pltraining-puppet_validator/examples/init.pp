$vhostname = $::fqdn,
$port      = '80',
$path      = '/var/www/puppet-validator'

include epel

class { 'apache':
  default_vhost => false,
  subscribe     => Class['puppet-validator'],
}

class { 'apache::mod::passenger':
  passenger_high_performance => 'off',
}

apache::vhost { $vhostname:
  port           => $port,
  docroot        => "${path}/public",
  manage_docroot => false,
  priority       => '25',
  passenger_ruby => '/usr/bin/ruby',
  options        => ['-MultiViews']
}

class { 'puppet_validator':
  versions => ['5.3.3', '4.9.0', '2.7.4', '3.6.2', '3.8.5'],
}
