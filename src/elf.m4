########################################################################
# FourK - Concatenative, stack based, Forth like language optimised for 
#        non-interactive 4KB size demoscene presentations.
#
# Copyright (C) 2009, 2010, 2011 Wojciech Meyer, Josef P. Bernhart
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
########################################################################



define([STD_DIVERT], [divert(0)])
define([SECTION], [
 	.equ sec_$1, . - _image_start
 	divert(6)
	.ASCII "$1"
	.FILL eval(24 - len($1))
	.LONG 0	      # offset
 	.LONG sec_$1  # section offset
	divert
])

define([ELF_HEADER],[

# factor.asm: Copyright (C) 1999-2001 by Brian Raiter, under the GNU
# General Public License (version 2 or later). No warranty.
#
# To build:
#	nasm -f bin -o factor factor.asm && chmod +x factor
#
# Usage: factor [N]...
# Prints the prime factors of each N. With no arguments, reads N
# from standard input. The valid range is 0 <= N < 2^64.

.code32


# The program's data

beg:


# The ELF header and the program header table. The last eight bytes
# of the former coexist with the first eight bytes of the former.
# The program header table contains three entries. The first is the
# interpreter pathname, the third is the _DYNAMIC section, and the
# middle one contains everything in the file.

.byte 0x7F
.ascii "ELF"

		.byte 	1			# ELFCLASS32
		.byte 	1			# ELFDATA2LSB
		.byte 	1			# EV_CURRENT
		.fill  9
		.word 	2			# ET_EXEC
		.word 	3			# EM_386
		.long 	1			# EV_CURRENT
		.long 	_start
		.long 	phdrs - beg
		.long 	0
		.long 	0
		.word 	0x34			# sizeof(Elf32_Ehdr)
		.word 	0x20			# sizeof(Elf32_Phdr)
phdrs:
		.long 	3			# PT_INTERP
		.long 	interp - beg
		.long 	interp
		.long 	interp
		.long 	interpsz
		.long 	interpsz
		.long 	4			# PF_R
		.long 	1
		.long 	1			# PT_LOAD
		.long 	0
		.long 	beg
		.long 	beg
		.long 	filesz
		.long 	memsz
		.long 	7			# PF_R | PF_W | PF_X
		.long 	0x1000
		.long 	2			# PT_DYNAMIC
		.long 	dynamic - beg
		.long 	dynamic
		.long 	dynamic
		.long 	dynamicsz
		.long 	dynamicsz
		.long 	6			# PF_R | PF_W
		.long 	4


# The hash table. Essentially a formality. The last entry in the hash
# table, a 1, overlaps with the next structure.

hash:
		.long 	1
		.long 	5
		.long 	4
		.long 	0, 2, 3, 0


# The _DYNAMIC section. Indicates the presence and location of the
# dynamic symbol section (and associated string table and hash table)
# and the relocation section. The final DT_NULL entry in the dynamic
# section overlaps with the next structure.

dynamic:
		.long 	1,  libc_name		# DT_NEEDED
		.long 	4,  hash		# DT_HASH
		.long 	5,  dynstr		# DT_STRTAB
		.long 	6,  dynsym		# DT_SYMTAB
		.long 	10, dynstrsz		# DT_STRSZ
		.long 	11, 0x10		# DT_SYMENT
		.long 	17, reltext		# DT_REL
		.long 	18, reltextsz		# DT_RELSZ
		.long 	19, 0x08		# DT_RELENT
.equ dynamicsz, 	. - dynamic + 8


# The dynamic symbol table. Entries are included for the _DYNAMIC
# section and the three functions imported from libc: getchar(),
# write(), and _exit().

dynsym:
		.long 	0
		.long 	0
		.long 	0
		.word 	0
		.word 	0

.equ dynamic_sym, 	1
		.long 	dynamic_name
		.long 	dynamic
		.long 	0
		.word 	0x11			# STB_GLOBAL, STT_OBJECT
		.word 	0xFFF1			# SHN_ABS

.equ dlopen_sym, 	2
		.long 	dlopen_name
		.long 	0
		.long 	0
		.word 	0x22			# STB_GLOBAL, STT_FUNC
		.word 	0

.equ dlsym_sym, 	3
		.long 	dlsym_name
		.long 	0
		.long 	0
		.word 	0x22			# STB_WEAK, STT_FUNC
		.word 	0

		.byte 	0


# The relocation table. The addresses of the three functions imported
# from libc are stored in the program's data area.

reltext:
		.long 	dlopen_
		.byte 	1			# R_386_32
		.byte 	dlopen_sym
		.word 	0

		.long 	dlsym_
		.byte 	1			# R_386_32
		.byte 	dlsym_sym
		.word 	0

.equ reltextsz, 	. - reltext


# The interpreter pathname. The final NUL byte appears in the next
# section.

interp:

.byte
.ascii "/lib/ld-linux.so.2"

.equ interpsz, 	. - interp + 1


# The string table for the dynamic symbol table.
dynstr:
		.byte 	0
.equ libc_name, 	. - dynstr

.asciz "libdl.so.2"
.equ dynamic_name, 	. - dynstr

.asciz "_DYNAMIC"
.equ dlopen_name, 	. - dynstr

.asciz "__gmon_start__"
.asciz "_Jv_RegisterClasses"

.asciz "dlopen"
.equ dlsym_name, 	. - dynstr

.asciz "dlsym"
.equ dynstrsz, 	. - dynstr


# End of file image.
_code_start:


])
define([ELF_SECTION_TAB_OFFSET],
[
	.long _section_tab
])


define([ELF_CODE_END],
[
_section_tab:
	undivert(6)
	.long 0x0
])


define([ELF_DATA_END],
[
	.equ filesz, 	. - beg

.equ dataorg, 	beg + ((filesz + 16) & ~15)

.equ memsz, 	0xF000+dataorg - beg
])
