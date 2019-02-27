{
  prometheusRules+:: {
    groups+: [
      {
        name: 'elasticsearch-k8s-rules',
        rules: [
          {
            expr: '100 * (elasticsearch_filesystem_data_size_bytes - elasticsearch_filesystem_data_free_bytes) / elasticsearch_filesystem_data_size_bytes',
            record: 'elasticsearch_filesystem_data_used_percent',
          },
          {
            expr: '100 - elasticsearch_filesystem_data_used_percent',
            record: 'elasticsearch_filesystem_data_free_percent',
          },

          {
            expr: 'elasticsearch_cluster_health_number_of_nodes < 3',
            alert: 'ElasticsearchTooFewNodesRunning',
            'for': '5m',
            annotations: {
              message: 'There are only {{$value}} < 3 ElasticSearch nodes running',
              summary: 'ElasticSearch running on less than 3 nodes',
            },
            labels: {
              severity: 'critical',
            },
          },
          {
            expr: 'elasticsearch_jvm_memory_used_bytes{area="heap"} / elasticsearch_jvm_memory_max_bytes{area="heap"} > 0.9',
            alert: 'ElasticsearchHeapTooHigh',
            'for': '15m',
            annotations: {
              message: 'The heap usage is over 90% for 15m',
              summary: 'ElasticSearch node {{$labels.node}} heap usage is high',
            },
            labels: {
              severity: 'critical',
            },
          },
        ],
      },
    ],
  },
}
