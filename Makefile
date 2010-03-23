export PREFIX = $(shell pwd)/bin
SUBDIRS := src \
	image4k
BIN := $(PREFIX)

$(shell test -e $(BIN) || mkdir $(BIN))

all: basic linker compiler debug


compress:
	cp $(BIN)/fourk $(BIN)/4k
	cp unpack.header $(BIN)/4k
	gzip -cn9 $(BIN)/fourk >> $(BIN)/4k
	chmod +x $(BIN)/4k

debug:
	$(MAKE) -C src debug

basic: 
	$(MAKE) -C src basic

4k: 
	$(MAKE) -C src bin/4k

party:
	$(MAKE) -C src party

boot: 
	$(MAKE) -C src boot

linker:
	$(MAKE) -C image4k

compiler: linker

.PHONY: clean
clean:
	$(foreach dir, $(SUBDIRS), $(MAKE) -C $(wildcard $(dir)) clean;)
	-rm -f $(BIN)/*
