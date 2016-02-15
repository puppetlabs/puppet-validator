class puppet_validator (
  $vhostname   = $::fqdn,
  $port        = '80',
  $path        = '/var/www/puppet-validator',
  $versions    = undef,
  $rubyversion = 'ruby-1.9.3-p551',
) {
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

  file { $path:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/puppet_validator/docroot',
    recurse => true,
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

  # this is in an unreleased version of puppetlabs/apache. It should be removed soon.
  if $::osfamily == 'RedHat' and ! defined(Yumrepo['passenger'])  {
    yumrepo { 'passenger':
      ensure        => 'present',
      baseurl       => 'https://oss-binaries.phusionpassenger.com/yum/passenger/el/$releasever/$basearch',
      descr         => 'passenger',
      enabled       => '1',
      gpgcheck      => '0',
      gpgkey        => 'https://packagecloud.io/gpg.key',
      repo_gpgcheck => '1',
      sslcacert     => '/etc/pki/tls/certs/ca-bundle.crt',
      sslverify     => '1',
      before        => Apache::Mod['passenger'],
    }
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