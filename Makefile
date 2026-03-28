# ── Configuration ─────────────────────────────────────────────────────────────
IMAGE_NAME   ?= memos
IMAGE_TAG    ?= local
DEV_PORT     ?= 8081
PROD_PORT    ?= 5230

# ── Development ──────────────────────────────────────────────────────────────

.PHONY: dev
dev: ## Start backend dev server
	go run ./cmd/memos --port $(DEV_PORT)

.PHONY: dev-frontend
dev-frontend: ## Start frontend dev server (Vite, proxies API to backend)
	cd web && pnpm dev

.PHONY: dev-all
dev-all: ## Start both backend and frontend (requires tmux or run in two terminals)
	@echo "Run in separate terminals:"
	@echo "  make dev            # backend on :$(DEV_PORT)"
	@echo "  make dev-frontend   # frontend on :3001 → proxy to :$(DEV_PORT)"

# ── Build ────────────────────────────────────────────────────────────────────

.PHONY: build
build: frontend ## Build Go binary (with embedded frontend)
	go build -trimpath -o build/memos ./cmd/memos

.PHONY: frontend
frontend: ## Build frontend and copy to server/router/frontend/dist
	cd web && pnpm install && pnpm release

.PHONY: extension
extension: ## Build Chrome extension
	cd extension && pnpm install && pnpm build

# ── Docker ───────────────────────────────────────────────────────────────────

.PHONY: docker
docker: ## Build Docker image (full build, no manual steps needed)
	docker build -f scripts/Dockerfile.full -t $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: docker-run
docker-run: ## Run Docker container
	docker run --rm -p $(PROD_PORT):5230 -v ~/.memos:/var/opt/memos $(IMAGE_NAME):$(IMAGE_TAG)

# ── Test ─────────────────────────────────────────────────────────────────────

.PHONY: test
test: ## Run all Go tests
	go test ./...

.PHONY: test-store
test-store: ## Run store tests (all DB drivers)
	go test -v ./store/...

.PHONY: test-server
test-server: ## Run server tests with race detection
	go test -v -race ./server/...

# ── Lint ─────────────────────────────────────────────────────────────────────

.PHONY: lint
lint: lint-backend lint-frontend ## Run all linters

.PHONY: lint-backend
lint-backend: ## Run Go linter
	golangci-lint run

.PHONY: lint-frontend
lint-frontend: ## Run frontend linter (type check + Biome)
	cd web && pnpm lint

.PHONY: lint-fix
lint-fix: ## Auto-fix lint issues
	golangci-lint run --fix
	cd web && pnpm lint:fix

# ── Proto ────────────────────────────────────────────────────────────────────

.PHONY: proto
proto: ## Regenerate protobuf code
	cd proto && buf generate

.PHONY: proto-lint
proto-lint: ## Lint proto files
	cd proto && buf lint && buf format --diff --exit-code

# ── Clean ────────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf build/
	rm -rf server/router/frontend/dist/
	rm -rf web/dist/
	rm -rf extension/dist/

# ── Help ─────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
