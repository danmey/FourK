PREFIX := $(shell pwd)
SUBDIRS := src \
	image4k
BIN := $(PREFIX)/bin

$(shell test -e $(BIN) || mkdir $(BIN))

all:
	$(foreach dir, $(SUBDIRS), \
		$(MAKE) -C $(wildcard $(dir)); \
		cp $(dir)/bin/* bin;)


.PHONY: clean
clean:
	$(foreach dir, $(SUBDIRS), $(MAKE) -C $(wildcard $(dir)) clean;)
	-rm -f $(BIN)/*
