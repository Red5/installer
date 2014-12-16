VERSION=1.0.0
SOURCE0=red5-$(VERSION).tar.gz
SOURCE1=flash-demos.tar.gz
SOURCE2=red5.init
SPEC=red5.spec
TOPDIR=$(shell pwd)

prepare: $(SPEC)
	mkdir -p BUILD SOURCES SPECS SRPMS RPMS
	cp $(SOURCE0) SOURCES
	cp $(SOURCE1) SOURCES
	cp $(SOURCE2) SOURCES
	cp $(SPEC) SPECS
	sed -i 's;@VERSION@;$(VERSION);' SPECS/$(SPEC)

build: prepare
	rpmbuild -ba --nodeps --define '_topdir $(TOPDIR)' SPECS/$(SPEC)

clean:
	rm -rf SOURCES SPECS RPMS SRPMS BUILD
