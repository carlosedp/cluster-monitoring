local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local vars = import 'vars.jsonnet';

{
  // Join multiple objects into one
  join_objects(objs)::
    local aux(arr, i, running) =
      if i >= std.length(arr) then
        running
      else
        aux(arr, i + 1, running + arr[i]) tailstrict;
    aux(objs, 0, {}),

  // Creates endpoint objects
  newEndpoint(name, namespace, ips, portName, portNumber):: (
    local endpoints = k.core.v1.endpoints;
    local endpointSubset = endpoints.subsetsType;
    local endpointPort = endpointSubset.portsType;
    local Port = endpointPort.new() +
                    endpointPort.withName(portName) +
                    endpointPort.withPort(portNumber) +
                    endpointPort.withProtocol('TCP');

    local subset = endpointSubset.new() +
                    endpointSubset.withAddresses([
                       { ip: IP }
                       for IP in ips
                     ]) +
                    endpointSubset.withPorts(Port);
    endpoints.new() +
      endpoints.mixin.metadata.withName(name) +
      endpoints.mixin.metadata.withNamespace(namespace) +
      endpoints.mixin.metadata.withLabels({ 'k8s-app': name }) +
      endpoints.withSubsets(subset)
    ),

  // Creates ingress objects
  newIngress(name, namespace, host, path, serviceName, servicePort):: (
    local secret = k.core.v1.secret;
    local ingress = k.extensions.v1beta1.ingress;
    local ingressTls = ingress.mixin.spec.tlsType;
    local ingressRule = ingress.mixin.spec.rulesType;
    local httpIngressPath = ingressRule.mixin.http.pathsType;

    ingress.new() +
    ingress.mixin.metadata.withName(name) +
    ingress.mixin.metadata.withNamespace(namespace) +
    ingress.mixin.spec.withRules(
      ingressRule.new() +
      ingressRule.withHost(host) +
      ingressRule.mixin.http.withPaths(
        httpIngressPath.new() +
        httpIngressPath.withPath(path) +
        httpIngressPath.mixin.backend.withServiceName(serviceName) +
        httpIngressPath.mixin.backend.withServicePort(servicePort)
      ),
    )
  ),

  // Creates http ServiceMonitor objects
  newServiceMonitor(name, namespace, matchLabel, matchNamespace, portName, portScheme, path='metrics'):: (
    {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: name,
          namespace: namespace,
          labels: {
            'app': name,
          },
        },
        spec: {
          jobLabel: name+'-exporter',
          selector: {
            matchLabels: matchLabel,
          },
          endpoints: [
            {
              port: portName,
              scheme: portScheme,
              interval: '30s',
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
              }
            }],
      }
    };
    std.mergePatch(s, t)
    // s + t
  ),
}