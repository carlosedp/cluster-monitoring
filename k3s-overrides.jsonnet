local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local vars = import 'vars.jsonnet';

{
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
            targetPort: '8080'
          },
          {
            name: 'http-self',
            port: 8081,
            targetPort: '8081'
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
              scheme: 'https',
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