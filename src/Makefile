# FourK - Concatenative, stack based, Forth like language optimised for 
#        non-interactive 4KB size demoscene presentations.

# Copyright (C) 2009, 2010 Wojciech Meyer, Josef P. Bernhart

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
BIN = bin
SRC = 4k.s
FOURKC = fourkc
REF_SUFFIX = -ref
SRC_FILES = elf.m4 import.m4 macros.m4 dict.m4 prim.s $(SRC)
BOOT_FILES = $(BIN)/boot.4ki
BASIC_FILES = bin/4k-party
PROGRAM = bin/4k
CYGWIN = $(shell \
	if [[ `uname` = "Linux" ]]; then \
		"" \
	else \
		"-DCYGWIN" \
	fi)

$(shell test -e $(BIN) || mkdir $(BIN))

all: basic boot debug

basic: $(BASIC_FILES)
boot: $(BOOT_FILES)
compiler: $(FOURKC)
debug: $(BIN)/4k-debug
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
	gcc -m32 -c -nostdlib $(BIN)/t.s -o $(BIN)/tiny.o
	ld -melf_i386 --oformat binary -Ttext 08048000 $(BIN)/tiny.o -o $@
	cp $@ $(PREFIX)


# $(BIN)/4k: $(SRC_FILES)
# 	m4 -s $(SRC) > $(BIN)/t.s 
# 	./m4patch.pl > $(BIN)/t.P
# 	mv $(BIN)/t.P $(BIN)/t.s
# 	gcc -ggdb3 -nostdlib -ldl $(BIN)/t.s -o $(BIN)/4k
# 	cp $@ $(PREFIX)

$(BIN)/4k-debug: $(SRC_FILES)
	m4 -DDEBUG $(CYWGIN) -s $(SRC) > $(BIN)/t.s 
	./m4patch.pl > $(BIN)/t.P
	mv $(BIN)/t.P $(BIN)/t.S
	gcc -m32 -ggdb3 $(BIN)/t.S -o $(BIN)/4k-debug -lGL -ldl -lsigsegv
	cp $@ $(PREFIX)



# $(BIN)/boot.4ki: $(BASIC_FILES) 
# 	cp ../bootstrap.4k bootstrap.4k
# 	echo "save-image $(BIN)/boot.4ki" >> bootstrap.4k
# 	$(PROGRAM) < /dev/null
# 	cp $@ $(PREFIX)


$(FOURKC): basic boot

.PHONY: clean

clean:
	-rm -f $(BIN)/*


