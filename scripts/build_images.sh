#!/bin/bash

# Build images for Prometheus Operator and dependencies
# Run on Linux AMD64 machine due to qemu image for rbac-proxy

export DOCKER_CLI_EXPERIMENTAL=enabled

REPO=carlosedp

export AOR_VERSION=2.3
export KSM_VERSION=v1.9.6
export PROM_OP_VERSION=v0.40.0
export KUBE_RBAC_VERSION=v0.5.0
export PROM_CONFIG_RELOADER_VERSION=v0.40.0
export CONFIGMAP_RELOAD_VERSION=latest
#-------------------------------------------------------------------------------
# Kubernetes addon-resizer
# Retag Addon-resizer google images to have unified manifest on DockerHub
ALL_ARCH=(amd64 arm arm64 ppc64le)
IMAGE=addon-resizer

for arch in $ALL_ARCH; do
    if [[ $arch == "arm" ]]; then archdocker="arm32v7";
    elif [[ $arch == "arm64" ]]; then archdocker="arm64v8";
    else archdocker="$arch"; fi
    docker pull gcr.io/google-containers/$IMAGE-$arch:$AOR_VERSION
    docker tag gcr.io/google-containers/$IMAGE-$arch:$AOR_VERSION $REPO/$IMAGE:$AOR_VERSION-$arch
    docker push $REPO/$IMAGE:$AOR_VERSION-$arch
done


docker manifest create --amend $REPO/$IMAGE:$AOR_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$REPO/$IMAGE:$AOR_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $REPO/$IMAGE:$AOR_VERSION $REPO/$IMAGE:$AOR_VERSION-$arch; done
docker manifest push --purge $REPO/$IMAGE:$AOR_VERSION

for arch in $ALL_ARCH; do
    docker rmi gcr.io/google-containers/$IMAGE-$arch:$AOR_VERSION
    docker rmi $REPO/$IMAGE:$AOR_VERSION-$arch
done

#-------------------------------------------------------------------------------
# Kube-state-metrics
IMAGE=carlosedp/kube-state-metrics
ALL_ARCH=(amd64 arm arm64 ppc64le)

rm -rf $GOPATH/src/k8s.io/kube-state-metrics
mkdir $GOPATH/src/k8s.io/
pushd $GOPATH/src/k8s.io/
git clone https://github.com/kubernetes/kube-state-metrics -b $KSM_VERSION --depth=1
cd kube-state-metrics

for arch in $ALL_ARCH; do
    if [[ $arch == "arm" ]]; then archdocker="arm32v7";
    elif [[ $arch == "arm64" ]]; then archdocker="arm64v8";
    else archdocker="$arch"; fi

    CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -a -installsuffix cgo -ldflags '-s -w -extldflags "-static"' -o kube-state-metrics .
    docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-$arch .
    docker push $REPO/kube-state-metrics:$KSM_VERSION-$arch
done

docker manifest create --amend $IMAGE:$KSM_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$KSM_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$KSM_VERSION $IMAGE:$KSM_VERSION-$arch; done
docker manifest push --purge $IMAGE:$KSM_VERSION

for arch in $ALL_ARCH; do
    docker rmi $REPO/kube-state-metrics:$KSM_VERSION-$arch
done

popd
#-------------------------------------------------------------------------------
# Prometheus-operator
IMAGE=carlosedp/prometheus-operator
ALL_ARCH=(amd64 arm arm64 ppc64le)

rm -rf $GOPATH/src/github.com/coreos/prometheus-operator
mkdir -p $GOPATH/src/github.com/coreos/
pushd $GOPATH/src/github.com/coreos/
git clone https://github.com/coreos/prometheus-operator -b $PROM_OP_VERSION --depth=1
cd prometheus-operator

for arch in $ALL_ARCH; do
    if [[ $arch == "arm" ]]; then archdocker="arm32v7";
    elif [[ $arch == "arm64" ]]; then archdocker="arm64v8";
    else archdocker="$arch"; fi

    cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e "s/^FROM.*/FROM $archdocker\/busybox/" > Dockerfile.custom
    CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -ldflags="-s -X github.com/coreos/prometheus-operator/pkg/version.Version=$(cat VERSION | tr -d " \t\n\r")" -o operator cmd/operator/main.go
    docker build -t $REPO/prometheus-operator:${PROM_OP_VERSION}-$arch -f Dockerfile.custom .
    docker push $REPO/prometheus-operator:$PROM_OP_VERSION-$arch
done


docker manifest create --amend $IMAGE:$PROM_OP_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$PROM_OP_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$PROM_OP_VERSION $IMAGE:$PROM_OP_VERSION-$arch; done
docker manifest push --purge $IMAGE:$PROM_OP_VERSION


for arch in $ALL_ARCH; do
    docker rmi $REPO/prometheus-operator:$PROM_OP_VERSION-$arch
done

rm -rf Dockerfile.custom
popd
#-------------------------------------------------------------------------------
# kube-rbac-proxy
IMAGE=carlosedp/kube-rbac-proxy
ALL_ARCH=(amd64 arm arm64 ppc64le)

