
VERSION ?= 0.0.1
IMAGE_TAG_BASE ?= arti.dev.cray.com/rabsw-docker-master-local/mfu

IMG ?= $(IMAGE_TAG_BASE):$(VERSION)

docker-build:
	docker build -t ${IMG} .

docker-push:
	docker push ${IMG}

kind-push:
	kind load docker-image ${IMG}