local utils = import 'utils.libsonnet';
local vars = import 'vars.jsonnet';

local kp = (import 'kube-prometheus/kube-prometheus.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-anti-affinity.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-kops-coredns.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet')
           // Additional modules are loaded dynamically from vars.jsonnet
           + utils.join_objects([module.file for module in vars.modules if module.enabled])
           // Load K3s customized modules
           + utils.join_objects([m for m in [import 'modules/k3s-overrides.jsonnet'] if vars.k3s.enabled])
           // Base stack is loaded at the end to override previous definitions
           + (import 'base_operator_stack.jsonnet')
           // Load image versions last to override default from modules
           + (import 'image_sources_versions.jsonnet');

// Generate core modules
{ ['setup/0namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) }
// First generate operator resources except the serviceMonitors
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor'), std.objectFields(kp.prometheusOperator))
}
// serviceMonitor is separated so that it can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor }
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) }
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) }
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) }
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
{ ['ingress-' + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) }

{  // Dynamically generate additional modules from vars.jsonnet
  [std.asciiLower(module.name) + '-' + name]: kp[module.name][name]
  for module in vars.modules
  if module.enabled
  for name in std.objectFields(kp[module.name])
}
