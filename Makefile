# Copyright 2021-2024 Hewlett Packard Enterprise Development LP
# Other additional copyright holders may be indicated within.
#
# The entirety of this work is licensed under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
#
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# NOTE: git-version-gen will generate a value for VERSION, unless you override it.
IMAGE_TAG_BASE ?= ghcr.io/nearnodeflash/nnf-mfu

# CONTAINER_TOOL defines the container tool to be used for building images.
# Be aware that the target commands are only tested with Docker which is
# scaffolded by default. However, you might want to replace it to use other
# tools. (i.e. podman)
CONTAINER_TOOL ?= docker

# Which tag to pull from the cray lustre source code.
# **Note:** This must also be set in .github/workflows/main.yaml for both
# production and debug docker builds.
CRAY_LUSTRE_VERSION ?= cray-2.15.B19

# Only support linux/amd64 builds. This reduces complexity with installing
# lustre, which is an option enabled for mpifileutils.
PLATFORM ?= linux/amd64

docker-build: VERSION ?= $(shell cat .version)
docker-build: TARGET ?= production
docker-build: .version
	${CONTAINER_TOOL} build --platform=$(PLATFORM) --target $(TARGET) --build-arg LUSTRE_VERSION=${CRAY_LUSTRE_VERSION} -t $(IMAGE_TAG_BASE):$(VERSION) .

docker-build-debug: VERSION ?= $(shell cat .version)
docker-build-debug: TARGET ?= debug
docker-build-debug: IMAGE_TAG_BASE := $(IMAGE_TAG_BASE)-debug
docker-build-debug: .version
	${CONTAINER_TOOL} build --platform=$(PLATFORM) --target $(TARGET) --build-arg LUSTRE_VERSION=${CRAY_LUSTRE_VERSION} -t $(IMAGE_TAG_BASE):$(VERSION) .

docker-push: VERSION ?= $(shell cat .version)
docker-push: .version
	${CONTAINER_TOOL} push $(IMAGE_TAG_BASE):$(VERSION)

docker-push-debug: VERSION ?= $(shell cat .version)
docker-push-debug: IMAGE_TAG_BASE := $(IMAGE_TAG_BASE)-debug
docker-push-debug: .version
	${CONTAINER_TOOL} push $(IMAGE_TAG_BASE):$(VERSION)

kind-push: VERSION ?= $(shell cat .version)
kind-push: .version
	kind load docker-image $(IMAGE_TAG_BASE):$(VERSION)

kind-push-debug: VERSION ?= $(shell cat .version)
kind-push-debug: IMAGE_TAG_BASE := $(IMAGE_TAG_BASE)-debug
kind-push-debug: .version
	kind load docker-image $(IMAGE_TAG_BASE):$(VERSION)

# Let .version be phony so that a git update to the workarea can be reflected
# in it each time it's needed.
.PHONY: .version
.version: ## Uses the git-version-gen script to generate a tag version
	./git-version-gen --fallback `git rev-parse HEAD` > .version

clean:
	rm -f .version
