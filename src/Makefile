BIN = bin
SRC = 4k.s
FOURKC = fourkc
REF_SUFFIX = -ref
SRC_FILES = elf.m4 import.m4 macros.m4 dict.m4 prim.s $(SRC)
BOOT_FILES = $(BIN)/boot.4ki $(BIN)/boot$(REF_SUFFIX).4ki
PROGRAM = $(BIN)/4k
BASIC_FILES = $(PROGRAM) $(PROGRAM)$(REF_SUFFIX)

$(shell test -e $(BIN) || mkdir $(BIN))

all: basic boot debug

basic: $(BASIC_FILES)
boot: $(BOOT_FILES)
compiler: $(FOURKC)
debug: $(BIN)/4k-debug

.PHONY: compress 
compress: 
	cp unpack.header 4k
	gzip -cn9 fourk >> 4k
	chmod +x 4k

$(PROGRAM): $(SRC_FILES)
	m4 -s $(SRC) > $(BIN)/t.s 
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.s
	gcc -c -nostdlib $(BIN)/t.s -o $(BIN)/tiny.o
	ld --oformat binary -Ttext 08048000 $(BIN)/tiny.o -o $@
	cp $@ $(PREFIX)

$(BIN)/4k-debug: $(SRC)
	m4 -DDEBUG -s $(SRC) > $(BIN)/t.s 
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.s
	gcc -ldl -nostdlib $(BIN)/t.s -o $@
	cp $@ $(PREFIX)

$(PROGRAM)$(REF_SUFFIX): $(SRC_FILES)
	m4 -s $(SRC) > $(BIN)/t.s 
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.s
	gcc -c -nostdlib $(BIN)/t.s -o $(BIN)/tiny.o
	ld --oformat binary -Ttext 9149000 $(BIN)/tiny.o -o $@
	cp $@ $(PREFIX)

$(BIN)/boot.4ki: $(BASIC_FILES) bootstrap.4k
	cp bootstrap.4k $(BIN)/boot.4k
	echo "save-image $(BIN)/boot.4ki" >> $(BIN)/boot.4k
	$(PROGRAM) < $(BIN)/boot.4k
	cp $@ $(PREFIX)

$(BIN)/boot$(REF_SUFFIX).4ki: $(BASIC_FILES) bootstrap.4k
	cp bootstrap.4k $(BIN)/boot.4k
	echo "save-image $(BIN)/boot$(REF_SUFFIX).4ki" >> $(BIN)/boot.4k
	$(PROGRAM)$(REF_SUFFIX) < $(BIN)/boot.4k
	cp $@ $(PREFIX)

$(FOURKC): basic boot

.PHONY: clean

clean:
	-rm -f $(BIN)/*


