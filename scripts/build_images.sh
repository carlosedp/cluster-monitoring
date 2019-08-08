#!/bin/bash

# Build images for Prometheus Operator and dependencies
# Run on Linux AMD64 machine due to qemu image for rbac-proxy

export DOCKER_CLI_EXPERIMENTAL=enabled

REPO=carlosedp

AOR_VERSION=2.1
PROM_ADAPTER_VERSION=v0.5.0
KSM_VERSION=v1.7.2
PROM_OP_VERSION=v0.31.1
KUBE_RBAC_VERSION=v0.4.1
PROM_CONFIG_RELOADER_VERSION=v0.31.1
CONFIGMAP_RELOAD_VERSION=v0.2.2
#-------------------------------------------------------------------------------
# Kubernetes addon-resizer
# Retag Addon-resizer google images to have unified manifest on DockerHub
docker pull gcr.io/google-containers/addon-resizer-arm:$AOR_VERSION
docker pull gcr.io/google-containers/addon-resizer-arm64:$AOR_VERSION
docker pull gcr.io/google-containers/addon-resizer-amd64:$AOR_VERSION

docker tag gcr.io/google-containers/addon-resizer-arm:$AOR_VERSION $REPO/addon-resizer:$AOR_VERSION-arm
docker tag gcr.io/google-containers/addon-resizer-arm64:$AOR_VERSION $REPO/addon-resizer:$AOR_VERSION-arm64
docker tag gcr.io/google-containers/addon-resizer-amd64:$AOR_VERSION $REPO/addon-resizer:$AOR_VERSION-amd64

docker push $REPO/addon-resizer:$AOR_VERSION-arm
docker push $REPO/addon-resizer:$AOR_VERSION-arm64
docker push $REPO/addon-resizer:$AOR_VERSION-amd64

docker rmi gcr.io/google-containers/addon-resizer-arm:$AOR_VERSION
docker rmi gcr.io/google-containers/addon-resizer-arm64:$AOR_VERSION
docker rmi gcr.io/google-containers/addon-resizer-amd64:$AOR_VERSION
docker rmi $REPO/addon-resizer:$AOR_VERSION-arm
docker rmi $REPO/addon-resizer:$AOR_VERSION-arm64
docker rmi $REPO/addon-resizer:$AOR_VERSION-amd64

IMAGE=$REPO/addon-resizer
VERSION=$AOR_VERSION
ALL_ARCH='amd64 arm arm64'

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION
#-------------------------------------------------------------------------------
# Prometheus-adapter
# Retag prometheus-adapter from directxman12 images to have unified manifest on DockerHub

docker pull directxman12/k8s-prometheus-adapter-arm:$PROM_ADAPTER_VERSION
docker pull directxman12/k8s-prometheus-adapter-arm64:$PROM_ADAPTER_VERSION
docker pull directxman12/k8s-prometheus-adapter-amd64:$PROM_ADAPTER_VERSION

docker tag directxman12/k8s-prometheus-adapter-arm:$PROM_ADAPTER_VERSION $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-arm
docker tag directxman12/k8s-prometheus-adapter-arm64:$PROM_ADAPTER_VERSION $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-arm64
docker tag directxman12/k8s-prometheus-adapter-amd64:$PROM_ADAPTER_VERSION $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-amd64

docker push $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-arm
docker push $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-arm64
docker push $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-amd64

docker rmi directxman12/k8s-prometheus-adapter-arm:$PROM_ADAPTER_VERSION
docker rmi directxman12/k8s-prometheus-adapter-arm64:$PROM_ADAPTER_VERSION
docker rmi directxman12/k8s-prometheus-adapter-amd64:$PROM_ADAPTER_VERSION
docker rmi $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-arm
docker rmi $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-arm64
docker rmi $REPO/k8s-prometheus-adapter:$PROM_ADAPTER_VERSION-amd64

