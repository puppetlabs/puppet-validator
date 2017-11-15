class puppet_validator (
  $vhostname   = $::fqdn,
  $port        = '80',
  $path        = '/var/www/puppet-validator',
  $versions    = undef,
) {
  include epel

  class { 'apache':
    default_vhost => false,
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

  # Since we don't use the default vhost, let's make sure the dir exists
  dirtree { $path:
    ensure  => present,
    parents => true,
    before  => File[$path]
  }

  file { $path:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Class['apache'],
  }

  exec { 'puppet-validator init':
    cwd     => $path,
    creates => "${path}/config.ru",
    path    => '/bin:/usr/bin/:/usr/local/bin',
    notify  => Class['apache'],
    require => Package['puppet-validator'],
  }

  package { 'puppet-validator':
    ensure   => present,
    provider => gem,
    before   => Class['apache'],
  }

  file { '/var/log/puppet-validator':
    ensure => file,
    owner  => 'nobody',
    group  => 'nobody',
    mode   => '0644',
    notify => Class['apache'],
  }

  # The bindir is to avoid binary collisions with PE. This must be installed
  # prior to the validator gem, because otherwise it will be installed as a
  # dependency and hit the /usr/local/bin/puppet symlink
  if $versions {
    $_versions = $versions.sort.reverse.join(', ')
    $_packages = $versions.map |$version| {
      "puppet:${version}"
    }.join(' ')

    # if the puppet gem is ever installed or updated manually, this will likely break
    exec { "gem install ${_packages} --bindir /tmp --no-document":
      path     => '/usr/local/bin:/usr/bin:/bin:/opt/puppetlabs/bin',
      unless   => "[[ \"$(gem list ^puppet$ | tail -1)\" == \"puppet (${_versions})\" ]]",
      provider => shell,
      before   => Package['puppet-validator'],
    }
  }
  else {
    package { ['puppet', 'facter']:
      ensure          => present,
      provider        => gem,
      install_options => { '--bindir' => '/tmp' },
      before          => Package['puppet-validator'],
    }
  }

}
