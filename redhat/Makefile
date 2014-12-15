VERSION=
SOURCE0=red5-server-$(VERSION)-RELEASE-server.tar.gz
SOURCE1=red5.init
SPEC=red5.spec
TOPDIR=$(shell pwd)

prepare: $(SPEC)
	mkdir -p BUILD SOURCES SPECS SRPMS RPMS
	cp $(SOURCE0) SOURCES
	cp $(SOURCE1) SOURCES
	cp $(SPEC) SPECS
	sed -i 's;@VERSION@;$(VERSION);' SPECS/$(SPEC)

build: prepare
	rpmbuild -ba --nodeps --define '_topdir $(TOPDIR)' SPECS/$(SPEC)

clean:
	rm -rf SOURCES SPECS RPMS SRPMS BUILD BUILDROOT
