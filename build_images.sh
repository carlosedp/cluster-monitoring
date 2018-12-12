#!/bin/bash

REPO=carlosedp

AOM_VERSION=2.1
KSM_VERSION=v1.4.0
VERSION=v0.26.0
PROMCONFIGRELOADER_VERSION=v0.20.0

#-------------------------------------------------------------------------------
# Kubernetes addon-resizer
# Retag Addon-resizer google images to have unified manifest on DockerHub
docker pull gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION
docker pull gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION
docker pull gcr.io/google-containers/addon-resizer-amd64:$AOM_VERSION


docker tag gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm64
docker tag gcr.io/google-containers/addon-resizer-amd64:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm64
docker tag gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION $REPO/addon-resizer:$AOM_VERSION-arm

docker push $REPO/addon-resizer:$AOM_VERSION-arm
docker push $REPO/addon-resizer:$AOM_VERSION-arm64
docker push $REPO/addon-resizer:$AOM_VERSION-amd64

manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/addon-resizer:$AOM_VERSION-ARCH --target $REPO/addon-resizer:$AOM_VERSION
manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template $REPO/addon-resizer:$AOM_VERSION-ARCH --target $REPO/addon-resizer:latest

#-------------------------------------------------------------------------------
# Kube-state-metrics

export DOCKER_CLI_EXPERIMENTAL=enabled
IMAGE=carlosedp/kube-state-metrics
ALL_ARCH='amd64 arm arm64'

go get github.com/kubernetes/kube-state-metrics
#mv $HOME/go/src/github.com/kubernetes/kube-state-metrics $HOME/go/src/k8s.io/kube-state-metrics
cd $HOME/go/src/k8s.io/kube-state-metrics
git checkout ${KSM_VERSION}

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm32v6\/alpine:3.7/' > Dockerfile.arm

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm64v8\/alpine:3.7/' > Dockerfile.arm64

GOOS=linux GOARCH=arm go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-arm64  -f Dockerfile.arm64 .

GOOS=linux GOARCH=amd64 go build .
docker build -t $REPO/kube-state-metrics:${KSM_VERSION}-amd64  -f Dockerfile .

docker push $REPO/kube-state-metrics:$KSM_VERSION-arm
docker push $REPO/kube-state-metrics:$KSM_VERSION-arm64
docker push $REPO/kube-state-metrics:$KSM_VERSION-amd64

docker manifest create --amend $IMAGE:$KSM_VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$KSM_VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$KSM_VERSION $IMAGE:$KSM_VERSION-$arch; done
docker manifest push $IMAGE:$KSM_VERSION

#-------------------------------------------------------------------------------
# Prometheus-operator
export DOCKER_CLI_EXPERIMENTAL=enabled
IMAGE=carlosedp/prometheus-operator
ALL_ARCH='amd64 arm arm64'

go get github.com/coreos/prometheus-operator
cd $HOME/go/src/github.com/coreos/prometheus-operator
git checkout ${VERSION}

go get -u github.com/prometheus/promu

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm32v6\/busybox/' > Dockerfile.arm

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm64v8\/busybox/' > Dockerfile.arm64

GOOS=linux GOARCH=arm $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 $GOPATH/bin/promu build --prefix `pwd`
docker build -t $REPO/prometheus-operator:${VERSION}-arm64 -f Dockerfile.arm64 .

docker push $REPO/prometheus-operator:$VERSION-arm
docker push $REPO/prometheus-operator:$VERSION-arm64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push $IMAGE:$VERSION

rm Dockerfile.arm
rm Dockerfile.arm64

#-------------------------------------------------------------------------------
# kube-rbac-proxy
export DOCKER_CLI_EXPERIMENTAL=enabled
IMAGE=carlosedp/kube-rbac-proxy
VERSION=v0.4.0
ALL_ARCH='amd64 arm arm64'

go get github.com/brancz/kube-rbac-proxy
cd $HOME/go/src/github.com/brancz/kube-rbac-proxy
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
FROM alpine:3.8
RUN apk add -U --no-cache ca-certificates && rm -rf /var/cache/apk/*
COPY kube-rbac-proxy .
ENTRYPOINT ["./kube-rbac-proxy"]
EXPOSE 8080
EOF

docker run --rm --privileged multiarch/qemu-user-static:register --reset

wget https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-arm-static
chmod +x qemu-arm-static
GOOS=linux GOARCH=arm go build .
docker build -t $IMAGE:$VERSION-arm -f Dockerfile.arm .

wget https://github.com/multiarch/qemu-user-static/releases/download/v3.0.0/qemu-aarch64-static
chmod +x qemu-aarch64-static
GOOS=linux GOARCH=arm64 go build .
docker build -t $IMAGE:$VERSION-arm64  -f Dockerfile.arm64 .

GOOS=linux GOARCH=amd64 go build .
docker build -t $IMAGE:$VERSION-amd64  -f Dockerfile.amd64 .

docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push $IMAGE:$VERSION

#-------------------------------------------------------------------------------
# prometheus-config-reloader
export DOCKER_CLI_EXPERIMENTAL=enabled
IMAGE=carlosedp/prometheus-config-reloader
VERSION=v0.26.0
ALL_ARCH='amd64 arm arm64'

go get github.com/coreos/prometheus-operator
cd $HOME/go/src/github.com/coreos/prometheus-operator/cmd/prometheus-config-reloader
git checkout ${VERSION}

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm32v6\/busybox/' > Dockerfile.arm

cat Dockerfile |sed -e 's/\.build\/linux-amd64\/operator/operator/' |sed -e 's/^FROM.*/FROM arm64v8\/busybox/' > Dockerfile.arm64

GOOS=linux GOARCH=arm CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $IMAGE:$VERSION-arm -f Dockerfile.arm .

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $IMAGE:$VERSION-arm64 -f Dockerfile.arm64 .

GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o prometheus-config-reloader main.go
docker build -t $IMAGE:$VERSION-amd64 -f Dockerfile .

docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push $IMAGE:$VERSION

rm Dockerfile.arm
rm Dockerfile.arm64

#-------------------------------------------------------------------------------
# configmap-reload
export DOCKER_CLI_EXPERIMENTAL=enabled
IMAGE=carlosedp/configmap-reload
VERSION=v0.2.2
ALL_ARCH='amd64 arm arm64'

go get github.com/openshift/configmap-reload
cd $HOME/go/src/github.com/openshift/configmap-reload
#git checkout ${VERSION}

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

GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build .
docker build -t $IMAGE:$VERSION-amd64 -f Dockerfile.amd64 .

docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-amd64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ALL_ARCH; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push $IMAGE:$VERSION




