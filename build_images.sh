#!/bin/bash

# Retag Addon-resizer google images to have unified manifest on DockerHub
AOM_VERSION=2.1

docker pull gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION
docker pull gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION

docker tag gcr.io/google-containers/addon-resizer-arm64:$AOM_VERSION carlosedp/addon-resizer:$AOM_VERSION-arm64
docker tag gcr.io/google-containers/addon-resizer-arm:$AOM_VERSION carlosedp/addon-resizer:$AOM_VERSION-arm

docker push carlosedp/addon-resizer:$AOM_VERSION-arm
docker push carlosedp/addon-resizer:$AOM_VERSION-arm64

manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template carlosedp/addon-resizer:$AOM_VERSION-ARCH --target carlosedp/addon-resizer:$AOM_VERSION
manifest-tool-linux-arm64 push from-args --platforms linux/arm,linux/arm64 --template carlosedp/addon-resizer:$AOM_VERSION-ARCH --target carlosedp/addon-resizer:latest




