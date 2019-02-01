local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

local kp = (import 'kube-prometheus/kube-prometheus.libsonnet') + {
	_config+:: {
    namespace: "monitoring",

    urls+:: {
      prom_externalUrl: 'http://prometheus.internal.carlosedp.com',
      alert_externalUrl: 'http://alertmanager.internal.carlosedp.com',
      grafana_externalUrl: 'http://grafana.internal.carlosedp.com/',

      prom_ingress: 'prometheus.internal.carlosedp.com',
      alert_ingress: 'alertmanager.internal.carlosedp.com',
      grafana_ingress: 'grafana.internal.carlosedp.com',
    },

    versions+:: {
        prometheus: "v2.5.0",
        alertmanager: "v0.15.3",
        kubeStateMetrics: "v1.5.0",
        kubeRbacProxy: "v0.4.1",
        addonResizer: "2.1",
        nodeExporter: "v0.17.0",
        prometheusOperator: "v0.28.0",
        prometheusAdapter: "v0.4.1",
        grafana: "v5.4.0",
        configmapReloader: "v0.2.2",
        prometheusConfigReloader: "v0.28.0",
    },

    imageRepos+:: {
        prometheus: "carlosedp/prometheus",
        alertmanager: "carlosedp/alertmanager",
        kubeStateMetrics: "carlosedp/kube-state-metrics",
        kubeRbacProxy: "carlosedp/kube-rbac-proxy",
        addonResizer: "carlosedp/addon-resizer",
        nodeExporter: "carlosedp/node_exporter",
        prometheusOperator: "carlosedp/prometheus-operator",
        prometheusAdapter: "directxman12/k8s-prometheus-adapter-arm64",
        grafana: "carlosedp/monitoring-grafana",
        configmapReloader: "carlosedp/configmap-reload",
        prometheusConfigReloader: "carlosedp/prometheus-config-reloader",
    },

    prometheus+:: {
      names: 'k8s',
      replicas: 1,
      namespaces: ["default", "kube-system","monitoring"],
    },

    alertmanager+:: {
      name: 'main',
      config: |||
        global:
          resolve_timeout: 5m
        route:
          group_by: ['job']
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 12h
          receiver: 'null'
          routes:
          - match:
              alertname: DeadMansSwitch
            receiver: 'null'
        receivers:
        - name: 'null'
      |||,
      replicas: 1,
    // Configure External URL's
      alertmanager+: {
        spec+: {
          externalUrl: $._config.urls.alert_externalUrl,
        },
      },
    },

    kubeStateMetrics+:: {
        collectors: '',  // empty string gets a default set
        scrapeInterval: '30s',
        scrapeTimeout: '30s',

        baseCPU: '100m',
        baseMemory: '150Mi',
        cpuPerNode: '2m',
        memoryPerNode: '30Mi',
      },

    grafana+:: {
      config: {
        sections: {
          database: { path: '/data/grafana.db' },
          paths: {
            data: '/var/lib/grafana',
            logs: '/var/lib/grafana/log',
            plugins: '/var/lib/grafana/plugins',
            provisioning: '/etc/grafana/provisioning',
          },
          session: { provider: 'memory' },
          'auth.basic': {enabled: false},
          'auth.anonymous': {enabled: false},
          smtp: {
            enabled: true,
            host: 'smtp-server.monitoring.svc:25',
            user: '',
            password: '',
            from_address:'carlosedp@gmail.com',
            from_name: 'Grafana Alert',
            skip_verify: true
          },
        },
      },
    },

    //---------------------------------------
    // End of _config
    //---------------------------------------

    },
    prometheus+:: {
      local pvc = k.core.v1.persistentVolumeClaim,

      prometheus+: {
        spec+: {
          retention: '15d',
          externalUrl: $._config.urls.prom_externalUrl,
          storage: {
            volumeClaimTemplate:
              pvc.new() +
              pvc.mixin.spec.withAccessModes('ReadWriteOnce') +
              pvc.mixin.spec.resources.withRequests({ storage: '20Gi' }) +
              pvc.mixin.spec.withStorageClassName('nfs-ssd-node1'),
          },
        },
      },
    },

  # Override command for Grafana to load ini from correct path
  // grafana+:: {
  //   deployment+:
  //     {
  //       local pvc = k.core.v1.persistentVolumeClaim,
  //       spec+: {
  //         volumeClaimTemplate:
  //           pvc.new() +
  //           pvc.mixin.metadata.withNamespace($._config.namespace) +
  //           pvc.mixin.metadata.withName("grafana-storage") +
  //           pvc.mixin.spec.withAccessModes('ReadWriteMany') +
  //           pvc.mixin.spec.resources.withRequests({ storage: '2Gi' }) +
  //           pvc.mixin.spec.withStorageClassName('nfs-ssd-node1'),
  //         template+: {
  //           spec+: {
  //             containers:
  //               std.map(
  //                 function(c)
  //                   if c.name == 'grafana' then
  //                     c {
  //                       args+: [
  //                         '-config=/etc/grafana/grafana.ini',
  //                       ],
  //                     }
  //                   else
  //                     c,
  //                 super.containers,
  //               ),
  //           },
  //         },
  //       },
  //     },
  // },

  // Override command for addon-resizer due to change from parameter --threshold to --acceptance-offset
  kubeStateMetrics+:: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers:
              std.filterMap(
                function(c) c.name == 'addon-resizer',
                function(c)
                  if std.startsWith(c.name, 'addon-resizer') then
                    c {
                      command: [
                        '/pod_nanny',
                        '--container=kube-state-metrics',
                        '--cpu=' + $._config.kubeStateMetrics.baseCPU,
                        '--extra-cpu=' + $._config.kubeStateMetrics.cpuPerNode,
                        '--memory=' + $._config.kubeStateMetrics.baseMemory,
                        '--extra-memory=' + $._config.kubeStateMetrics.memoryPerNode,
                        '--acceptance-offset=5',
                        '--deployment=kube-state-metrics',
                      ],
                    },
                super.containers,
              ),
          },
        },
      },
    },
  },

  // Create ingress objects per application
  ingress+: {
    local secret = k.core.v1.secret,
    local ingress = k.extensions.v1beta1.ingress,
    local ingressTls = ingress.mixin.spec.tlsType,
    local ingressRule = ingress.mixin.spec.rulesType,
    local httpIngressPath = ingressRule.mixin.http.pathsType,

    'alertmanager-main':
      ingress.new() +
      ingress.mixin.metadata.withName('alertmanager-main') +
      ingress.mixin.metadata.withNamespace($._config.namespace) +
      // ingress.mixin.metadata.withAnnotations({
      //   'nginx.ingress.kubernetes.io/auth-type': 'basic',
      //   'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
      //   'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
      // }) +
      ingress.mixin.spec.withRules(
        ingressRule.new() +
        ingressRule.withHost($._config.urls.alert_ingress) +
        ingressRule.mixin.http.withPaths(
          httpIngressPath.new() +
          httpIngressPath.withPath('/') +
          httpIngressPath.mixin.backend.withServiceName('alertmanager-main') +
          httpIngressPath.mixin.backend.withServicePort('web')
        ),
      ),
    'grafana':
      ingress.new() +
      ingress.mixin.metadata.withName('grafana') +
      ingress.mixin.metadata.withNamespace($._config.namespace) +
      // ingress.mixin.metadata.withAnnotations({
      //   'nginx.ingress.kubernetes.io/auth-type': 'basic',
      //   'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
      //   'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
      // }) +
      ingress.mixin.spec.withRules(
        ingressRule.new() +
        ingressRule.withHost($._config.urls.grafana_ingress) +
        ingressRule.mixin.http.withPaths(
          httpIngressPath.new() +
          httpIngressPath.withPath('/') +
          httpIngressPath.mixin.backend.withServiceName('grafana') +
          httpIngressPath.mixin.backend.withServicePort('http')
        ),
      ),
    'prometheus-k8s':
      ingress.new() +
      ingress.mixin.metadata.withName('prometheus-k8s') +
      ingress.mixin.metadata.withNamespace($._config.namespace) +
      // ingress.mixin.metadata.withAnnotations({
      //   'nginx.ingress.kubernetes.io/auth-type': 'basic',
      //   'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
      //   'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
      // }) +
      ingress.mixin.spec.withRules(
        ingressRule.new() +
        ingressRule.withHost($._config.urls.prom_ingress) +
        ingressRule.mixin.http.withPaths(
          httpIngressPath.new() +
          httpIngressPath.withPath('/') +
          httpIngressPath.mixin.backend.withServiceName('prometheus-k8s') +
          httpIngressPath.mixin.backend.withServicePort('web')
        ),
      ),
    },
  };
  // + {
    // Create basic auth secret - replace 'auth' file with your own
    // Create with htpasswd -c auth [USERNAME]
//     ingress+:: {
//       'basic-auth-secret':
//         secret.new('basic-auth', { auth: std.base64(importstr 'auth') }) +
//         secret.mixin.metadata.withNamespace($._config.namespace),
//     },
// };

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['ingress-' + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }