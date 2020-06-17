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
      name: 'traefikExporter',
      enabled: false,
      file: import 'modules/traefik.jsonnet',
    },
    {
      name: 'elasticExporter',
      enabled: false,
      file: import 'modules/elasticsearch_exporter.jsonnet',
    },
  ],

  k3s: {
    enabled: false,
    master_ip: ['192.168.15.15'],
  },

  // Domain suffix for the ingresses
  suffixDomain: '192.168.15.15.nip.io',
  // If TLSingress is true, a self-signed HTTPS ingress with redirect will be created
  TLSingress: true,
  // If UseProvidedCerts is true, provided files will be used on created HTTPS ingresses.
  // Use a wildcard certificate for the domain like ex. "*.192.168.99.100.nip.io"
  UseProvidedCerts: false,
  TLSCertificate: importstr 'server.crt',
  TLSKey: importstr 'server.key',

  // Setting these to false, defaults to emptyDirs.
  // If using a pre-created PV, fill in the names. If blank, they will use the default StorageClass
  enablePersistence: {
    prometheus: false,
    grafana: false,
    prometheusPV: '',
    prometheusSizePV: '2Gi',
    grafanaPV: '',
    grafanaSizePV: '20Gi',
  },

  // Grafana "from" email
  grafana: {
    from_address: 'myemail@gmail.com',
  },
}
