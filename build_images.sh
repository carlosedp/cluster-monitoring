#!/bin/bash

REPO=carlosedp

AOM_VERSION=2.1
KSM_VERSION=v1.3.0
VERSION=v0.20.0
PROMCONFIGRELOADER_VERSION=v0.20.0

# Kubernetes addon-resizer
# Retag Addon-resizer google images to have unified manifest on DockerHub
docker pull gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION
docker pull gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION

docker tag gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm64
docker tag gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm

docker push $REPO/addon-resizer:$AOM_VERSION-arm
docker push $REPO/addon-resizer:$AOM_VERSION-arm64

manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/addon-resizer:$AOM_VERSION-ARCH --target $REPO/addon-resizer:$AOM_VERSION
manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/addon-resizer:$AOM_VERSION-ARCH --target $REPO/addon-resizer:latest

# Kube-state-metrics
go get github.com/kubernetes/kube-state-metrics
mv $HOME/go/src/github.com/kubernetes/kube-state-metrics $HOME/go/src/k8s.io/kube-state-metrics
cd $HOME/go/src/k8s.io/kube-state-metrics
git checkout ${KSM_VERSION}
GOOS=linux GOARCH=arm go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm .

GOOS=linux GOARCH=arm64 go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm64 .

docker push $REPO/kube-state-metrics:$KSM_VERSION-arm
docker push $REPO/kube-state-metrics:$KSM_VERSION-arm64

manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/kube-state-metrics:$KSM_VERSION-ARCH --target $REPO/kube-state-metrics:$KSM_VERSION
manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/kube-state-metrics:$KSM_VERSION-ARCH --target $REPO/kube-state-metrics:latest


# Prometheus-operator

go get github.com/coreos/prometheus-operator
cd $HOME/go/src/github.com/coreos/prometheus-operator
git checkout ${VERSION}

go get -u github.com/prometheus/promu

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM busybox/' > Dockerfile.arm

GOOS=linux GOARCH=arm $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-arm64 -f Dockerfile.arm .

docker push $REPO/prometheus-operator:$VERSION-arm
docker push $REPO/prometheus-operator:$VERSION-arm64

manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-operator:$VERSION-ARCH --target $REPO/prometheus-operator:$VERSION
manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-operator:$VERSION-ARCH --target $REPO/prometheus-operator:latest

rm Dockerfile.arm

# prometheus-config-reloader
go get github.com/coreos/prometheus-operator
cd $HOME/go/src/github.com/coreos/prometheus-operator/
git checkout ${PROMCONFIGRELOADER_VERSION}
cd $HOME/go/src/github.com/coreos/prometheus-operator/contrib/prometheus-config-reloader

cat Dockerfile |sed -e 's/^FROM.*/FROM busybox/' > Dockerfile.arm

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $REPO/prometheus-config-reloader:${PROMCONFIGRELOADER_VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $REPO/prometheus-config-reloader:${PROMCONFIGRELOADER_VERSION}-arm64 -f Dockerfile.arm .

docker push $REPO/prometheus-config-reloader:$PROMCONFIGRELOADER_VERSION-arm
docker push $REPO/prometheus-config-reloader:$PROMCONFIGRELOADER_VERSION-arm64

manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-config-reloader:$PROMCONFIGRELOADER_VERSION-ARCH --target $REPO/prometheus-config-reloader:$VERSION
manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/prometheus-config-reloader:$PROMCONFIGRELOADER_VERSION-ARCH --target $REPO/prometheus-config-reloader:latest

rm Dockerfile.arm
