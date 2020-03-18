local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local utils = import 'utils.libsonnet';
local vars = import 'vars.jsonnet';

{
  prometheus+:: {
    kubeControllerManagerPrometheusDiscoveryEndpoints:
      utils.newEndpoint('kube-controller-manager-prometheus-discovery', 'kube-system', vars.k3s.master_ip, 'http-metrics', 10252),

    kubeSchedulerPrometheusDiscoveryEndpoints:
      utils.newEndpoint('kube-scheduler-prometheus-discovery', 'kube-system', vars.k3s.master_ip, 'http-metrics', 10251),
  },

  // Temporary workaround until merge of https://github.com/coreos/kube-prometheus/pull/456
  kubeStateMetrics+:: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers:
              std.map(
                function(c)
                  if std.startsWith(c.name, 'kube-state-metrics') then
                    c {
                      image: $._config.imageRepos.kubeStateMetrics + ':' + $._config.versions.kubeStateMetrics,
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
}
