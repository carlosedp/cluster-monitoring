local utils = import '../utils.libsonnet';
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    grafanaDashboards+:: {
      'nginx-dashboard.json': (import '../grafana-dashboards/nginx-dashboard.json'),
    },
  },

  nginxExporter+:: {
    serviceMonitor:
      utils.newServiceMonitor('nginx', $._config.namespace, { 'app.kubernetes.io/name': 'ingress-nginx' }, 'ingress-nginx', 'prometheus', 'http'),

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;
      local nginxPort = servicePort.newNamed('prometheus', 10254, 10254);

      service.new('ingress-nginx-metrics', {'app.kubernetes.io/name': 'ingress-nginx'}, nginxPort) +
      service.mixin.metadata.withNamespace('ingress-nginx') +
      service.mixin.metadata.withLabels({'app.kubernetes.io/name': 'ingress-nginx'}) +
      service.mixin.spec.withClusterIp('None'),

    clusterRole:
      utils.newClusterRole('nginx-exporter', [
        {
          apis: [''],
          res: ['services', 'endpoints', 'pods'],
          verbs: ['get', 'list', 'watch'],
        },
      ], null),


    serviceAccount:
      utils.newServiceAccount('nginx-exporter', $._config.namespace, null),


    clusterRoleBinding:
      utils.newClusterRoleBinding('nginx-exporter', 'nginx-exporter', $._config.namespace, 'nginx-exporter', null),

  },
}
