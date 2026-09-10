.PHONY: build clean-build repo-hygiene

PKGNAME := $(shell awk '/^Package:/ { print $$2 }' DESCRIPTION)
VERSION := $(shell awk '/^Version:/ { print $$2 }' DESCRIPTION)
TARBALL := build/$(PKGNAME)_$(VERSION).tar.gz

repo-hygiene:
	python3 dev/check-no-manuscripts.py

build: repo-hygiene
	@echo "Building $(TARBALL)..."
	@./dev/build-package.sh
	@test -f $(TARBALL)
	@echo "Built $(TARBALL)"

clean-build:
	rm -f $(TARBALL)
