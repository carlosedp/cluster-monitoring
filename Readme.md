# Cluster Monitoring stack for ARM / X86-64 platforms

The Prometheus Operator for Kubernetes provides easy monitoring definitions for Kubernetes services and deployment and management of Prometheus instances.

This have been tested on a hybrid ARM64 / X84-64 Kubernetes cluster deployed as [this article](https://medium.com/@carlosedp/building-a-hybrid-x86-64-and-arm-kubernetes-cluster-e7f94ff6e51d).

This repository collects Kubernetes manifests, Grafana dashboards, and Prometheus rules combined with documentation and scripts to provide easy to operate end-to-end Kubernetes cluster monitoring with Prometheus using the Prometheus Operator. 

The content of this project is written in jsonnet and is an extension of the fantastic [kube-prometheus](https://github.com/coreos/prometheus-operator/blob/master/contrib/kube-prometheus) project.

To continue using my previous stack with manifests and previous versions of the operator and components, use the legacy repo tag from: https://github.com/carlosedp/prometheus-operator-ARM/tree/legacy.

Components included in this package:

* The Prometheus Operator
* Highly available Prometheus
* Highly available Alertmanager
* Prometheus node-exporter
* kube-state-metrics
* CoreDNS
* Grafana
* SMTP relay to Gmail for Grafana notifications

There are additional modules (disabled by default) to monitor other components of the infra-structure. These can be disabled on `vars.jsonnet` file by setting the module in `installModules` to `false`.

The additional modules are:

* ARM_exporter to generate temperature metrics
* MetalLB metrics
* Traefik metrics
* ElasticSearch metrics
* APC UPS metrics

There are also options to set the ingress domain suffix and enable persistence for Grafana and Prometheus.

After changing these parameters, rebuild the manifests with `make`.

## Quickstart

The repository already provides a set of compiled manifests to be applied into the cluster. The deployment can be customized thru the jsonnet files.

To simply deploy the stack, run:

```bash
$ make deploy

# Or manually:

$ kubectl apply -f manifests/

# It can take a few seconds for the above 'create manifests' command to fully create the following resources, so verify the resources are ready before proceeding.
$ until kubectl get customresourcedefinitions servicemonitors.monitoring.coreos.com ; do date; sleep 1; echo ""; done
$ until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

$ kubectl apply -f manifests/ # This command sometimes may need to be done twice (to workaround a race condition).
```

## Customizing

The content of this project consists of a set of jsonnet files making up a library to be consumed.

### Pre-reqs

The project requires json-bundler and the jsonnet compiler. The Makefile does the heavy-lifting of installing them. You need [Go](https://golang.org/dl/) already installed:

```bash
git clone https://github.com/carlosedp/prometheus-operator-ARM
cd prometheus-operator-ARM
make vendor
# Change the jsonnet files...
make
```

After this, a new customized set of manifests is built into the `manifests` dir. To apply to your cluster, run:

```bash
make deploy
```

To uninstall, run:

```bash
make teardown
```

## Images

This project depends on the following images (all supports ARM, ARM64 and AMD64 thru manifests):

**Alertmanager**
**Blackbox_exporter**
**Node_exporter**
**Snmp_exporter**
**Prometheus**

* Source: https://github.com/carlosedp/prometheus-ARM
* Autobuild: https://travis-ci.org/carlosedp/prometheus-ARM
* Images:
    * https://hub.docker.com/r/carlosedp/prometheus/
    * https://hub.docker.com/r/carlosedp/alertmanager/
    * https://hub.docker.com/r/carlosedp/blackbox_exporter/
    * https://hub.docker.com/r/carlosedp/node_exporter/
    * https://hub.docker.com/r/carlosedp/snmp_exporter/

**ARM_exporter**

* Source: https://github.com/carlosedp/docker-arm_exporter
* Autobuild: https://travis-ci.org/carlosedp/docker-arm_exporter
* Images: https://hub.docker.com/r/carlosedp/arm_exporter/

**Prometheus-operator**

* Source: https://github.com/carlosedp/prometheus-operator
* Autobuild: No autobuild yet. Use provided `build_images.sh` script.
* Images: https://hub.docker.com/r/carlosedp/prometheus-operator

**Prometheus-adapter**

* Source: https://github.com/DirectXMan12/k8s-prometheus-adapter
* Autobuild: No autobuild yet. Use provided `build_images.sh` script.
* Images: https://hub.docker.com/r/carlosedp/k8s-prometheus-adapter

**Grafana**

* Source: https://github.com/carlosedp/grafana-ARM
* Autobuild: https://travis-ci.org/carlosedp/grafana-ARM
* Images: https://hub.docker.com/r/grafana/grafana/

**Kube-state-metrics**

* Source: https://github.com/kubernetes/kube-state-metrics
* Autobuild: No autobuild yet. Use provided `build_images.sh` script.
* Images: https://hub.docker.com/r/carlosedp/kube-state-metrics

**Addon-resizer**

* Source: https://github.com/kubernetes/autoscaler/tree/master/addon-resizer
* Autobuild: No autobuild yet. Use provided `build_images.sh` script.
* Images: https://hub.docker.com/r/carlosedp/addon-resizer

*Obs.* This image is a clone of [AMD64](https://console.cloud.google.com/gcr/images/google-containers/GLOBAL/addon-resizer-amd64), [ARM64](https://console.cloud.google.com/gcr/images/google-containers/GLOBAL/addon-resizer-arm64) and [ARM](https://console.cloud.google.com/gcr/images/google-containers/GLOBAL/addon-resizer-arm64) with a manifest. It's cloned and generated by the `build_images.sh` script

**configmap_reload**

* Source: https://github.com/carlosedp/configmap-reload
* Autobuild: https://travis-ci.org/carlosedp/configmap-reload
* Images: https://hub.docker.com/r/carlosedp/configmap-reload

**prometheus-config-reloader**

* Source: https://github.com/coreos/prometheus-operator/tree/master/contrib/prometheus-config-reloader
* Autobuild: No autobuild yet. Use provided `build_images.sh` script.
* Images: https://hub.docker.com/r/carlosedp/prometheus-config-reloader

**SMTP-server**

* Source: https://github.com/carlosedp/docker-smtp
* Autobuild: https://travis-ci.org/carlosedp/docker-smtp
* Images: https://hub.docker.com/r/carlosedp/docker-smtp

**Kube-rbac-proxy**

* Source: https://github.com/brancz/kube-rbac-proxy
* Autobuild: No autobuild yet. Use provided `build_images.sh` script.
* Images: https://hub.docker.com/r/carlosedp/kube-rbac-proxy
