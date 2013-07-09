FETCH_CMD=wget
MASTER_SITE=http://s3.amazonaws.com/percona.com/downloads/community
MYSQL_VERSION=5.5.31
PERCONA_SERVER_VERSION=rel30.3
PERCONA_XTRADB_CLUSTER ?=Percona-XtraDB-Cluster-$(MYSQL_VERSION)
PERCONA_SERVER ?=Percona-Server
DEBUG_DIR ?= $(PERCONA_XTRADB_CLUSTER)-debug
RELEASE_DIR ?= $(PERCONA_XTRADB_CLUSTER)-release
SERIES ?=series

CFLAGS=-fPIC -Wall -O3 -g -static-libgcc -fno-omit-frame-pointer -fno-strict-aliasing
CXXFLAGS=-fno-exceptions -fPIC -Wall -Wno-unused-parameter -fno-implicit-templates -fno-exceptions -fno-rtti -O3 -g -static-libgcc -fno-omit-frame-pointer -fno-strict-aliasing

CFLAGS_RELEASE=$(CFLAGS) -DDBUG_OFF -DMY_PTHREAD_FASTMUTEX=1
CXXFLAGS_RELEASE=$(CXXFLAGS) -DDBUG_OFF -DMY_PTHREAD_FASTMUTEX=1

CMAKE=CC=gcc CXX=gcc cmake $(ADDITIONAL)
ADDITIONAL ?=
CONFIGURE=CFLAGS="-O2 -g -fmessage-length=0 -D_FORTIFY_SOURCE=2" CXXFLAGS="-O2 -g -fmessage-length=0 -D_FORTIFY_SOURCE=2"  LIBS=-lrt ./configure --prefix=/usr/local/$(PERCONA_XTRADB_CLUSTER) --with-plugin-innobase --with-plugin-partition

REVS = $(shell bzr log | grep rev | head -1   )
REV  = $(word 2, $(REVS) )

all: main handlersocket maatkit-udf install-lic
	@echo ""
	@echo "Percona Server source code is ready"
	@echo "Now change directory to $(PERCONA_XTRADB_CLUSTER) define variables as show below"
	@echo ""
	export CFLAGS="-O2 -g -fmessage-length=0 -D_FORTIFY_SOURCE=2"
	export CXXFLAGS="-O2 -g -fmessage-length=0 -D_FORTIFY_SOURCE=2"
	export LIBS=-lrt
	@echo ""
	@echo "and run cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DWITH_EMBEDDED_SERVER=OFF && make all install"
	@echo ""

handlersocket:
	cp -R HandlerSocket-Plugin-for-MySQL $(PERCONA_XTRADB_CLUSTER)/storage
	patch -p1 -d $(PERCONA_XTRADB_CLUSTER)/storage < handlersocket.patch

maatkit-udf:
	cp -R UDF "$(PERCONA_XTRADB_CLUSTER)"
	cd "$(PERCONA_XTRADB_CLUSTER)"/UDF && autoreconf --install

configure: all
	(cd $(PERCONA_XTRADB_CLUSTER); bash BUILD/autorun.sh; $(CONFIGURE))

cmake: cmake_release cmake_debug

cmake_release:
	rm -rf $(RELEASE_DIR)
	(mkdir -p $(RELEASE_DIR); cd $(RELEASE_DIR); CFLAGS="$(CFLAGS_RELEASE)" CXXFLAGS="$(CXXFLAGS_RELEASE)" $(CMAKE) -G "Unix Makefiles" ../$(PERCONA_XTRADB_CLUSTER))

cmake_debug:
	rm -rf $(DEBUG_DIR)
	(mkdir -p $(DEBUG_DIR); cd $(DEBUG_DIR); CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" $(CMAKE) -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Debug -DWITH_DEBUG=ON -DMYSQL_MAINTAINER_MODE=OFF ../$(PERCONA_XTRADB_CLUSTER))

binary:
	(cd $(PERCONA_XTRADB_CLUSTER); CFLAGS="$(CFLAGS_RELEASE)" CXXFLAGS="$(CXXFLAGS_RELEASE)" ${CMAKE} . -DBUILD_CONFIG=mysql_release  \
           -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	   -DCMAKE_INSTALL_PREFIX="/usr/local/$(PERCONA_XTRADB_CLUSTER)-$(REV)" \
           -DFEATURE_SET="community" \
	   -DWITH_EMBEDDED_SERVER=OFF \
           -DCOMPILATION_COMMENT="Percona-Server" \
           -DMYSQL_SERVER_SUFFIX="-$(REV)" )

install-lic: 
	@echo "Installing license files"
	install -m 644 COPYING.* $(PERCONA_XTRADB_CLUSTER)

prepare:
	@echo "Prepare Percona Server sources"
	rm -f $(PERCONA_XTRADB_CLUSTER)
	ln -s $(PERCONA_SERVER) $(PERCONA_XTRADB_CLUSTER)

main: prepare

misc:
	@echo "Installing other files"
	install -m 644 lrusort.py $(PERCONA_XTRADB_CLUSTER)/scripts

clean:
	rm -rf mysql-$(MYSQL_VERSION) $(PERCONA_XTRADB_CLUSTER) $(RELEASE_DIR) $(DEBUG_DIR)