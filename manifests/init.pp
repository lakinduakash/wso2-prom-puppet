# Class: prometheus_install
#
#
class prometheus_install {

  class { 'prometheus::server':
  version        => '2.4.3',
  alerts         => {
    'groups' => [
      {
        'name'  => 'alert.rules',
        'rules' => [
          {
            'alert'       => 'InstanceDown',
            'expr'        => 'up == 0',
            'for'         => '5m',
            'labels'      => {
              'severity' => 'page',
            },
            'annotations' => {
              'summary'     => 'Instance {{ $labels.instance }} down',
              'description' => '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
            }
          },
        ],
      },
    ],
  },
  scrape_configs => [
    {
      'job_name'        => 'prometheus',
      'scrape_interval' => '10s',
      'scrape_timeout'  => '10s',
      'static_configs'  => [
        {
          'targets' => [ 'localhost:9090' ],
          'labels'  => {
            'alias' => 'Prometheus',
          }
        }
      ],
    },
  ],
}

class { 'prometheus::node_exporter':
  version            => '0.12.0',
}

class { '::mysql::server':
  root_password           => 'root@123',
  remove_default_accounts => true,
  restart                 => true,
}

mysql::db { 'grafana':
  user     => 'root',
  password => 'root@123',
  host     => 'localhost',
}

class { 'grafana':
  cfg                      => {
    app_mode => 'production',
    server   => {
      http_port     => 8080,
    },
    database => {
      type     => 'mysql',
      host     => '127.0.0.1:3306',
      name     => 'grafana',
      user     => 'root',
      password => 'root@123',
    },
    users    => {
      allow_sign_up => true,
    },
  },
  provisioning_datasources => {
    apiVersion  => 1,
    datasources => [
      {
        name      => 'Prometheus',
        type      => 'prometheus',
        access    => 'proxy',
        url       => 'http://localhost:9090',
        isDefault => true,
      },
    ],
  }
}

}
