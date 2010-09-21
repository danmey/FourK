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
export PREFIX = $(shell pwd)/bin
SUBDIRS := src \
	image4k
BIN := $(PREFIX)

$(shell test -e $(BIN) || mkdir $(BIN))

all: basic linker compiler debug


compress:
	cp $(BIN)/fourk $(BIN)/4k
	cp unpack.header $(BIN)/4k
	gzip -cn9 $(BIN)/fourk >> $(BIN)/4k
	chmod +x $(BIN)/4k

debug:
	$(MAKE) -C src debug

basic: 
	$(MAKE) -C src basic

4k: 
	$(MAKE) -C src bin/4k

party:
	$(MAKE) -C src party

boot: 
	$(MAKE) -C src boot

linker:
	$(MAKE) -C image4k

compiler: linker

.PHONY: clean
clean:
	$(foreach dir, $(SUBDIRS), $(MAKE) -C $(wildcard $(dir)) clean;)
	-rm -f $(BIN)/*
