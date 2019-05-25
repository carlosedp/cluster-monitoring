JSONNET_FMT := jsonnet fmt -n 2 --max-blank-lines 2 --string-style s --comment-style s

JSONNET_BIN := $(GOPATH)/bin/jsonnet
JB_BINARY := $(GOPATH)/bin/jb

.PHONY: generate vendor fmt manifests

all: manifests

manifests: jsonnet
	rm -rf manifests
	./scripts/build.sh main.jsonnet $(JSONNET_BIN)

update: jsonnet_bundler
	jb update

vendor: jsonnet_bundler jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BINARY) install

fmt:
	find . -name 'vendor' -prune -o -name '*.libsonnet' -o -name '*.jsonnet' -print | xargs -n 1 -- $(JSONNET_FMT) -i

deploy: manifests
	kubectl apply -f ./manifests/
	echo "Will wait 40 seconds to reapply manifests"
	sleep 40
	kubectl apply -f ./manifests/

teardown:
	kubectl delete -f ./manifests/

tar: manifests
	rm -rf manifests.tar
	tar -cf manifests.tar manifests

jsonnet_bundler:
ifeq (, $(shell which jb))
	@echo "Installing jsonnet-bundler"
	@go get -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
endif

jsonnet:
ifeq (, $(shell which jsonnet))
	@echo "Installing jsonnet"
	@go get github.com/google/go-jsonnet/cmd/jsonnet
	@go get github.com/brancz/gojsontoyaml
endif
