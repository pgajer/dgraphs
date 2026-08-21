SHELL := /bin/sh

PACKAGE_ROOT := ../..
LIBRARY := $(abspath library)
R_ENV := env R_MAKEVARS_USER=/dev/null R_LIBS=$(LIBRARY)

.PHONY: package-install benchmark render citation-check rj-check audit public-version clean

package-install:
	mkdir -p $(LIBRARY)
	env R_MAKEVARS_USER=/dev/null R CMD INSTALL --library=$(LIBRARY) $(PACKAGE_ROOT)

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

public-version:
	Rscript scripts/check-public-version.R

clean:
	rm -rf build output library
	rm -f dgraphs.R dgraphs.html dgraphs.log dgraphs.pdf dgraphs.tex
	rm -f motivation-letter/motivation-letter.pdf figures/*.pdf figures/*.png
