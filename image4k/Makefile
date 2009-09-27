PREFIX := $(shell pwd)
BIN := $(PREFIX)/bin

$(shell test -e $(BIN) || mkdir $(BIN))

$(BIN)/image4k:	image.ml
	ocamlc $< -o $@

.PHONY: clean
clean:
	-rm -f $(BIN)/*
