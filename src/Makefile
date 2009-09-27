PREFIX := $(shell pwd)
SRC = fourk2.S
FILES = macros.m4 dict.m4 $(SRC)
BIN := $(PREFIX)/bin

$(shell test -e $(BIN) || mkdir $(BIN))

$(BIN)/fourk $(BIN)/fourk-ref $(BIN)/fourk-debug: $(FILES)
	m4 -s $(SRC) > t.S 
	gcc -ldl t.S -o $(BIN)/fourk
	gcc -gdb3 -ldl -DDEBUG t.S -o $(BIN)/fourk-debug
	gcc -DREFERENCE -ldl t.S -o $(BIN)/fourk-ref
	-rm t.S

.PHONY: clean

clean:
	-rm -f $(BIN)/*

