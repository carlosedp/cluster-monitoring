local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',

    versions+:: {
      armExporter: 'latest',
    },

    imageRepos+:: {
      armExporter: 'carlosedp/arm_exporter',
    },
  },

  armExporter+:: {
    clusterRoleBinding:
      local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName('arm-exporter') +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withName('arm-exporter') +
      clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' }) +
      clusterRoleBinding.withSubjects([{ kind: 'ServiceAccount', name: 'arm-exporter', namespace: $._config.namespace }]),

    clusterRole:
      local clusterRole = k.rbac.v1.clusterRole;
      local policyRule = clusterRole.rulesType;

      local authenticationRole = policyRule.new() +
                                 policyRule.withApiGroups(['authentication.k8s.io']) +
                                 policyRule.withResources([
                                   'tokenreviews',
                                 ]) +
                                 policyRule.withVerbs(['create']);

      local authorizationRole = policyRule.new() +
                                policyRule.withApiGroups(['authorization.k8s.io']) +
                                policyRule.withResources([
                                  'subjectaccessreviews',
                                ]) +
                                policyRule.withVerbs(['create']);

      local rules = [authenticationRole, authorizationRole];

      clusterRole.new() +
      clusterRole.mixin.metadata.withName('arm-exporter') +
      clusterRole.withRules(rules),

    serviceAccount:
      local serviceAccount = k.core.v1.serviceAccount;

      serviceAccount.new('arm-exporter') +
      serviceAccount.mixin.metadata.withNamespace($._config.namespace),

    daemonset:
      local daemonset = k.apps.v1beta2.daemonSet;
      local container = daemonset.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;
      local containerEnv = container.envType;

      local podLabels = { 'k8s-app': 'arm-exporter' };

      local armExporter =
        container.new('arm-exporter', $._config.imageRepos.armExporter + ':' + $._config.versions.armExporter) +
        container.withCommand([
          '/bin/rpi_exporter',
          '--web.listen-address=127.0.0.1:9243',
        ]) +
        container.mixin.resources.withRequests({ cpu: '50m', memory: '50Mi' }) +
        container.mixin.resources.withLimits({ cpu: '100m', memory: '100Mi' });

      local ip = containerEnv.fromFieldPath('IP', 'status.podIP');
      local proxy =
        container.new('kube-rbac-proxy', $._config.imageRepos.kubeRbacProxy + ':' + $._config.versions.kubeRbacProxy) +
        container.withArgs([
          '--secure-listen-address=$(IP):9243',
          '--upstream=http://127.0.0.1:9243/',
          '--tls-cipher-suites=' + std.join(',', $._config.tlsCipherSuites),
        ]) +
        container.withPorts(containerPort.new(9243) + containerPort.withHostPort(9243) + containerPort.withName('https')) +
        container.mixin.resources.withRequests({ cpu: '10m', memory: '20Mi' }) +
        container.mixin.resources.withLimits({ cpu: '20m', memory: '40Mi' }) +
        container.withEnv([ip]);
      local c = [armExporter, proxy];

      daemonset.new() +
      daemonset.mixin.metadata.withName('arm-exporter') +
      daemonset.mixin.metadata.withNamespace($._config.namespace) +
      daemonset.mixin.metadata.withLabels(podLabels) +
      daemonset.mixin.spec.selector.withMatchLabels(podLabels) +
      daemonset.mixin.spec.template.metadata.withLabels(podLabels) +
      daemonset.mixin.spec.template.spec.withNodeSelector({ 'beta.kubernetes.io/arch': 'arm64' }) +
      daemonset.mixin.spec.template.spec.withServiceAccountName('arm-exporter') +
      daemonset.mixin.spec.template.spec.withContainers(c),
    serviceMonitor:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'arm-exporter',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'arm-exporter',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          selector: {
            matchLabels: {
              'k8s-app': 'arm-exporter',
            },
          },
          endpoints: [
            {
              port: 'https',
              scheme: 'https',
              interval: '30s',
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
              tlsConfig: {
                insecureSkipVerify: true,
              },
            },
          ],
        },
      },

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      local armExporterPort = servicePort.newNamed('https', 9243, 'https');

      service.new('arm-exporter', $.armExporter.daemonset.spec.selector.matchLabels, armExporterPort) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ 'k8s-app': 'arm-exporter' }) +
      service.mixin.spec.withClusterIp('None'),
  },
}
