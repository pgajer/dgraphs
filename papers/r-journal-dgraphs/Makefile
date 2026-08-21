SHELL := /bin/sh

PACKAGE_ROOT := ../..
LIBRARY := $(abspath library)
PACKAGE_TARBALL := $(firstword $(wildcard package/dgraphs_*.tar.gz))
R_ENV := env R_MAKEVARS_USER=/dev/null R_LIBS=$(LIBRARY)
PREFLIGHT_ZIP := dist/dgraphs-r-journal-submission-preflight.zip
SUBMISSION_ZIP := dist/dgraphs-r-journal-submission.zip

.PHONY: package-install benchmark render citation-check rj-check audit reproduce \
	public-version submission-zip-preflight submission-zip clean

package-install:
	mkdir -p $(LIBRARY)
	@if [ -n "$(PACKAGE_TARBALL)" ]; then \
		env R_MAKEVARS_USER=/dev/null R CMD INSTALL \
			--library=$(LIBRARY) $(PACKAGE_TARBALL); \
	elif [ -f "$(PACKAGE_ROOT)/DESCRIPTION" ]; then \
		env R_MAKEVARS_USER=/dev/null R CMD INSTALL \
			--library=$(LIBRARY) $(PACKAGE_ROOT); \
	else \
		echo "No dgraphs source package is available." >&2; \
		exit 1; \
	fi

benchmark: package-install
	$(R_ENV) Rscript scripts/generate-results.R

render: package-install
	$(R_ENV) Rscript scripts/render-paper.R

citation-check: render
	python3 scripts/check-citation-verification.py \
		--tex dgraphs.tex \
		--bib RJreferences.bib \
		--html citation_verification.html \
		--log dgraphs.log

rj-check: render
	$(R_ENV) Rscript scripts/run-rjtools-checks.R

audit: citation-check rj-check
	python3 scripts/readiness-scan.py

reproduce: audit

public-version:
	Rscript scripts/check-public-version.R

submission-zip-preflight: audit
	python3 scripts/build-submission-archive.py --output $(PREFLIGHT_ZIP)
	python3 scripts/verify-submission-archive.py $(PREFLIGHT_ZIP)

submission-zip: public-version audit
	python3 scripts/build-submission-archive.py --output $(SUBMISSION_ZIP)
	python3 scripts/verify-submission-archive.py $(SUBMISSION_ZIP)

clean:
	rm -rf build output library dist
	rm -f dgraphs.R dgraphs.html dgraphs.knit.md dgraphs.log dgraphs.pdf dgraphs.tex
	rm -f RJwrapper.brf
	rm -f motivation-letter/motivation-letter.pdf figures/*.pdf figures/*.png
