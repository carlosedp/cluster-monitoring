GOPATH = $(shell go env GOPATH)

JSONNET_BIN := $(GOPATH)/bin/jsonnet
JB_BINARY := $(GOPATH)/bin/jb

JSONNET_FMT := $(GOPATH)/bin/jsonnetfmt -n 2 --max-blank-lines 2 --string-style s --comment-style s

GO_MAJOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f1)
GO_MINOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f2)
MINIMUM_SUPPORTED_GO_MAJOR_VERSION = 1
MINIMUM_SUPPORTED_GO_MINOR_VERSION = 18
GO_VERSION_VALIDATION_ERR_MSG = Your golang version, $(GO_MAJOR_VERSION).$(GO_MINOR_VERSION), is not supported, \
								please update to at least $(MINIMUM_SUPPORTED_GO_MAJOR_VERSION).$(MINIMUM_SUPPORTED_GO_MINOR_VERSION).

.PHONY: generate vendor fmt manifests help

all: manifests       ## Builds the  manifests

help:	# Show help
	@echo "Makefile targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

manifests: $(JSONNET_BIN)       ## Builds the  manifests
	rm -rf manifests
	./scripts/build.sh main.jsonnet $(JSONNET_BIN)

docker:        ## Builds the manifests in a Docker container to avoid installing pre-requisites (Golang, Jsonnet, etc)
	docker run -it --rm -v $(PWD):/work -w /work --rm golang bash -c "make vendor && make"

update_libs: $(JB_BINARY)        ## Updates vendor libs. Require a regeneration of the manifests
	$(JB_BINARY) update

vendor: validate-go-version $(JB_BINARY) jsonnetfile.json jsonnetfile.lock.json       ## Download vendor libs
	rm -rf vendor
	$(JB_BINARY) install

fmt:        ## Formats all jsonnet and libsonnet files (except on vendor dir)
	@echo "Formatting jsonnet files"
	@find . -type f \( -iname "*.libsonnet" -or -iname "*.jsonnet" \) -print -or -name "vendor" -prune | xargs -n 1 -- $(JSONNET_FMT) -i

deploy:        ## Deploy current manifests to configured cluster
	echo "Deploying stack setup manifests..."
	kubectl apply -f ./manifests/setup/
	echo "Will wait 10 seconds to deploy the additional manifests.."
	sleep 10
	kubectl apply -f ./manifests/

teardown:        ## Delete all monitoring stack resources from configured cluster
	kubectl delete -f ./manifests/
	kubectl delete -f ./manifests/setup/

tar: manifests        ## Generates a .tar.gz from manifests dir
	rm -rf manifests.tar.gz
	tar -cfz manifests.tar.gz manifests

$(JB_BINARY):        ## Installs jsonnet-bundler utility
	@echo "Installing jsonnet-bundler"
	@go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest

$(JSONNET_BIN):        ## Installs jsonnet and jsonnetfmt utility
	@echo "Installing jsonnet"
	@go install github.com/google/go-jsonnet/cmd/jsonnet@latest
	@go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
	@go install github.com/brancz/gojsontoyaml@latest

update_tools:        ## Updates jsonnet, jsonnetfmt and jb utilities
	@echo "Updating jsonnet"
	@go install github.com/google/go-jsonnet/cmd/jsonnet@latest
	@go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
	@go install github.com/brancz/gojsontoyaml@latest
	@go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest

change_suffix:        ## Changes suffix for the ingress. Pass suffix=[suffixURL] as argument
	@echo "Ingress IPs changed to [service].${suffix}"
	@echo "Apply to your cluster with:"
	@for f in alertmanager prometheus grafana; do \
		cat manifests/ingress-$$f.yaml | sed -e "s/\(.*$$f\.\).*/\1${suffix}/" > manifests/ingress-$$f.yaml-tmp; \
		mv -f manifests/ingress-$$f.yaml-tmp manifests/ingress-$$f.yaml; \
		echo ${K3S} kubectl apply -f manifests/ingress-$$f.yaml; \
	done

validate-go-version:  ## Validates the installed version of go to allow the `go install` syntax needed for `make vendor`
	@if [ $(GO_MAJOR_VERSION) -lt $(MINIMUM_SUPPORTED_GO_MAJOR_VERSION) -o $(GO_MINOR_VERSION) -lt $(MINIMUM_SUPPORTED_GO_MINOR_VERSION) ]; then \
    	echo '$(GO_VERSION_VALIDATION_ERR_MSG)'; \
    	exit 1; \
	fi