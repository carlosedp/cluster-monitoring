local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

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
          name: 'traefik-ingress-lb',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'traefik-ingress-lb',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          selector: {
            matchLabels: {
              'k8s-app': 'traefik-ingress-lb',
            },
          },
          endpoints: [
            {
              port: 'admin',
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
