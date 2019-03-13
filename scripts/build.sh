#!/usr/bin/env bash

if ! [ -x "$(command -v $2)" ]; then
    JSONNET_BIN=jsonnet
    echo "using jsonnet from path"
else
    JSONNET_BIN=$2
    echo "using jsonnet from arg"
fi

# This script uses arg $1 (name of *.jsonnet file to use) to generate the manifests/*.yaml files.

set -e
set -x
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

# Make sure to start with a clean 'manifests' dir
rm -rf manifests
mkdir manifests

# optional, but we would like to generate yaml, not json
$JSONNET_BIN -J vendor -m manifests "${1-example.jsonnet}" | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}

