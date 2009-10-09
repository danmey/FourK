SRC = fourk2.S
FOURKC = fourkc
SRC_FILES = macros.m4 dict.m4 prim.S $(SRC)
BIN = bin
BASIC_FILES = $(BIN)/fourk $(BIN)/fourk-ref 
DEBUG_FILES = $(BIN)/fourk-debug
BOOT_FILES = $(BIN)/boot.4ki $(BIN)/boot-ref.4ki $(BIN)/boot-tiny.4ki
$(shell test -e $(BIN) || mkdir $(BIN))

all: basic debug boot tiny
basic: $(BASIC_FILES)
debug: $(DEBUG_FILES)
boot: $(BOOT_FILES)
compiler: $(FOURKC)
tiny: $(BIN)/tiny

.PHONY: compress 
compress: 
	cp unpack.header 4k
	gzip -cn9 fourk >> 4k
	chmod +x 4k

$(BIN)/tiny: tiny.S
	m4 -s tiny.S > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc -c -nostdlib -DTINY t.S -o tiny.o
	ld --oformat binary -Ttext 08048000 tiny.o -o $@
	cp $@ $(PREFIX)

$(BIN)/fourk: $(SRC_FILES)
	m4 -s $(SRC) > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc -O1 -nostdlib -ffast-math -fomit-frame-pointer -DPARTY -c t.S -o t.o
	ld -dynamic-linker  /lib/ld-linux.so.2 /usr/lib/libdl.so t.o  -o $@
#	strip -s -R .comment -R .gnu.version $@
#	../tools/sstrip $@

#	-rm t.*
	cp $@ $(PREFIX)

$(BIN)/fourk-ref: $(SRC_FILES)
	m4 -s $(SRC) > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc  -DREFERENCE -O1 -nostdlib -ffast-math -fomit-frame-pointer -DPARTY -c t.S -o t.o
	ld -dynamic-linker  /lib/ld-linux.so.2 /usr/lib/libdl.so t.o  -o $@
	strip -s -R .comment -R .gnu.version $@
	../tools/sstrip $@
	cp $@ $(PREFIX)
#	-rm -f t.*

$(BIN)/fourk-debug: $(SRC_FILES)
	m4 -s $(SRC) > t.S 
	./m4patch.pl > t.P
	mv t.P t.S
	gcc -g3 -ldl -DDEBUG t.S -o $@
	cp $@ $(PREFIX)
#	-rm -f t.*

$(BIN)/boot.4ki: $(BASIC_FILES) bootstrap.4k
	cat bootstrap.4k > boot.4k
	echo "save-image $(BIN)/boot.4ki" >> boot.4k
	cat boot.4k | $(BIN)/fourk
	cp $@ $(PREFIX)
#	-rm -f boot.4k

$(BIN)/boot-ref.4ki: $(BASIC_FILES) bootstrap.4k
	cat bootstrap.4k > boot.4k
	echo "save-image $(BIN)/boot-ref.4ki" >> boot.4k
	cat boot.4k | $(BIN)/fourk-ref
	cp $@ $(PREFIX)
 #      -rm -f boot.4k

$(BIN)/boot-tiny.4ki: $(BIN)/tiny bootstrap.4k
	cat bootstrap.4k > boot.4k
	echo "save-image $(BIN)/boot-tiny.4ki" >> boot.4k
	cat boot.4k | $(BIN)/tiny
	cp $@ $(PREFIX)
#	-rm -f boot.4k

$(FOURKC): basic boot

.PHONY: clean

clean:
	-rm -f $(BIN)/*
	-rm t.S
	-rm tiny.o
	-rm t.o


