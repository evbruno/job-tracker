# ex_wallet_api: build, run and ship the progress API.
#
#   make build                  # go binary in ./bin
#   make run                    # go run on :$(PORT)
#   make seed [COUNT=10]        # POST sample progress snapshots to :$(PORT)
#   make docker-build           # image for $(PLATFORM), loaded locally
#   make docker-run             # run that image on :$(PORT)
#   make deploy IMAGE=gcr.io/<project>/ex-wallet-api [KUBE_DEPLOYMENT=... KUBE_CONTEXT=... KUBE_NAMESPACE=...]

APP        := job-tracker
IMAGE      ?= job-tracker
REGISTRY   ?= docker.io/educhaos
PLATFORM   ?= linux/arm64
BUILDER    ?= ex-wallet-builder
PORT       ?= 4000
DB_DIR     ?= $(CURDIR)/db_data
API_TOKEN  ?=

# recursive (=) so TAG, defined further down, is picked up
IMAGE_REF   = $(REGISTRY)/$(IMAGE):$(TAG)

GO     ?= go
DOCKER ?= docker

# Provenance stamped into the image (see `make inspect`)
GIT_SHA    := $(shell git rev-parse --short=10 HEAD 2>/dev/null || echo unknown)
GIT_DIRTY  := $(shell test -n "$$(git status --porcelain 2>/dev/null)" && echo -dirty)
GIT_REV    := $(GIT_SHA)$(GIT_DIRTY)
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
TAG        ?= $(GIT_SHA)

# served by GET /api/version
VERSION_PKG := github.com/evbruno/ex_wallet_api/internal/version
LDFLAGS      = -s -w -X $(VERSION_PKG).Revision=$(GIT_REV) -X $(VERSION_PKG).BuildDate=$(BUILD_DATE)

LABELS = --label "org.opencontainers.image.title=$(IMAGE)" \
	--label "org.opencontainers.image.version=$(TAG)" \
	--label "org.opencontainers.image.revision=$(GIT_REV)" \
	--label "org.opencontainers.image.created=$(BUILD_DATE)"

# $(1) is the output flag: --load (local image) or --push (registry).
# The Go build cross-compiles natively ($$BUILDPLATFORM), so no QEMU slowness here.
define docker_build
	$(DOCKER) buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORM) \
		--tag $(IMAGE_REF) \
		$(LABELS) \
		--build-arg GIT_REV=$(GIT_REV) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		$(1) \
		.
endef


.DEFAULT_GOAL := docker-build


# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------

.PHONY: builder
builder: ## Create the buildx builder if it is missing
	@$(DOCKER) buildx inspect $(BUILDER) >/dev/null 2>&1 || \
		$(DOCKER) buildx create --name $(BUILDER) --driver docker-container --bootstrap

.PHONY: docker-build
docker-build: builder ## Build the image (PLATFORM, default linux/arm64) and load it locally
	$(call docker_build,--load)


.PHONY: docker-push
docker-push: docker-build
	@$(DOCKER) push $(IMAGE_REF)
	@echo "pushed $(IMAGE_REF)"

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------

.PHONY: deploy
deploy:
	set -a && . .kamal/secrets && set +a && kamal deploy --version=$(TAG) --skip-push

.PHONY: setup status logs
setup:
	set -a && . .kamal/secrets && set +a && kamal setup

status:
	set -a && . .kamal/secrets && set +a && kamal details

logs:
	set -a && . .kamal/secrets && set +a && kamal app logs -f