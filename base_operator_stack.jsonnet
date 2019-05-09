local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local vars = import 'vars.jsonnet';

{
  _config+:: {
    namespace: 'monitoring',

    urls+:: {
      prom_ingress: 'prometheus.' + vars.suffixDomain,
      alert_ingress: 'alertmanager.' + vars.suffixDomain,
      grafana_ingress: 'grafana.' + vars.suffixDomain,
      grafana_ingress_external: 'grafana.' + vars.suffixDomain,
    },

    prometheus+:: {
      names: 'k8s',
      replicas: 1,
      namespaces: ['default', 'kube-system', 'monitoring'],
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

    // Add custom Grafana dashboards
    grafanaDashboards+:: {
      'kubernetes-cluster-dashboard.json': (import 'grafana-dashboards/kubernetes-cluster-dashboard.json'),
      'prometheus-dashboard.json': (import 'grafana-dashboards/prometheus-dashboard.json'),
      'coredns-dashboard.json': (import 'grafana-dashboards/coredns-dashboard.json'),
    },

    grafana+:: {
      config: {
        sections: {
          session: { provider: 'memory' },
          'auth.basic': { enabled: false },
          'auth.anonymous': { enabled: false },
          smtp: {
            enabled: true,
            host: 'smtp-server.monitoring.svc:25',
            user: '',
            password: '',
            from_address: vars.grafana.from_address,
            from_name: 'Grafana Alert',
            skip_verify: true,
          },
        },
      },
    },
  },
  //---------------------------------------
  // End of _config
  //---------------------------------------

  prometheus+:: {
    # Add option (from vars.yaml) to enable persistence
    local pvc = k.core.v1.persistentVolumeClaim,
    prometheus+: {
      spec+: {
               retention: '15d',
               externalUrl: 'http://' + $._config.urls.prom_ingress,
             }
             + (if vars.enablePersistence.prometheus then {
                  storage: {
                    volumeClaimTemplate:
                      pvc.new() +
                      pvc.mixin.spec.withAccessModes('ReadWriteOnce') +
                      pvc.mixin.spec.resources.withRequests({ storage: '20Gi' }),
                    // Uncomment below to define a StorageClass name
                    //+ pvc.mixin.spec.withStorageClassName('nfs-master-ssd'),
                  },
                } else {}),
    },
  },

  // Override deployment for Grafana data persistence
  grafana+:: if vars.enablePersistence.grafana then {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            volumes:
              std.map(
                function(v)
                  if v.name == 'grafana-storage' then
                    {
                      name: 'grafana-storage',
                      persistentVolumeClaim: {
                        claimName: 'grafana-storage',
                      },
                    }
                  else v,
                super.volumes
              ),
          },
        },
      },
    },
    storage:
      local pvc = k.core.v1.persistentVolumeClaim;
      pvc.new() +
      pvc.mixin.metadata.withNamespace($._config.namespace) +
      pvc.mixin.metadata.withName('grafana-storage') +
      pvc.mixin.spec.withAccessModes('ReadWriteMany') +
      pvc.mixin.spec.resources.withRequests({ storage: '2Gi' }),
  } else {},

  grafanaDashboards+:: $._config.grafanaDashboards,

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
    grafana:
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
}
