BIN := bin

$(shell test -e $(BIN) || mkdir $(BIN))

$(BIN)/image4k:	image.ml dict.ml
	ocamlc $< -o $@
	cp $@ $(PREFIX)

.PHONY: clean
clean:
	-rm -f $(BIN)/*
