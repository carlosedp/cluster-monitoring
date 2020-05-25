local utils = import '../utils.libsonnet';
local vars = import '../vars.jsonnet';
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  prometheus+:: {
    kubeControllerManagerPrometheusDiscoveryEndpoints:
      utils.newEndpoint('kube-controller-manager-prometheus-discovery', 'kube-system', vars.k3s.master_ip, 'http-metrics', 10252),

    kubeSchedulerPrometheusDiscoveryEndpoints:
      utils.newEndpoint('kube-scheduler-prometheus-discovery', 'kube-system', vars.k3s.master_ip, 'http-metrics', 10251),
  },
}
