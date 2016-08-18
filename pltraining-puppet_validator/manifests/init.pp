class puppet_validator (
  $vhostname   = $::fqdn,
  $port        = '80',
  $path        = '/var/www/puppet-validator',
  $versions    = undef,
  $rubyversion = 'ruby-1.9.3-p551',
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
  }

  # lollercopter. This is to avoid binary collisions with PE
  package { ['puppet', 'facter']:
    ensure          => present,
    provider        => gem,
    install_options => { '--bindir' => '/tmp' },
    before          => Package['puppet-validator'],
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

  if $versions {
    include rvm
    rvm::system_user { 'nobody': }

    rvm_system_ruby { $rubyversion:
      ensure      => 'present',
      default_use => false,
    }

    $versions.each |$version| {
      rvm_gemset { "${rubyversion}@puppet${version}":
        ensure  => present,
        require => Rvm_system_ruby[$rubyversion];
      }

      rvm_gem { "${rubyversion}@puppet${version}/puppet":
        ensure  => $version,
        require => Rvm_gemset["${rubyversion}@puppet${version}"],
      }

      rvm_gem { "${rubyversion}@puppet${version}/puppet-validator":
        ensure  => present,
        require => Rvm_gemset["${rubyversion}@puppet${version}"],
      }

      # This symlink allows the Apache alias to work, and it's also the
      # trigger that populates the version dropdown in the UI.
      file { "${path}/${version}":
        ensure => link,
        target => '.',
      }

      # This is way tightly coupled, but I didn't see a better way.
      # It creates a concat fragment targeted to be inserted into the vhost conf.
      concat::fragment { "${vhostname}-puppet-validator-${version}":
        target  => "25-${vhostname}.conf",
        order   => 175,
        content => template('puppet_validator/apache_vhost_puppet_validator.erb'),
      }
    }
  }

}
