projects = chunk concordance ligate phase split_reference

.PHONY: all $(projects) system clean upstream-patch-audit r-package-bootstrap r-package-source-audit r-package-build r-package-check r-package-pkgdown

all: $(projects)

$(projects):
	$(MAKE) -C $@ $(COMPILATION_ENV)

system: $(addprefix system-,$(projects))
system-%:
	$(MAKE) -C $* system

clean: $(addprefix clean-,$(projects))
clean-%:
	$(MAKE) -C $* clean

upstream-patch-audit:
	./patches/check.sh

r-package-bootstrap:
	$(MAKE) -C RGlimpse2 bootstrap

r-package-source-audit: upstream-patch-audit
	$(MAKE) -C RGlimpse2 source-audit

r-package-build:
	$(MAKE) -C RGlimpse2 build

r-package-check:
	$(MAKE) -C RGlimpse2 check

r-package-pkgdown:
	$(MAKE) -C RGlimpse2 pkgdown
