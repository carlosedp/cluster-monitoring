local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    replicas: 1,

    // Add custom dashboards
    grafanaDashboards+:: {
      'elasticsearch-dashboard.json': (import 'grafana-dashboards/elasticsearch-dashboard.json'),
      'fluentd-dashboard.json': (import 'grafana-dashboards/fluentd-dashboard.json'),
    },
  },

  elasticExporter+:: {
    deployment:
      local deployment = k.apps.v1beta2.deployment;
      local container = k.apps.v1beta2.deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;

      local podLabels = { 'k8s-app': 'elasticsearch-exporter' };
      local elasticExporter =
        container.new('elasticsearch-exporter',
                      $._config.imageRepos.elasticExporter + ':' + $._config.versions.elasticExporter) +
        container.withCommand([
          '/bin/elasticsearch_exporter',
          '-es.uri=http://elasticsearch.logging.svc:9200',
          '-es.timeout=60s',
          '-es.all=true',
        ]) +
        container.withPorts(containerPort.newNamed('es-metrics', 9108)) +
        container.mixin.securityContext.capabilities.withDrop(['SETPCAP', 'MKNOD', 'AUDIT_WRITE', 'CHOWN', 'NET_RAW', 'DAC_OVERRIDE', 'FOWNER', 'FSETID', 'KILL', 'SETGID', 'SETUID', 'NET_BIND_SERVICE', 'SYS_CHROOT', 'SETFCAP']) +
        container.mixin.securityContext.withRunAsNonRoot(true) +
        container.mixin.securityContext.withRunAsUser(1000) +
        container.mixin.securityContext.withReadOnlyRootFilesystem(true) +
        container.mixin.resources.withRequests({ memory: '64Mi', cpu: '25m' }) +
        container.mixin.resources.withLimits({ memory: '128Mi', cpu: '100m' }) +
        container.mixin.livenessProbe.httpGet.withPath('/health') +
        container.mixin.livenessProbe.httpGet.withPort(9108) +
        container.mixin.livenessProbe.withInitialDelaySeconds(30) +
        container.mixin.livenessProbe.withTimeoutSeconds(10) +

        container.mixin.readinessProbe.httpGet.withPath('/health') +
        container.mixin.readinessProbe.httpGet.withPort(9108) +
        container.mixin.readinessProbe.withInitialDelaySeconds(30) +
        container.mixin.readinessProbe.withTimeoutSeconds(10);

      local c = [elasticExporter];

      deployment.new('elasticsearch-exporter', $._config.replicas, c, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.strategy.withType('RollingUpdate') +
      deployment.mixin.spec.strategy.rollingUpdate.withMaxSurge(1) +
      deployment.mixin.spec.strategy.rollingUpdate.withMaxUnavailable(0) +
      deployment.mixin.spec.template.spec.withRestartPolicy('Always'),

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;
      local elasticExporterPorts = servicePort.newNamed('es-metrics', 9108, 'es-metrics');

      service.new('elasticsearch-exporter', $.elasticExporter.deployment.spec.selector.matchLabels, elasticExporterPorts) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ 'k8s-app': 'elasticsearch-exporter' }),

    serviceMonitorElastic:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'elasticsearch-exporter',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'elasticsearch-exporter',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          selector: {
            matchLabels: {
              'k8s-app': 'elasticsearch-exporter',
            },
          },
          endpoints: [
            {
              port: 'es-metrics',
              scheme: 'http',
              interval: '30s',
            },
          ],
          namespaceSelector: {
            matchNames: [
              'monitoring',
            ],
          },
        },
      },
    serviceMonitorFluentd:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'fluentd-es',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'fluentd-es',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          selector: {
            matchLabels: {
              'k8s-app': 'fluentd-es',
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
              'logging',
            ],
          },
        },
      },
  },
} + (import 'elasticsearch_rules.jsonnet')
