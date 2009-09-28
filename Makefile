export PREFIX = $(shell pwd)/bin
SUBDIRS := src \
	image4k
BIN := $(PREFIX)

$(shell test -e $(BIN) || mkdir $(BIN))

all: basic debug boot linker

basic: 
	$(MAKE) -C src basic
debug: 
	$(MAKE) -C src debug
boot: 
	$(MAKE) -C src boot

linker:
	$(MAKE) -C image4k


.PHONY: clean
clean:
	$(foreach dir, $(SUBDIRS), $(MAKE) -C $(wildcard $(dir)) clean;)
	-rm -f $(BIN)/*
