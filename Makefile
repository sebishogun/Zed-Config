BIN := bin/dotfiles

.PHONY: help install zed jetbrains vscode nvim dry build fmt vet clean

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | sort

install: ## Set up ALL editors (zed, jetbrains, vscode, nvim) — idempotent
	go run ./installer

zed: ## Only Zed
	go run ./installer -only zed

jetbrains: ## Only JetBrains (~/.ideavimrc; IDEA, GoLand, ...)
	go run ./installer -only jetbrains

vscode: ## Only VSCode family (Code/Cursor/Windsurf/Antigravity/VSCodium)
	go run ./installer -only vscode

nvim: ## Only Neovim config
	go run ./installer -only nvim

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
