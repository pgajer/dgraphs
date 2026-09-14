.PHONY: build clean-build repo-hygiene
.PHONY: test-quadform

test-quadform:
	Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_dir("tests/testthat", filter="quadform", stop_on_failure=TRUE)'

PKGNAME := $(shell awk '/^Package:/ { print $$2 }' DESCRIPTION)
VERSION := $(shell awk '/^Version:/ { print $$2 }' DESCRIPTION)
TARBALL := build/$(PKGNAME)_$(VERSION).tar.gz

repo-hygiene:
	python3 dev/check-no-manuscripts.py

build: repo-hygiene audit-guides
	@echo "Building $(TARBALL)..."
	@./dev/build-package.sh
	@test -f $(TARBALL)
	@echo "Built $(TARBALL)"

clean-build:
	rm -f $(TARBALL)

.PHONY: test-quadform-fixtures test-quadform-interface
test-quadform-fixtures:
	Rscript --vanilla dev/shared/fixtures/quadform_geodesics/verify.R --self-test
test-quadform-interface:
	Rscript --vanilla dev/shared/benchmarks/quadform_geodesics/tests.R
	Rscript --vanilla dev/shared/benchmarks/quadform_geodesics/tests_runtime.R
	Rscript --vanilla dev/shared/benchmarks/quadform_geodesics/tests_regressions.R

.PHONY: document audit-guides preview-guides validate-guides check

document:
	Rscript --vanilla -e 'roxygen2::roxygenise(".")'

audit-guides:
	Rscript --vanilla dev/audit-api-guide.R

validate-guides:
	Rscript --vanilla dev/validate-installed-guides.R
	python3 dev/audit-vignette-html.py

preview-guides:
	Rscript --vanilla dev/render-guides.R

check: build
	cd build && R_TIDYCMD="$${R_TIDYCMD:-$$(command -v tidy)}" R_PROFILE_USER="$(CURDIR)/dev/check-profile.R" R CMD check --as-cran $(PKGNAME)_$(VERSION).tar.gz
