BIN := bin/zed-config

.PHONY: help install link dry build fmt vet clean

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | sort

install: ## Detect platform, install Zed if missing, link config (idempotent)
	go run ./installer

link: ## Only (re)link config, never install Zed
	go run ./installer -link-only

dry: ## Show what install would do, change nothing
	go run ./installer -dry-run

build: ## Compile installer to $(BIN)
	go build -o $(BIN) ./installer

fmt: ## gofmt the installer
	gofmt -w ./installer

vet: ## go vet
	go vet ./...

clean: ## Remove build artifacts
	rm -rf bin
