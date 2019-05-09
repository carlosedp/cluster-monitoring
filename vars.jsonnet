{
  // Enable or disable additional modules
  installModules: {
    'arm-exporter': false,
    'metallb-exporter': false,
    'traefik-exporter': false,
    'ups-exporter': false,
    'elastic-exporter': false,
  },

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
