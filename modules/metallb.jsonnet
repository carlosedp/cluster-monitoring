local utils = import '../utils.libsonnet';
local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',

    prometheus+:: {
      namespaces+:: ['metallb-system'],
    },

  },

  metallbExporter+:: {
    serviceMonitor:
      utils.newServiceMonitor('metallb', $._config.namespace, { 'k8s-app': 'metallb-controller' }, 'metallb-system', 'http', 'http'),

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;
      local metallbPort = servicePort.newNamed('http', 7472, 7472);

      service.new('metallb-controller', { app: 'metallb', component: 'controller' }, metallbPort) +
      service.mixin.metadata.withNamespace('metallb-system') +
      service.mixin.metadata.withLabels({ 'k8s-app': 'metallb-controller' }) +
      service.mixin.spec.withClusterIp('None'),

    clusterRole:
      utils.newClusterRole('metallb-exporter', [
        {
          apis: [''],
          res: ['services', 'endpoints', 'pods'],
          verbs: ['get', 'list', 'watch'],
        },
      ], null),


    clusterRoleBinding:
      utils.newClusterRoleBinding('metallb-exporter', 'prometheus-k8s', $._config.namespace, 'metallb-exporter', null),


  },
}
