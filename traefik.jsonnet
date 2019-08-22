local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    // Add custom dashboards
    grafanaDashboards+:: {
      'traefik-dashboard.json': (import 'grafana-dashboards/traefik-dashboard.json'),
    },
  },

  traefikExporter+:: {
    serviceMonitor:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'traefik',
          namespace: $._config.namespace,
          labels: {
            'app': 'traefik',
          },
        },
        spec: {
          jobLabel: 'traefik-exporter',
          selector: {
            matchLabels: {
              'app': 'traefik',
            },
          },
          endpoints: [
            {
              port: 'metrics',
              scheme: 'http',
              interval: '30s',
            },
          ],
          namespaceSelector: {
            matchNames: [
              'kube-system',
            ],
          },
        },
      },
  },
}
