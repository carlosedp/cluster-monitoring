{
  _config+:: {
    namespace: 'monitoring',
  },
  // Enable or disable additional modules
  modules: [
    {
      // After deployment, run the create_gmail_auth.sh script from scripts dir.
      name: 'smtpRelay',
      enabled: false,
      file: import 'modules/smtp_relay.jsonnet',
    },
    {
      name: 'armExporter',
      enabled: false,
      file: import 'modules/arm_exporter.jsonnet',
    },
    {
      name: 'upsExporter',
      enabled: false,
      file: import 'modules/ups_exporter.jsonnet',
    },
    {
      name: 'metallbExporter',
      enabled: false,
      file: import 'modules/metallb.jsonnet',
    },
    {
      name: 'nginxExporter',
      enabled: false,
      file: import 'modules/nginx.jsonnet',
    },
    {
      name: 'traefikExporter',
      enabled: false,
      file: import 'modules/traefik.jsonnet',
    },
    {
      name: 'elasticExporter',
      enabled: false,
      file: import 'modules/elasticsearch_exporter.jsonnet',
    },
    {
      name: 'speedtestExporter',
      enabled: false,
      file: import 'modules/speedtest_exporter.jsonnet',
    },
  ],

  k3s: {
    enabled: false,
    master_ip: ['192.168.1.15'],
  },

  // Domain suffix for the ingresses
  suffixDomain: '192.168.1.15.nip.io',
  // If TLSingress is true, a self-signed HTTPS ingress with redirect will be created
  TLSingress: true,
  // If UseProvidedCerts is true, provided files will be used on created HTTPS ingresses.
  // Use a wildcard certificate for the domain like ex. "*.192.168.99.100.nip.io"
  UseProvidedCerts: false,
  TLSCertificate: importstr 'server.crt',
  TLSKey: importstr 'server.key',

  // Persistent volume configuration
  enablePersistence: {
    // Setting these to false, defaults to emptyDirs.
    prometheus: false,
    grafana: false,
    // If using a pre-created PV, fill in the names below. If blank, they will use the default StorageClass
    prometheusPV: '',
    grafanaPV: '',
    // If required to use a specific storageClass, keep the PV names above blank and fill the storageClass name below.
    storageClass: '',
    // Define the PV sizes below
    prometheusSizePV: '2Gi',
    grafanaSizePV: '20Gi',
  },

  // Configuration for Prometheus deployment
  prometheus: {
    retention: '15d',
    scrapeInterval: '30s',
    scrapeTimeout: '30s',
  },
  grafana: {
    // Grafana "from" email
    from_address: 'myemail@gmail.com',
    // Plugins to be installed at runtime.
    //Ex. plugins: ['grafana-piechart-panel', 'grafana-clock-panel'],
    plugins: [],
    //Ex. env: [ { name: 'http_proxy', value: 'host:8080' } ]
    env: []
  },
}
