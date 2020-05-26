local utils = import '../utils.libsonnet';
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    // Add custom dashboards
    grafanaDashboards+:: {
      'traefik-dashboard.json': (import '../grafana-dashboards/traefik-dashboard.json'),
    },
  },

  traefikExporter+:: {
    serviceMonitor:
      utils.newServiceMonitor('traefik', $._config.namespace, { app: 'traefik' }, 'kube-system', 'metrics', 'http'),
  },
}