rm -rf $GOPATH/src/github.com/brancz/
mkdir -p $GOPATH/src/github.com/brancz/
pushd $GOPATH/src/github.com/brancz/
git clone https://github.com/brancz/kube-rbac-proxy -b $KUBE_RBAC_VERSION --depth=1
cd kube-rbac-proxy

for arch in $ALL_ARCH; do
    if [[ $arch == "arm" ]]; then archdocker="arm32v7";
    elif [[ $arch == "arm64" ]]; then archdocker="arm64v8";
    else archdocker="$arch"; fi
    cat > Dockerfile.custom <<EOF
FROM $archdocker/alpine:3.11
RUN apk add -U --no-cache ca-certificates && rm -rf /var/cache/apk/*
COPY kube-rbac-proxy .
ENTRYPOINT ["./kube-rbac-proxy"]
EXPOSE 8080
EOF
    GOOS=linux GOARCH=$arch make build
    rm -rf kube-rbac-proxy
    mv _output/linux/$arch/kube-rbac-proxy ./kube-rbac-proxy
    docker build -t $IMAGE:$KUBE_RBAC_VERSION-$arch -f Dockerfile.custom .
    docker push $IMAGE:$KUBE_RBAC_VERSION-$arch
done

docker manifest create --amend $IMAGE:$KUBE_RBAC_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$KUBE_RBAC_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$KUBE_RBAC_VERSION $IMAGE:$KUBE_RBAC_VERSION-$arch; done
docker manifest push --purge $IMAGE:$KUBE_RBAC_VERSION

for arch in $ALL_ARCH; do
    docker rmi $IMAGE:$KUBE_RBAC_VERSION-$arch
done

#-------------------------------------------------------------------------------
# prometheus-config-reloader
IMAGE=carlosedp/prometheus-config-reloader
ALL_ARCH=(amd64 arm arm64 ppc64le)

pushd $GOPATH/src/github.com/coreos/prometheus-operator
cd $GOPATH/src/github.com/coreos/prometheus-operator/cmd/prometheus-config-reloader
git checkout ${PROM_CONFIG_RELOADER_VERSION}

for arch in $ALL_ARCH; do
    if [[ $arch == "arm" ]]; then archdocker="arm32v7";
    elif [[ $arch == "arm64" ]]; then archdocker="arm64v8";
    else archdocker="$arch"; fi
    cat Dockerfile | sed -e "s/^FROM.*/FROM $archdocker\/busybox/" > Dockerfile.custom
    GOOS=linux GOARCH=$arch CGO_ENABLED=0 go build -a -installsuffix cgo -ldflags '-s -w -extldflags "-static"' -o prometheus-config-reloader main.go
    docker build -t $IMAGE:$PROM_CONFIG_RELOADER_VERSION-$arch -f Dockerfile.custom .
    docker push $IMAGE:$PROM_CONFIG_RELOADER_VERSION-$arch
done

docker manifest create --amend $IMAGE:$PROM_CONFIG_RELOADER_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$PROM_CONFIG_RELOADER_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$PROM_CONFIG_RELOADER_VERSION $IMAGE:$PROM_CONFIG_RELOADER_VERSION-$arch; done
docker manifest push --purge $IMAGE:$PROM_CONFIG_RELOADER_VERSION

for arch in $ALL_ARCH; do
    docker rmi $IMAGE:$PROM_CONFIG_RELOADER_VERSION-$arch
done

rm -rf Dockerfile.custom

#-------------------------------------------------------------------------------
# configmap-reload
IMAGE=carlosedp/configmap-reload
ALL_ARCH=(amd64 arm arm64 ppc64le)

rm -rf $GOPATH/src/github.com/openshift/configmap-reload
mkdir -p $GOPATH/src/github.com/openshift/
pushd $GOPATH/src/github.com/openshift/
git clone https://github.com/openshift/configmap-reload
cd configmap-reload

for arch in $ALL_ARCH; do
    if [[ $arch == "arm" ]]; then archdocker="arm32v7";
    elif [[ $arch == "arm64" ]]; then archdocker="arm64v8";
    else archdocker="$arch"; fi
    cat > Dockerfile.custom <<EOF
FROM $archdocker/busybox
COPY out/configmap-reload /usr/bin/configmap-reload
ENTRYPOINT ["/usr/bin/configmap-reload"]
EOF
    GOOS=linux GOARCH=$arch make
    docker build -t $IMAGE:$CONFIGMAP_RELOAD_VERSION-$arch -f Dockerfile.custom .
    docker push $IMAGE:$CONFIGMAP_RELOAD_VERSION-$arch
done

docker manifest create --amend $IMAGE:$CONFIGMAP_RELOAD_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$CONFIGMAP_RELOAD_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$CONFIGMAP_RELOAD_VERSION $IMAGE:$CONFIGMAP_RELOAD_VERSION-$arch; done
docker manifest push --purge $IMAGE:$CONFIGMAP_RELOAD_VERSION

for arch in $ALL_ARCH; do
    docker rmi $IMAGE:$CONFIGMAP_RELOAD_VERSION-$arch
done

rm -rf Dockerfile.custom
