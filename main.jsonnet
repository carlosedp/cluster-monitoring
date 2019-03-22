local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

// Enable or disable additional modules
local installModules = {
  'arm-exporter': true,
  metallb: true,
  traefik: true,
  'ups-exporter': true,
  'elastic-exporter': true,
};

local kp = (import 'kube-prometheus/kube-prometheus.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-anti-affinity.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-kops-coredns.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet')
           + (import 'base_operator_stack.jsonnet')
           + (import 'smtp_server.jsonnet')
           // Additional Modules
           + (if installModules['arm-exporter'] then (import 'arm_exporter.jsonnet') else {})
           + (if installModules.metallb then (import 'metallb.jsonnet') else {})
           + (if installModules.traefik then (import 'traefik.jsonnet') else {})
           + (if installModules['ups-exporter'] then (import 'ups_exporter.jsonnet') else {})
           + (if installModules['elastic-exporter'] then (import 'elasticsearch_exporter.jsonnet') else {})
           // Load image versions last to override default from modules
           + (import 'image_sources_versions.jsonnet');

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) }
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['ingress-' + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) } +
{ ['smtp-server-' + name]: kp.smtpServer[name] for name in std.objectFields(kp.smtpServer) } +
// Additional Modules
(if installModules['arm-exporter'] then
   { ['arm-exporter-' + name]: kp.armExporter[name] for name in std.objectFields(kp.armExporter) } else {}) +
(if installModules.metallb then
   { ['metallb-' + name]: kp.metallb[name] for name in std.objectFields(kp.metallb) } else {}) +
(if installModules.traefik then
   { ['traefik-' + name]: kp.traefik[name] for name in std.objectFields(kp.traefik) } else {}) +
(if installModules['ups-exporter'] then
   { ['ups-exporter-' + name]: kp.upsExporter[name] for name in std.objectFields(kp.upsExporter) } else {}) +
(if installModules['elastic-exporter'] then
   { ['elasticexporter-' + name]: kp.elasticExporter[name] for name in std.objectFields(kp.elasticExporter) } else {})
