JSONNET_FMT := jsonnet fmt -n 2 --max-blank-lines 2 --string-style s --comment-style s

JB_BINARY:=$(GOPATH)/bin/jb

.PHONY: generate vendor fmt manifests

all: generate

generate: manifests

manifests: $(JSONNET)
	rm -rf manifests
	./build.sh main.jsonnet

update:
	jb update

vendor: $(JB_BINARY) jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BINARY) install

fmt:
	find . -name 'vendor' -prune -o -name '*.libsonnet' -o -name '*.jsonnet' -print | xargs -n 1 -- $(JSONNET_FMT) -i

deploy:
	kubectl apply -f ./manifests/
	echo "Will wait 40 seconds to reapply manifests"
	sleep 40
	kubectl apply -f ./manifests/

teardown:
	kubectl delete -f ./manifests/

tar: manifests
	rm -rf manifests.tar
	tar -cf manifests.tar manifests

$(JB_BINARY):
	go get -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb

$(JSONNET):
	go get github.com/google/go-jsonnet/jsonnet
	go get github.com/brancz/gojsontoyaml
