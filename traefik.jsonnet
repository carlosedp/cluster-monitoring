local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

local kp = (import 'kube-prometheus/kube-prometheus.libsonnet') + {
  _config+:: {
    namespace: 'monitoring',
  },

  traefik+:: {
    serviceMonitor:
      {

        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
            name: 'traefik-ingress-lb',
            namespace: $._config.namespace,
            labels: {
                'k8s-app': 'traefik-ingress-lb',
            },
        },
        spec: {
            jobLabel: 'k8s-app',
            selector: {
              matchLabels: {
                'k8s-app': 'traefik-ingress-lb',
              },
            },
            endpoints: [
              {
                 port: 'admin',
                 scheme: 'https',
                 interval: '30s',
              },
            ],
            namespaceSelector: {
              matchNames: [
                'kube-system',
              ]
            },
        },
      },
  },
};

{ ['traefik-' + name]: kp.traefik[name] for name in std.objectFields(kp.traefik) }