IMAGE=$REPO/k8s-prometheus-adapter
VERSION=$PROM_ADAPTER_VERSION
ALL_ARCH='amd64 arm arm64'

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION
#-------------------------------------------------------------------------------
# Kube-state-metrics

IMAGE=carlosedp/kube-state-metrics
ALL_ARCH='amd64 arm arm64'
VERSION=$KSM_VERSION

rm -rf $GOPATH/src/k8s.io/kube-state-metrics
mkdir $GOPATH/src/k8s.io/
pushd $GOPATH/src/k8s.io/
git clone https://github.com/kubernetes/kube-state-metrics
cd kube-state-metrics
git checkout ${KSM_VERSION}

CGO_ENABLED=0 GOOS=linux GOARCH=arm go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm .

CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm64 .

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-amd64  .

docker push $REPO/kube-state-metrics:$KSM_VERSION-arm
docker push $REPO/kube-state-metrics:$KSM_VERSION-arm64
docker push $REPO/kube-state-metrics:$KSM_VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

popd
#-------------------------------------------------------------------------------
# Prometheus-operator
IMAGE=carlosedp/prometheus-operator
ALL_ARCH='amd64 arm arm64'
VERSION=$PROM_OP_VERSION

rm -rf $GOPATH/src/github.com/coreos/prometheus-operator
mkdir $GOPATH/src/github.com/coreos/
pushd $GOPATH/src/github.com/coreos/
git clone https://github.com/coreos/prometheus-operator
cd prometheus-operator
git checkout ${VERSION}

go get -u github.com/prometheus/promu

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm32v6\/busybox/' > Dockerfile.arm

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm64v8\/busybox/' > Dockerfile.arm64

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM amd64\/busybox/' > Dockerfile.amd64

GOOS=linux GOARCH=arm $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-arm64 -f Dockerfile.arm64 .

GOOS=linux GOARCH=amd64 $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-amd64 -f Dockerfile.amd64 .

docker push $REPO/prometheus-operator:$VERSION-arm
docker push $REPO/prometheus-operator:$VERSION-arm64
docker push $REPO/prometheus-operator:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

rm Dockerfile.arm
rm Dockerfile.arm64
rm Dockerfile.amd64
popd
#-------------------------------------------------------------------------------
# kube-rbac-proxy
IMAGE=carlosedp/kube-rbac-proxy
VERSION=$KUBE_RBAC_VERSION
ALL_ARCH='amd64 arm arm64'

go get github.com/brancz/kube-rbac-proxy
cd $HOME/go/src/github.com/brancz/kube-rbac-proxy
git fetch
git checkout ${VERSION}

cat > Dockerfile.arm <<EOF
FROM arm32v6/alpine:3.8
COPY qemu-arm-static /usr/bin/qemu-arm-static
RUN apk add -U --no-cache ca-certificates && rm -rf /var/cache/apk/*
COPY kube-rbac-proxy .
RUN rm /usr/bin/qemu-arm-static
ENTRYPOINT ["./kube-rbac-proxy"]
EXPOSE 8080
EOF

cat > Dockerfile.arm64 <<EOF
FROM arm64v8/alpine:3.8
COPY qemu-aarch64-static /usr/bin/qemu-aarch64-static
RUN apk add -U --no-cache ca-certificates && rm -rf /var/cache/apk/*
COPY kube-rbac-proxy .
ENTRYPOINT ["./kube-rbac-proxy"]
EXPOSE 8080
EOF

cat > Dockerfile.amd64 <<EOF
FROM amd64/alpine:3.8
RUN apk add -U --no-cache ca-certificates && rm -rf /var/cache/apk/*
COPY kube-rbac-proxy .
ENTRYPOINT ["./kube-rbac-proxy"]
EXPOSE 8080
EOF

docker run --rm --privileged multiarch/qemu-user-static:register --reset
rm qemu-arm-static
wget https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-arm-static
chmod +x qemu-arm-static
CGO_ENABLED=0 GOOS=linux GOARCH=arm go build .
docker build -t $IMAGE:$VERSION-arm -f Dockerfile.arm .

rm qemu-aarch64-static
wget https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-aarch64-static
chmod +x qemu-aarch64-static
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build .
docker build -t $IMAGE:$VERSION-arm64  -f Dockerfile.arm64 .

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' .
docker build -t $IMAGE:$VERSION-amd64  -f Dockerfile.amd64 .

docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

#-------------------------------------------------------------------------------
# prometheus-config-reloader
IMAGE=carlosedp/prometheus-config-reloader

VERSION=$PROM_CONFIG_RELOADER_VERSION
ALL_ARCH='amd64 arm arm64'


pushd $GOPATH/src/github.com/coreos/prometheus-operator
cd $GOPATH/src/github.com/coreos/prometheus-operator/cmd/prometheus-config-reloader
git checkout ${VERSION}

cp ../../Dockerfile ./Dockerfile.new
cat Dockerfile.new |sed -e 's/ADD operator.*/ADD prometheus-config-reloader /bin/prometheus-config-reloader/' |sed -e 's/^ENTRYPOINT.*/ENTRYPOINT ["/bin/prometheus-config-reloader"]/' > Dockerfile.arm


