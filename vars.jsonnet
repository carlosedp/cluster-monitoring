{
  // Enable or disable additional modules
  modules: [
    {
      name: 'armExporter',
      enabled: false,
      file: import 'arm_exporter.jsonnet',
    },
    {
      name: 'upsExporter',
      enabled: false,
      file: import 'ups_exporter.jsonnet',
    },
    {
      name: 'metallbExporter',
      enabled: false,
      file: import 'metallb.jsonnet',
    },
    {
      name: 'traefikExporter',
      enabled: false,
      file: import 'traefik.jsonnet',
    },
    {
      name: 'elasticExporter',
      enabled: false,
      file: import 'elasticsearch_exporter.jsonnet',
    },
  ],

  // Setting these to false, defaults to emptyDirs
  enablePersistence: {
    prometheus: false,
    grafana: false,
  },

  // Domain suffix for the ingresses
  suffixDomain: '192.168.99.100.nip.io',

  // Grafana "from" email
  grafana: {
    from_address: 'myemail@gmail.com',
  },
}
