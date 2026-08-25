# Economic Zones Protocol ($HNY v2) - Makefile
FORGE = /workspace/.toolchains/foundry/bin/forge

.PHONY: all build test test-unit test-invariant snapshot snapshot-check fmt clean docs docs-dev build-sdk test-sdk

all: build

build:
	$(FORGE) build --sizes

test:
	$(FORGE) test -vvv

test-unit:
	$(FORGE) test --match-path "test/unit/*" -vvv

test-invariant:
	$(FORGE) test --match-path "test/invariants/*" -vvv

snapshot:
	$(FORGE) snapshot

snapshot-check:
	$(FORGE) snapshot --check

fmt:
	$(FORGE) fmt

fmt-check:
	$(FORGE) fmt --check

build-sdk:
	cd pkg/checkout && bun install && bun run build

test-sdk:
	cd pkg/checkout && bun test

docs:
	bun run docs:build

docs-dev:
	bun run docs:dev

clean:
	$(FORGE) clean
	rm -rf out cache docs/.vitepress/dist docs/.vitepress/cache
