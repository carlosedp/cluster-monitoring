local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local vars = import 'vars.jsonnet';
local enabledModules = [module.name for module in vars.modules if module.enabled];

local join_objects(objs) =
    local aux(arr, i, running) =
        if i >= std.length(arr) then
            running
        else
            aux(arr, i + 1, running + arr[i]) tailstrict;
    aux(objs, 0, {});

local kp = (import 'kube-prometheus/kube-prometheus.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-anti-affinity.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-kops-coredns.libsonnet')
           + (import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet')
           // Use http Kubelet targets. Comment to revert to https
           + (import 'kube-prometheus/kube-prometheus-insecure-kubelet.libsonnet')
           + (import 'base_operator_stack.jsonnet')
           + (import 'smtp_server.jsonnet')
           // Additional Modules
           + join_objects([module.file for module in vars.modules if module.enabled])
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
{ ['smtp-server-' + name]: kp.smtpServer[name] for name in std.objectFields(kp.smtpServer) }
// Additional Modules

{
    [std.asciiLower(moduleName) + '-' + objName]: {kp.moduleName[objName]}
    for objName in [std.objectFields(kp[moduleName]] for moduleName in enabledModules
}


// {
//   local items = ["a", "b", "c"],
//   joined: {
//     [x + i]: {
//       data: "x = %s and i = %s" % [x, i],
//     } for i in ["1", "2"] for x in items
//   }
// }

// { ['arm-exporter-' + name]: kp.armExporter[name] for name in std.objectFields(kp.armExporter) }

// {[std.asciiLower(moduleName) + '-' + objName]: kp.moduleName[objName] for objName in [std.objectFields(kp[moduleName]) for moduleName in enabledModules]}

// (if vars.installModules['arm-exporter'] then
//    { ['arm-exporter-' + name]: kp.armExporter[name] for name in std.objectFields(kp.armExporter) } else {}) +
// (if vars.installModules.metallb then
//    { ['metallb-' + name]: kp.metallb[name] for name in std.objectFields(kp.metallb) } else {}) +
// (if vars.installModules.traefik then
//    { ['traefik-' + name]: kp.traefik[name] for name in std.objectFields(kp.traefik) } else {}) +
// (if vars.installModules['ups-exporter'] then
//    { ['ups-exporter-' + name]: kp.upsExporter[name] for name in std.objectFields(kp.upsExporter) } else {}) +
// (if vars.installModules['elastic-exporter'] then
//    { ['elasticexporter-' + name]: kp.elasticExporter[name] for name in std.objectFields(kp.elasticExporter) } else {})
