# Economic Zones Protocol (HNY v2) - Makefile
FORGE = /workspace/.toolchains/foundry/bin/forge

.PHONY: all build test test-unit test-invariant fmt clean

all: build

build:
	$(FORGE) build

test:
	$(FORGE) test -vvv

test-unit:
	$(FORGE) test --match-path "test/unit/*" -vvv

test-invariant:
	$(FORGE) test --match-path "test/invariants/*" -vvv

fmt:
	$(FORGE) fmt

clean:
	$(FORGE) clean
