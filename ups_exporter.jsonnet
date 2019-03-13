local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

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
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'ups-exporter',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'ups-exporter',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          selector: {
            matchLabels: {
              'k8s-app': 'ups-exporter',
            },
          },
          endpoints: [
            {
              port: 'metrics',
              scheme: 'http',
              interval: '30s',
            },
          ],
        },
      },

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      local upsExporterPort = servicePort.newNamed('metrics', 9099, 9099);

      service.new('ups-exporter', null, upsExporterPort) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ 'k8s-app': 'ups-exporter' }) +
      service.mixin.spec.withClusterIp('None'),

    endpoints:
      local endpoints = k.core.v1.endpoints;
      local endpointSubset = endpoints.subsetsType;
      local endpointPort = endpointSubset.portsType;

      local upsPort = endpointPort.new() +
                      endpointPort.withName('metrics') +
                      endpointPort.withPort(9099) +
                      endpointPort.withProtocol('TCP');

      local subset = endpointSubset.new() +
                     endpointSubset.withAddresses([
                       { ip: IP }
                       for IP in $._config.ups.ips
                     ]) +
                     endpointSubset.withPorts(upsPort);

      endpoints.new() +
      endpoints.mixin.metadata.withName('ups-exporter') +
      endpoints.mixin.metadata.withNamespace($._config.namespace) +
      endpoints.mixin.metadata.withLabels({ 'k8s-app': 'ups-exporter' }) +
      endpoints.withSubsets(subset),
  },
}
