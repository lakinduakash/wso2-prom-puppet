# Class: prometheus_install
#
#
class prometheus_install {

  $node_targets =['localhost:9100','172.31.9.138:9100']
  $jmx_node_targets =['172.31.9.138:8082']

  info('prom_master:')
  info($facts['prom_master'])

  notify {"facts prom_master ${facts['prom_master']}":}

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
              {
                'alert'       => 'HighLoad',
                'expr'        => 'node_load1 > 0.8',
                'for'         => '5m',
                'labels'      => {
                  'severity' => 'page',
                },
                'annotations' => {
                  'summary'     => 'Instance {{ $labels.instance }} have high load',
                  'description' => '{{ $labels.instance }} of job {{ $labels.job }} has load more than 0.8'
                }
              },

              {
                'alert'       => 'DiskFull',
                'expr'        => '(1 - (node_filesystem_free_bytes{fstype="ext4",mountpoint="/"} / node_filesystem_size_bytes{fstype="ext4",mountpoint="/"})) > 0.9',
                'for'         => '1m',
                'labels'      => {
                  'severity' => 'page',
                },
                'annotations' => {
                  'summary'     => 'Instance {{ $labels.instance }} disk is full',
                  'description' => '{{ $labels.instance }} of job {{ $labels.job }} has disk usage over 0.9'
                }
              },
              {
                'alert'       => 'HeapMemory Exceeded',
                'expr'        => 'jvm_memory_bytes_used > 10000',
                'for'         => '1m',
                'labels'      => {
                  'severity' => 'page',
                },
                'annotations' => {
                  'summary'     => 'Instance {{ $labels.instance }} Heap memory usage is exceeded',
                  'description' => '{{ $labels.instance }} of job {{ $labels.job }} has high heap memeory usage'
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
        {
          'job_name'        => 'jmx_node',
          'scrape_interval' => '10s',
          'scrape_timeout'  => '10s',
          'static_configs'  => [
            {
              'targets' => $jmx_node_targets,
              'labels'  => {'alias' => 'Jmx_Node'}
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
        'receiver'        => 'pagerDuty',
      },
      receivers => [
        {
          'name'             => 'pagerDuty',
          'pagerduty_config' => [
            {
              'service_key' => '63332f625ffa4d72abda2d9067ad3be3'
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
