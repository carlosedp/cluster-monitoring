local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local vars = import 'vars.jsonnet';
local utils = import 'utils.libsonnet';

{
  prometheus+:: {
    kubeControllerManagerPrometheusDiscoveryEndpoints:
      utils.newEndpoint('kube-controller-manager-prometheus-discovery', 'kube-system', vars.k3s.master_ip, 'http-metrics', 10252),

    kubeSchedulerPrometheusDiscoveryEndpoints:
      utils.newEndpoint('kube-scheduler-prometheus-discovery', 'kube-system', vars.k3s.master_ip, 'http-metrics', 10251),

    serviceMonitorKubelet+:
      {
        spec+: {
          endpoints: [
            {
              port: 'https-metrics',
              scheme: 'https',
              interval: '30s',
              honorLabels: true,
              tlsConfig: {
                insecureSkipVerify: true,
              },
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            },
            {
              port: 'https-metrics',
              scheme: 'https',
              path: '/metrics/cadvisor',
              interval: '30s',
              honorLabels: true,
              tlsConfig: {
                insecureSkipVerify: true,
              },
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
              metricRelabelings: [
                // Drop a bunch of metrics which are disabled but still sent, see
                // https://github.com/google/cadvisor/issues/1925.
                {
                  sourceLabels: ['__name__'],
                  regex: 'container_(network_tcp_usage_total|network_udp_usage_total|tasks_state|cpu_load_average_10s)',
                  action: 'drop',
                },
              ],
            },
          ],
        },
      },
  },

  nodeExporter+:: {
    daemonset+: {
      spec+: {
        template+: {
          spec+: {
            containers:
              std.filterMap(
                function(c) std.startsWith(c.name, 'kube-rbac') != true,
                function(c)
                  if std.startsWith(c.name, 'node-exporter') then
                    c {
                      args: [
                        '--web.listen-address=:' + $._config.nodeExporter.port,
                        '--path.procfs=/host/proc',
                        '--path.sysfs=/host/sys',
                        '--path.rootfs=/host/root',
                        // The following settings have been taken from
                        // https://github.com/prometheus/node_exporter/blob/0662673/collector/filesystem_linux.go#L30-L31
                        // Once node exporter is being released with those settings, this can be removed.
                        '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+)($|/)',
                        '--collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|cgroup|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|sysfs|tracefs)$',
                      ],
                      ports: [
                        {
                          containerPort: 9100,
                          name: 'http'
                        }],

                    }
                  else
                    c,
                super.containers,
              ),
          },
        },
      },
    },

    service+:
      {
        spec+: {
          ports: [{
            name: 'http',
            port: 9100,
            targetPort: 'http'
          }]
        }
      },

    serviceMonitor+:
      {
        spec+: {
          endpoints: [
            {
              port: 'http',
              scheme: 'http',
              interval: '30s',
              relabelings: [
                {
                  action: 'replace',
                  regex: '(.*)',
                  replacment: '$1',
                  sourceLabels: ['__meta_kubernetes_pod_node_name'],
                  targetLabel: 'instance',
                },
              ],
            },
          ],
        },
      },
  },


  kubeStateMetrics+:: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers:
              std.filterMap(
                function(c) std.startsWith(c.name, 'kube-rbac') != true,
                function(c)
                  if std.startsWith(c.name, 'kube-state-metrics') then
                    c {
                      args: [
                        '--port=8080',
                        '--telemetry-port=8081',
                      ],
                      ports: [
                        {
                          containerPort: 8080,
                          name: 'http-main'
                        },
                        {
                          containerPort: 8081,
                          name: 'http-self'
                        }],
                    }
                  else
                    c,
                super.containers,
              ),
          },
        },
      },
    },

    service+:
      {
        spec+: {
          ports: [{
            name: 'http-main',
            port: 8080,
            targetPort: 'http-main'
          },
          {
            name: 'http-self',
            port: 8081,
            targetPort: 'http-self'
          }]
        }
      },

    serviceMonitor+:
      {
        spec+: {
          endpoints: [
            {
              port: 'http-main',
              scheme: 'http',
              interval: $._config.kubeStateMetrics.scrapeInterval,
              scrapeTimeout: $._config.kubeStateMetrics.scrapeTimeout,
              honorLabels: true,
              tlsConfig: {
                insecureSkipVerify: true,
              },
            },
            {
              port: 'http-self',
              scheme: 'http',
              interval: '30s',
              tlsConfig: {
                insecureSkipVerify: true,
              },
            },
          ],
        },
      },
  },

}