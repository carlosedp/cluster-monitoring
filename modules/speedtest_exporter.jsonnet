local utils = import '../utils.libsonnet';
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    replicas: 1,

    imageRepos+:: {
      speedtestExporter: 'ghcr.io/miguelndecarvalho/speedtest-exporter',  
    },

    // Add custom dashboards
    grafanaDashboards+:: {
      'speedtest-exporter-dashboard.json': (import '../grafana-dashboards/speedtest-exporter-dashboard.json'),
    },
  },

  speedtestExporter+:: {
    deployment:
      local deployment = k.apps.v1.deployment;
      local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;

      local podLabels = { 'k8s-app': 'speedtest-exporter' };
      local speedtestExporter =
        container.new('speedtest-exporter',
                      $._config.imageRepos.speedtestExporter) +
        container.withPorts(containerPort.newNamed(9798, 'metrics'));

      local c = [speedtestExporter];

      deployment.new('speedtest-exporter', $._config.replicas, c, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.withRestartPolicy('Always'),

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;
      local speedtestExporterPorts = servicePort.newNamed('metrics', 9798, 'metrics');

      service.new('speedtest-exporter', $.speedtestExporter.deployment.spec.selector.matchLabels, speedtestExporterPorts) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ 'k8s-app': 'speedtest-exporter' }),

    serviceMonitor:
      utils.newServiceMonitor('speedtest-exporter', $._config.namespace, { 'k8s-app': 'speedtest-exporter' }, $._config.namespace, 'metrics', 'http', 'metrics', '30m', '2m'),
  },
}
