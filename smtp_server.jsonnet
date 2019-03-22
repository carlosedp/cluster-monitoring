local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',

    versions+:: {
      smtpServer: 'v1.0.1',
    },

    imageRepos+:: {
      smtpServer: 'carlosedp/docker-smtp',
    },
  },

  smtpServer+:: {
    deployment:
      local deployment = k.apps.v1beta2.deployment;
      local container = k.apps.v1beta2.deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;

      local podLabels = { run: 'smtp-server' };

      local smtpServer =
        container.new('smtp-server', $._config.imageRepos.smtpServer + ':' + $._config.versions.smtpServer) +
        container.withPorts(containerPort.newNamed('smtp', 25)) +
        container.withEnv([
          {
            name: 'GMAIL_USER',
            valueFrom: {
              secretKeyRef: { name: 'smtp-account', key: 'username' },
            },
          },
          {
            name: 'GMAIL_PASSWORD',
            valueFrom: {
              secretKeyRef: { name: 'smtp-account', key: 'password' },
            },
          },
          {
            name: 'DISABLE_IPV6',
            value: 'True',
          },
          { name: 'RELAY_DOMAINS', value: ':192.168.0.0/24:10.0.0.0/16' },
        ]);

      local c = [smtpServer];

      deployment.new('smtp-server', 1, c, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels),

    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;
      local smtpServerPorts = servicePort.newNamed('smtp', 25, 'smtp');

      service.new('smtp-server', $.smtpServer.deployment.spec.selector.matchLabels, smtpServerPorts) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ run: 'smtp-server' }),
  },
}
