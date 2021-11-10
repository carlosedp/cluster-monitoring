local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  // Generates the manifests for all objects in kp except those starting with "_"
  generate(kp):: (
    {
      [std.asciiLower(module) + '-' + name]: kp[module][name]
      for module in std.objectFieldsAll(kp)
      if !std.startsWith(module, '_')
      for name in std.objectFields(kp[module])
    }
  ),

  // Join multiple objects into one
  join_objects(objs)::
    local aux(arr, i, running) =
      if i >= std.length(arr) then
        running
      else
        aux(arr, i + 1, running + arr[i]) tailstrict;
    aux(objs, 0, {}),

  // Creates serviceaccount
  newServiceAccount(name, namespace, labels):: (
    local serviceAccount = k.core.v1.serviceAccount;

    serviceAccount.new(name)
    + (if labels != null then serviceAccount.mixin.metadata.withLabels(labels) else {})
    + serviceAccount.mixin.metadata.withNamespace(namespace)
  ),

  // Creates ClusterRoles
  // roles format example: [{apis: ['authentication.k8s.io'],
  //                        res: ['tokenreviews'],
  //                        verbs: ['create']
  //                       },[{...}]]
  newClusterRole(name, roles, labels):: (
    local clusterRole = k.rbac.v1.clusterRole;
    local policyRule = clusterRole.rulesType;

    local p(apigroups, resources, verbs) = policyRule.new()
                                           + policyRule.withApiGroups([a for a in apigroups])
                                           + policyRule.withResources([r for r in resources])
                                           + policyRule.withVerbs([v for v in verbs]);

    local r = [p(pol.apis, pol.res, pol.verbs) for pol in roles];

    local rules = r;

    local c = clusterRole.new()
              + (if labels != null then clusterRole.mixin.metadata.withLabels(labels) else {})
              + clusterRole.mixin.metadata.withName(name)
              + clusterRole.withRules(rules);
    c
  ),

  // Creates a ClusterRoleBinding between a `clusterRole` and a `serviceAccount` on `serviceAccountNamespace`
  newClusterRoleBinding(name, serviceAccount, serviceAccountNamespace, clusterRole, labels):: (
    local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

    clusterRoleBinding.new()
    + clusterRoleBinding.mixin.metadata.withName(name)
    + (if labels != null then clusterRoleBinding.mixin.metadata.withLabels(labels) else {})
    + clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io')
    + clusterRoleBinding.mixin.roleRef.withName(clusterRole)
    + clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' })
    + clusterRoleBinding.withSubjects([{ kind: 'ServiceAccount', name: serviceAccount, namespace: serviceAccountNamespace }])
  ),

  // Creates endpoint objects
  newEndpoint(name, namespace, ips, portName, portNumber):: (
    local endpoints = k.core.v1.endpoints;
    local endpointSubset = endpoints.subsetsType;
    local endpointPort = endpointSubset.portsType;
    local Port = endpointPort.new()
                 + endpointPort.withName(portName)
                 + endpointPort.withPort(portNumber)
                 + endpointPort.withProtocol('TCP');

    local subset = endpointSubset.new()
                   + endpointSubset.withAddresses([
                     { ip: IP }
                     for IP in ips
                   ])
                   + endpointSubset.withPorts(Port);
    endpoints.new()
    + endpoints.mixin.metadata.withName(name)
    + endpoints.mixin.metadata.withNamespace(namespace)
    + endpoints.mixin.metadata.withLabels({ 'k8s-app': name })
    + endpoints.withSubsets(subset)
  ),

  // Creates ingress objects
  newIngress(name, namespace, host, path, serviceName, servicePort):: (
    {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: {
        name: name,
        namespace: namespace,
      },
      spec: {
        rules: [
          {
            host: host,
            http: {
              paths: [
                {
                  backend: {
                    service: {
                      name: serviceName,
                      port: {
                        name: servicePort,
                      },
                    },
                  },
                  path: path,
                  pathType: 'Prefix',
                },
              ],
            },
          },
        ],
      },
    }
  ),

  // Add TLS to Ingress resource with secret containing the certificates if exists
  addIngressTLS(I, S=''):: (
    local ingress = k.networking.v1beta1.ingress;
    local ingressTls = ingress.mixin.spec.tlsType;
    local host = I.spec.rules[0].host;
    local namespace = I.metadata.namespace;

    I + ingress.mixin.spec.withTls(
      ingressTls.new() +
      ingressTls.withHosts(host) +
      (if S != '' then { secretName: S } else {})
    )
  ),

  // Creates a new TLS Secred with Certificate and Key
  newTLSSecret(name, namespace, crt, key):: (
    local secret = k.core.v1.secret;

    secret.new(name) +
    secret.mixin.metadata.withNamespace(namespace) +
    secret.withType('kubernetes.io/tls') +
    secret.withData(
      {
        'tls.crt': std.base64(crt),
        'tls.key': std.base64(key),
      }
    )
  ),

  // Creates new basic deployments
  newDeployment(name, namespace, image, cmd, port):: (
    local deployment = k.apps.v1.deployment;
    local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
    local containerPort = container.portsType;

    local con =
      container.new(name, image)
      + (if cmd != null then container.withCommand(cmd) else {})
      + container.withPorts(containerPort.newNamed(port, name));

    local c = [con];

    local d = deployment.new(name, 1, c, { app: name })
              + deployment.mixin.metadata.withNamespace(namespace)
              + deployment.mixin.metadata.withLabels({ app: name })
              + deployment.mixin.spec.selector.withMatchLabels({ app: name })
              + deployment.mixin.spec.strategy.withType('RollingUpdate')
              + deployment.mixin.spec.template.spec.withRestartPolicy('Always');
    d
  ),

  newService(name, namespace, port):: (
    local service = k.core.v1.service;
    local servicePort = k.core.v1.service.mixin.spec.portsType;
    local p = servicePort.newNamed(name, port, port);

    local s = service.new(name, { app: name }, p)
              + service.mixin.metadata.withNamespace(namespace)
              + service.mixin.metadata.withLabels({ app: name });
    s
  ),

  // Creates http ServiceMonitor objects
  newServiceMonitor(name, namespace, matchLabel, matchNamespace, portName, portScheme, path='metrics', interval='30s', timeout='30s'):: (
    {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: name,
        namespace: namespace,
        labels: {
          app: name,
        },
      },
      spec: {
        jobLabel: name + '-exporter',
        selector: {
          matchLabels: matchLabel,
        },
        endpoints: [
          {
            port: portName,
            scheme: portScheme,
            interval: interval,
            scrapeTimeout: timeout,
            relabelings: [
              {
                action: 'replace',
                regex: '(.*)',
                replacement: '$1',
                sourceLabels: ['__meta_kubernetes_pod_node_name'],
                targetLabel: 'instance',
              },
            ],
          },
        ],
        namespaceSelector: {
          matchNames: [matchNamespace],
        },
      },
    }
  ),

  // Creates https ServiceMonitor objects
  newServiceMonitorHTTPS(name, namespace, matchLabel, matchNamespace, portName, portScheme, token):: (
    local s = $.newServiceMonitor(name, namespace, matchLabel, matchNamespace, portName, portScheme);
    // Replace endpoint with https and token
    local t = {
      spec: {
        endpoints: [{
          port: portName,
          scheme: portScheme,
          interval: '30s',
          bearerTokenFile: token,
          tlsConfig: {
            insecureSkipVerify: true,
          },
          relabelings: [
            {
              action: 'replace',
              regex: '(.*)',
              replacement: '$1',
              sourceLabels: ['__meta_kubernetes_pod_node_name'],
              targetLabel: 'instance',
            },
          ],
        }],
      },
    };
    std.mergePatch(s, t)
  ),

  // Adds arguments to a container in a deployment
  // args is an array of arguments in the format
  // ["arg1","arg2",]
  addArguments(deployment, container, args):: (
    { spec+: {
      template+: {
        spec+: {
          containers:
            std.map(
              function(c)
                if c.name == container then
                  c { args+: args }
                else c,
              super.containers
            ),
        },
      },
    } }
  ),

  // Adds environment variables to a container in a deployment
  // envs is an array of environment variables in the format
  // [{name: 'VARNAME', value: 'var_value'},{...},]
  addEnviromnentVars(deployment, container, envs):: (
    { spec+: {
      template+: {
        spec+: {
          containers:
            std.map(
              function(c)
                if c.name == container then
                  c { env+: envs }
                else c,
              super.containers
            ),
        },
      },
    } }
  ),
}
