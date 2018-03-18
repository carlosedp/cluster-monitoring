# Prometheus Operator for ARM platform

The Prometheus Operator for Kubernetes provides easy monitoring definitions for Kubernetes services and deployment and management of Prometheus instances.

This project aims on porting the [official manifests](https://github.com/coreos/prometheus-operator/tree/master/contrib/kube-prometheus) and images to the ARM platform. This have been tested on a ARM64 Kubernetes cluster deployed as [this article](medium.com/@carlosedp/building-an-arm-kubernetes-cluster-ef31032636f9).

## Changes to Kubeadm for Prometheus Operator

According to the official deployment documentation [here](https://github.com/coreos/prometheus-operator/blob/master/contrib/kube-prometheus/docs/kube-prometheus-on-kubeadm.md), a couple of changes on the cluster are required:

We need to expose the cadvisor that is installed and managed by the kubelet daemon and allow webhook token authentication. To do so, we do the following on **all the masters and nodes**:

    sudo sed -e "/cadvisor-port=0/d" -i /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    sudo sed -e "s/--authorization-mode=Webhook/--authentication-token-webhook=true --authorization-mode=Webhook/" -i /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet

In case you already have a Kubernetes deployed with kubeadm, change the address kube-controller-manager and kube-scheduler listens **on master node** in addition to previous kubelet change:

    sudo sed -e "s/- --address=127.0.0.1/- --address=0.0.0.0/" -i /etc/kubernetes/manifests/kube-controller-manager.yaml
    sudo sed -e "s/- --address=127.0.0.1/- --address=0.0.0.0/" -i /etc/kubernetes/manifests/kube-scheduler.yaml


