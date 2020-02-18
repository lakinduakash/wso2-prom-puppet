# Class: prometheus_install
#
#
class prometheus_install {

  $node_targets =['localhost:9090']

  log('prom_master:')
  log($facts['prom_master'])

  if $facts['prom_master'] {
        class { 'prometheus::server':
      version              => '2.4.3',
      alerts               => {
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
      scrape_configs       => [
        {
          'job_name'        => 'prometheus',
          'scrape_interval' => '10s',
          'scrape_timeout'  => '10s',
          'static_configs'  => [
            {
              'targets' => ['localhost:9090'],
              'labels'  => {
                'alias' => 'Prometheus',
              }
            }
          ],
        },
        {
          'job_name'        => 'node',
          'scrape_interval' => '5s',
          'scrape_timeout'  => '5s',
          'static_configs'  => [
            {
              'targets' => $node_targets,
              'labels'  => {'alias' => 'Node'}
            },
          ],
        },
      ],
      alertmanagers_config => [
        {
          'static_configs' => [{'targets' => ['localhost:9093']}],
        },
      ],
    }

    class { 'prometheus::alertmanager':
      version   => '0.13.0',
      route     => {
        'group_by'        => ['alertname', 'cluster', 'service'],
        'group_wait'      => '30s',
        'group_interval'  => '5m',
        'repeat_interval' => '3h',
        'receiver'        => 'slack',
      },
      receivers => [
        {
          'name'          => 'slack',
          'slack_configs' => [
            {
              'api_url'       => 'https://hooks.slack.com/services/ABCDEFG123456',
              'channel'       => '#channel',
              'send_resolved' => true,
              'username'      => 'username'
            },
          ],
        },
      ],
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
      },
      provisioning_dashboards  => {
        apiVersion => 1,
        providers  => [
          {
            name            => 'default',
            orgId           => 1,
            folder          => '',
            type            => 'file',
            disableDeletion => true,
            options         => {
              path         => '/var/lib/grafana/dashboards',
              puppetsource => 'puppet:///modules/prometheus_install/dashboards',
            },
          },
        ],
      },
    }
  }

  class { 'prometheus::node_exporter':
  version            => '0.18.0',
}

}
