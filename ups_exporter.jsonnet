local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local utils = import 'utils.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',

    ups: {
      ips: ['192.168.1.62'],
    },

    // Add custom dashboards
    grafanaDashboards+:: {
      'apc-ups-dashboard.json': (import 'grafana-dashboards/apc-ups-dashboard.json'),
    },
  },

  upsExporter+:: {
    serviceMonitor:
      utils.newServiceMonitor('ups-exporter', $._config.namespace, {'k8s-app': 'ups-exporter'}, $._config.namespace, 'metrics', 'http'),

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      local upsExporterPort = servicePort.newNamed('metrics', 9099, 9099);

      service.new('ups-exporter', null, upsExporterPort) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ 'k8s-app': 'ups-exporter' }) +
      service.mixin.spec.withClusterIp('None'),

    endpoints:
      utils.newEndpoint('ups-exporter', $._config.namespace, $._config.ups.ips, 'metrics', 9099),
  },
}
