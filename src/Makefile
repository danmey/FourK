BIN = bin
SRC = 4k.s
FOURKC = fourkc
REF_SUFFIX = -ref
SRC_FILES = elf.m4 import.m4 macros.m4 dict.m4 prim.s $(SRC)
BOOT_FILES = $(BIN)/boot.4ki
BASIC_FILES = bin/4k bin/4k-party
PROGRAM = bin/4k
$(shell test -e $(BIN) || mkdir $(BIN))

all: basic boot debug

basic: $(BASIC_FILES)
boot: $(BOOT_FILES)
compiler: $(FOURKC)
debug: $(BIN)/4k-debug.exe
party: $(BIN)/4k-party

.PHONY: compress 
compress: 
	cp unpack.header 4k
	gzip -cn9 fourk >> 4k
	chmod +x 4k

$(BIN)/4k-party: $(SRC_FILES)
	m4 -DPARTY -s $(SRC) > $(BIN)/t.s 
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.s
	gcc -c -nostdlib $(BIN)/t.s -o $(BIN)/tiny.o
	ld --oformat binary -Ttext 08048000 $(BIN)/tiny.o -o $@
	cp $@ $(PREFIX)


$(BIN)/4k: $(SRC_FILES)
	m4 -s $(SRC) > $(BIN)/t.s 
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.s
	gcc -ggdb3 -nostdlib -ldl $(BIN)/t.s -o $(BIN)/4k
	cp $@ $(PREFIX)

$(BIN)/4k-debug.exe: $(SRC_FILES)
	m4 -DDEBUG -DCYGWIN -s $(SRC) > $(BIN)/t.S
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.S
	gcc -ggdb3 $(BIN)/t.S -o $(BIN)/4k-debug -ldl -lsigsegv -lc
	cp $@ $(PREFIX)



$(BIN)/boot.4ki: $(BASIC_FILES) 
	cp ../bootstrap.4k bootstrap.4k
	echo "save-image $(BIN)/boot.4ki" >> bootstrap.4k
	$(PROGRAM) < /dev/null
	cp $@ $(PREFIX)


$(FOURKC): basic boot

.PHONY: clean

clean:
	-rm -f $(BIN)/*


