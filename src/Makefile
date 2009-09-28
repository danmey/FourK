SRC = fourk2.S
SRC_FILES = macros.m4 dict.m4 $(SRC)
BIN = bin
BASIC_FILES = $(BIN)/fourk $(BIN)/fourk-ref 
DEBUG_FILES = $(BIN)/fourk-debug
BOOT_FILES = $(BIN)/boot.4ki $(BIN)/boot-ref.4ki
$(shell test -e $(BIN) || mkdir $(BIN))

all: $(BASIC_FILES) $(DEBUG_FILES)
basic: $(BASIC_FILES)
debug: $(DEBUG_FILES)
boot: $(BOOT_FILES)

$(BIN)/fourk: $(SRC_FILES)
	m4 -s $(SRC) > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc -ldl t.S -o $@
	-rm t.*
	cp $@ $(PREFIX)

$(BIN)/fourk-ref: $(SRC_FILES)
	m4 -s $(SRC) > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc -DREFERENCE -ldl t.S -o $(BIN)/fourk-ref
	cp $@ $(PREFIX)
	-rm -f t.*

$(BIN)/fourk-debug: $(SRC_FILES)
	m4 -s $(SRC) > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc -g3 -ldl -DDEBUG t.S -o $(BIN)/fourk-debug
	cp $@ $(PREFIX)
	-rm -f t.*

$(BIN)/boot.4ki: $(BASIC_FILES)
	cat bootstrap.4k > boot.4k
	echo "save-image $(BIN)/boot.4ki" >> boot.4k
	cat boot.4k | $(BIN)/fourk
	cp $@ $(PREFIX)
	-rm -f boot.4k

$(BIN)/boot-ref.4ki: $(BASIC_FILES)
	cat bootstrap.4k > boot.4k
	echo "save-image $(BIN)/boot-ref.4ki" >> boot.4k
	cat boot.4k | $(BIN)/fourk
	cp $@ $(PREFIX)
	-rm -f boot.4k

.PHONY: clean

clean:
	-rm -f $(BIN)/*

