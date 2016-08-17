node "vm-rec-prod-app.kainos.com" {

  include nginx
  include firewall

  class { 'postgresql::globals':
    manage_package_repo => true,
    version             => '9.5',
  }

  class { 'postgresql::server':
    listen_addresses  => 'localhost',
    require           => Class['postgresql::globals'],
  }

  postgresql::server::db { 'tdprecruitment':
     user     => 'tdp',
     password => postgresql_password('tdp', 'tdp'),
  }

  nginx::resource::upstream { 'rec':
    members => [
      'localhost:8888',
    ],
  }

  nginx::resource::vhost { 'recruitment-helper.kainos.com':
    proxy            => 'http://rec',
    proxy_set_header => ['Host $host:$server_port', 'X-Real-IP $remote_addr', 'X-Forwarded-For $proxy_add_x_forwarded_for', 'X-Forwarded-Proto $scheme'],

  }
  resources { 'firewall':
    purge => true,
  }
  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  }
  firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }
  firewall { '002 reject local traffic not on loopback interface':
    iniface     => '! lo',
    proto       => 'all',
    destination => '127.0.0.1/8',
    action      => 'reject',
  }
  firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  }
}
  if $::virtual == 'virtualbox' {
  notice('Detected vagarnt instance - opening All trafic')
    firewall { '998 allow all trafic for vagrant':
      proto  => 'all',
      action => 'accept',
      source => '0.0.0.0/0',
    }
  }
  firewall { '999 drop all':
    proto  => 'all',
    action => 'drop',
  }
  firewall { '050 accept SSH traffic':
    proto  => 'all',
    dport  => 22,
    action => 'accept',
  }
  firewall { '051 accept HTTP traffic':
    proto  => 'all',
    dport  => 22,
    action => 'accept',
  }


node "tdp-jenkins.kainos.com" {
  include epel
  include nginx


  $dependencies = [ 'git', 'rubygems', 'gcc', 'ruby-devel', 'rpm-build']
  $dependencies.each |$dependency| {
    package {$dependency:
      ensure => latest,
    }
  }

  package {'bundler':
    ensure   => installed,
    provider => 'gem',
    require  => Package['rubygems'],
  }

  package {'ansible':
    ensure  => installed,
    require => Class['epel']
  }

  class {'yum_repo':
    require => Class['nginx'],
  }

  nginx::resource::upstream {'jenkins':
    members => ['127.0.0.1:8080'],
  }

  nginx::resource::vhost {'172.16.253.52':
    use_default_location => false,
  }

  nginx::resource::location {'jenkins':
    location              => '/',
    vhost                 => '172.16.253.52',
    proxy                 => 'http://jenkins',
    proxy_connect_timeout => '10s',
    proxy_read_timeout    => '10s',
    proxy_set_header      => ['Host $host:$server_port', 'X-Real-IP $remote_addr', 'X-Forwarded-For $proxy_add_x_forwarded_for', 'X-Forwarded-Proto $scheme'],
  }

  nginx::resource::location {'local':
    location  => '/yum',
    vhost     => '172.16.253.52',
    www_root  => '/var/www/',
    autoindex => 'on',
  }

  if ($::selinux) {
    selboolean {'httpd_can_network_connect':
      persistent => true,
      value      => 'on',
    }
  }
}
