CR := ghcr.io/red55
IMG := $(CR)/sandbox
VER := latest

QC_IMAGE := ghcr.io/qwenlm/qwen-code:0.14
OC_IMAGE := docker.io/docker/sandbox-templates:opencode-docker

EXTRA_ARGS :=

.PHONY: all base base-opencode base-qwencode golang-opencode golang-qwencode ansible-opencode ansible-qwencode clean prune pull

all: ansible-opencode ansible-qwencode golang-opencode golang-qwencode

pull:
	docker pull $(EXTRA_ARGS) $(OC_IMAGE)
	docker pull $(EXTRA_ARGS) $(QC_IMAGE)
base: base-opencode base-qwencode

base-opencode:
	docker build -t oc-sandbox-base:$(VER) --build-arg IMAGE=$(OC_IMAGE) $(EXTRA_ARGS) base/
	docker build -t opencode-sandbox-base:$(VER) -f base/opencode.Dockerfile $(EXTRA_ARGS) base/

base-qwencode:
	docker build -t qc-sandbox-base:$(VER) --build-arg IMAGE=$(QC_IMAGE) $(EXTRA_ARGS) base/
	docker build -t qwencode-sandbox-base:$(VER) -f base/qwencode.Dockerfile $(EXTRA_ARGS) base/

golang-opencode: base-opencode
	docker build -t $(IMG)-oc-go:$(VER) --build-arg IMAGE=opencode-sandbox-base:$(VER) $(EXTRA_ARGS) golang/
golang-qwencode: base-qwencode
	docker build -t $(IMG)-qc-go:$(VER) --build-arg IMAGE=qwencode-sandbox-base:$(VER) $(EXTRA_ARGS) golang/
ansible-opencode: base-opencode
	docker build -t $(IMG)-oc-ansible:$(VER) --build-arg IMAGE=opencode-sandbox-base:$(VER) $(EXTRA_ARGS) ansible/
ansible-qwencode: base-qwencode
	docker build -t $(IMG)-qc-ansible:$(VER) --build-arg IMAGE=qwencode-sandbox-base:$(VER) $(EXTRA_ARGS) ansible/
clean:
	docker rmi -f $(IMG)-oc-go:$(VER) $(IMG)-qc-go:$(VER) $(IMG)-oc-ansible:$(VER) $(IMG)-qc-ansible:$(VER) \
	opencode-sandbox-base:$(VER) qwencode-sandbox-base:$(VER) \
	qc-sandbox-base:$(VER) oc-sandbox-base:$(VER) \
	|| true
	$(MAKE) prune

prune:
	docker buildx prune -f
	docker image prune -f