wget https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-arm-static
wget https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-aarch64-static
chmod +x qemu*

cat Dockerfile.new |sed -e 's/^FROM.*/FROM arm32v6\/busybox/'|sed -e 's/ADD operator.*/ADD prometheus-config-reloader \/bin\/prometheus-config-reloader/' |sed -e 's/^ENTRYPOINT.*/ENTRYPOINT \["\/bin\/prometheus-config-reloader"\]/' > Dockerfile.arm

cat Dockerfile.new |sed -e 's/^FROM.*/FROM arm64v8\/busybox/'|sed -e 's/ADD operator.*/ADD prometheus-config-reloader \/bin\/prometheus-config-reloader/' |sed -e 's/^ENTRYPOINT.*/ENTRYPOINT \["\/bin\/prometheus-config-reloader"\]/' > Dockerfile.arm64

cat Dockerfile.new |sed -e 's/^FROM.*/FROM amd64\/busybox/'|sed -e 's/ADD operator.*/ADD prometheus-config-reloader \/bin\/prometheus-config-reloader/' |sed -e 's/^ENTRYPOINT.*/ENTRYPOINT \["\/bin\/prometheus-config-reloader"\]/' > Dockerfile.amd64

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $IMAGE:$VERSION-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $IMAGE:$VERSION-arm64 -f Dockerfile.arm64 .

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags '-extldflags "-static"'  -o prometheus-config-reloader main.go
docker build -t $IMAGE:$VERSION-amd64 -f Dockerfile.amd64 .

docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

rm Dockerfile.arm
rm Dockerfile.arm64
rm Dockerfile.amd64
rm Dockerfile.new

#-------------------------------------------------------------------------------
# configmap-reload
IMAGE=carlosedp/configmap-reload
VERSION=$CONFIGMAP_RELOAD_VERSION
ALL_ARCH='amd64 arm arm64'

go get github.com/openshift/configmap-reload
cd $HOME/go/src/github.com/openshift/configmap-reload
git fetch
git checkout ${VERSION}

cat > Dockerfile.arm <<EOF
FROM arm32v6/busybox
COPY configmap-reload /configmap-reload
ENTRYPOINT ["/configmap-reload"]
EOF

cat > Dockerfile.arm64 <<EOF
FROM arm64v8/busybox
COPY configmap-reload /configmap-reload
ENTRYPOINT ["/configmap-reload"]
EOF

cat > Dockerfile.amd64 <<EOF
FROM busybox
COPY configmap-reload /configmap-reload
ENTRYPOINT ["/configmap-reload"]
EOF

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build .
docker build -t $IMAGE:$VERSION-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build .
docker build -t $IMAGE:$VERSION-arm64 -f Dockerfile.arm64 .

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' .
docker build -t $IMAGE:$VERSION-amd64 -f Dockerfile.amd64 .

docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION