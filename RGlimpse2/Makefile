PKGNAME := $(shell sed -n 's/Package: *\([^ ]*\)/\1/p' DESCRIPTION)
PKGVERS := $(shell sed -n 's/Version: *\([^ ]*\)/\1/p' DESCRIPTION)
TARBALL := $(PKGNAME)_$(PKGVERS).tar.gz
JOBS := $(shell Rscript -e 'cores <- parallel::detectCores(logical = FALSE); if (is.na(cores)) cores <- parallel::detectCores(); if (is.na(cores)) cores <- 2L; cat(max(2L, min(8L, cores)))')

all: check

bootstrap:
	Rscript bootstrap.R

genetic-maps:
	Rscript tools/update-genetic-maps.R

genetic-map-audit:
	Rscript tools/check-genetic-maps.R

source-audit: genetic-map-audit
	../patches/check.sh
	Rscript tools/check-source-archive.R

assembly-audit: install
	tools/check-phase-assembly.sh "$$(Rscript -e 'cat(system.file("glimpse2", "bin", package = "$(PKGNAME)"))')" /usr/bin/objdump

rd:
	Rscript -e 'roxygen2::roxygenize(load_code = "source")'

readme:
	Rscript -e 'rmarkdown::render("README.Rmd", output_format = rmarkdown::github_document(html_preview = FALSE), output_file = "README.md", quiet = TRUE)'

pkgdown:
	Rscript -e 'pkgdown::build_site(new_process = FALSE)'

build: bootstrap rd readme source-audit
	R CMD build .

check: build
	R CMD check --no-manual $(TARBALL)

check-cran: build
	R CMD check --as-cran --no-manual $(TARBALL)

install: build
	R CMD INSTALL --preclean $(TARBALL)

test: install
	Rscript -e 'tinytest::test_package("$(PKGNAME)", ncpu = $(JOBS)L)'

clean:
	rm -rf $(TARBALL) $(PKGNAME).Rcheck docs tools/glimpse2-build
	rm -f src/*.o src/*.so src/*.dll src/*.dylib
	rm -f inst/glimpse2/htslib-version
	rm -f inst/glimpse2/bin/GLIMPSE2_*

.PHONY: all bootstrap genetic-maps genetic-map-audit source-audit assembly-audit rd readme pkgdown build check check-cran install test clean
