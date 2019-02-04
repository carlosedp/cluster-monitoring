local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

local kp = (import 'kube-prometheus/kube-prometheus.libsonnet') +
           (import 'kube-prometheus/kube-prometheus-anti-affinity.libsonnet') +
           (import 'kube-prometheus/kube-prometheus-kops-coredns.libsonnet') +
           (import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet') +
           (import 'image_sources_versions.jsonnet') +
    {
	_config+:: {
        namespace: "monitoring",

        urls+:: {
            prom_ingress: 'prometheus.internal.carlosedp.com',
            alert_ingress: 'alertmanager.internal.carlosedp.com',
            grafana_ingress: 'grafana.internal.carlosedp.com',
            grafana_ingress_external: 'grafana.cloud.carlosedp.com',
        },

        prometheus+:: {
            names: 'k8s',
            replicas: 1,
            namespaces: ["default", "kube-system", "monitoring", "logging", "metallb-system"],
        },

        alertmanager+:: {
            replicas: 1,
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
            //   database: { path: '/data/grafana.db' },
            //   paths: {
            //     data: '/var/lib/grafana',
            //     logs: '/var/lib/grafana/log',
            //     plugins: '/var/lib/grafana/plugins',
            //     provisioning: '/etc/grafana/provisioning',
            //   },
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
    },
    //---------------------------------------
    // End of _config
    //---------------------------------------

    prometheus+:: {
        local pvc = k.core.v1.persistentVolumeClaim,
        prometheus+: {
            spec+: {
                retention: '15d',
                externalUrl: 'http://' + $._config.urls.prom_ingress,
                storage: {
                volumeClaimTemplate:
                    pvc.new() +
                    pvc.mixin.spec.withAccessModes('ReadWriteOnce') +
                    pvc.mixin.spec.resources.withRequests({ storage: '20Gi' })
                    # Uncomment below to define a StorageClass name
                    #+ pvc.mixin.spec.withStorageClassName('nfs-master-ssd'),
                },
            },
        },
    },

  # Override deployment for Grafana data persistence
    grafana+:: {
        deployment+: {
            spec+: {
            template+: {
                spec+: {
                volumes:
                    std.map(
                        function(v)
                            if v.name == 'grafana-storage' then
                            {'name':'grafana-storage',
                                'persistentVolumeClaim': {
                                    'claimName': 'grafana-storage'}
                            }
                            else
                                v,
                    super.volumes
                    ),
                },
            },
            },
        },
        storage:
            local pvc = k.core.v1.persistentVolumeClaim;
            pvc.new() + pvc.mixin.metadata.withNamespace($._config.namespace) +
                        pvc.mixin.metadata.withName("grafana-storage") +
                        pvc.mixin.spec.withAccessModes('ReadWriteMany') +
                        pvc.mixin.spec.resources.withRequests({ storage: '2Gi' }),
    },

    // Add custom dashboards
    grafanaDashboards+:: {
        'kubernetes-cluster-dashboard.json': (import 'grafana-dashboards/kubernetes-cluster-dashboard.json'),
        'prometheus-dashboard.json': (import 'grafana-dashboards/prometheus-dashboard.json'),
        'traefik-dashboard.json': (import 'grafana-dashboards/traefik-dashboard.json'),
    },
    kubeStateMetrics+:: {
    // Override command for addon-resizer due to change from parameter --threshold to --acceptance-offset
        deployment+: {
            spec+: {
                template+: {
                    spec+: {
                    containers:
                        std.map(
                        function(c)
                            if std.startsWith(c.name, 'addon-resizer') then
                            c {
                                command: [
                                    '/pod_nanny',
                                    '--container=kube-state-metrics',
                                    '--cpu=100m',
                                    '--extra-cpu=2m',
                                    '--memory=150Mi',
                                    '--extra-memory=30Mi',
                                    '--acceptance-offset=5',
                                    '--deployment=kube-state-metrics',
                                ],
                            }
                            else
                            c,
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
        // // Example external ingress with authentication
        // 'grafana-external':
        //     ingress.new() +
        //     ingress.mixin.metadata.withName('grafana-external') +
        //     ingress.mixin.metadata.withNamespace($._config.namespace) +
        //     ingress.mixin.metadata.withLabels({'traffic-type': 'external'}) +
        //     ingress.mixin.metadata.withAnnotations({
        //       'ingress.kubernetes.io/auth-type': 'basic',
        //       'ingress.kubernetes.io/auth-secret': 'basic-auth',
        //     }) +
        //     ingress.mixin.spec.withRules(
        //         ingressRule.new() +
        //         ingressRule.withHost($._config.urls.grafana_ingress_external) +
        //         ingressRule.mixin.http.withPaths(
        //             httpIngressPath.new() +
        //             httpIngressPath.withPath('/') +
        //             httpIngressPath.mixin.backend.withServiceName('grafana') +
        //             httpIngressPath.mixin.backend.withServicePort('http')
        //         ),
        //     ),
        // 'basic-auth-secret':
        //     // First generate the auth secret with gen_auth.sh script
        //     secret.new('basic-auth', { auth: std.base64(importstr 'auth') }) +
        //     secret.mixin.metadata.withNamespace($._config.namespace),
        },
    };

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['ingress-' + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }