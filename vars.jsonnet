{
  // Enable or disable additional modules
  installModules: {
    'arm-exporter': false,
    metallb: false,
    traefik: false,
    'ups-exporter': false,
    'elastic-exporter': false,
  },

  // Setting these to false, defaults to emptyDirs
  enablePersistence: {
    prometheus: false,
    grafana: false,
  },

  // Domain suffix for the ingresses
  suffixDomain: "internal.carlosedp.com",

  // Grafana from email
  grafana: {
    from_address: 'carlosedp@gmail.com',
  },
}