/* ; factor.asm: Copyright (C) 1999-2001 by Brian Raiter, under the GNU */
/* ; General Public License (version 2 or later). No warranty. */
/* ; */
/* ; To build: */
/* ;	nasm -f bin -o factor factor.asm && chmod +x factor */
/* ; */
/* ; Usage: factor [N]... */
/* ; Prints the prime factors of each N. With no arguments, reads N */
/* ; from standard input. The valid range is 0 <= N < 2^64. */

.code32

.equ	stdin, 0
.equ	stdout, 1
.equ	stderr, 2

/* ; The program's data */

.equ	iobuf_size, 96


/* STRUC data */
/* factor:		resd	2		; number being tested for factorhood */
/* getchar_rel:	resd	1		; pointer to getchar() function */
/* write_rel:	resd	1		; pointer to write() function */
/* buf:		resd	3		; general-purpose numerical buffer */
/* exit_rel:	resd	1		; pointer to _exit() function */
/* iobuf:		resb	iobuf_size	; buffer for I/O */
/* ENDSTRUC */


.org		0x08048000

/* ; The ELF header and the program header table. The last eight bytes */
/* ; of the former coexist with the first eight bytes of the former. */
/* ; The program header table contains three entries. The first is the */
/* ; interpreter pathname, the third is the _DYNAMIC section, and the */
/* ; middle one contains everything in the file. */


.byte 0x7F
.ascii "ELF"

		.byte 	1			# ELFCLASS32
		.byte 	1			# ELFDATA2LSB
		.byte 	1			# EV_CURRENT
		.fill 9	
		.word 	2			# ET_EXEC
		.word 	3			# EM_386
		.long 	1			# EV_CURRENT
		.long 	_start
		.long 	phdrs - $$
		.long 	0
		.long 	0
		.word 	0x34			# sizeof(Elf32_Ehdr)
		.word 	0x20			# sizeof(Elf32_Phdr)
phdrs:
	.long 	3			# PT_INTERP
		.long 	interp - $$
		.long 	interp
		.long 	interp
		.long 	interpsz
		.long 	interpsz
		.long 	4			# PF_R
		.long 	1
		.long 	1			# PT_LOAD
		.long 	0
		.long 	$$
		.long 	$$
		.long 	filesz
		.long 	memsz
		.long 	7			# PF_R | PF_W | PF_X
		.long 	0x1000
		.long 	2			# PT_DYNAMIC
		.long 	dynamic - $$
		.long 	dynamic
		.long 	dynamic
		.long 	dynamicsz
		.long 	dynamicsz
		.long 	6			# PF_R | PF_W
		.long 	4

/* # The hash table. Essentially a formality. The last entry in the hash */
/* # table, a 1, overlaps with the next structure. */

hash:
		.long 	1
		.long 	5
		.long 	4
		.long 	0, 2, 3, 0

/* # The _DYNAMIC section. Indicates the presence and location of the */
/* # dynamic symbol section (and associated string table and hash table) */
/* # and the relocation section. The final DT_NULL entry in the dynamic */
/* # section overlaps with the next structure. */

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
.equ dynamicsz, 	$ - dynamic + 8

/* # The dynamic symbol table. Entries are included for the _DYNAMIC */
/* # section and the three functions imported from libc: getchar(), */
/* # write(), and _exit(). */

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
.equ exit_sym, 	2
		.long 	exit_name
		.long 	0
		.long 	0
		.word 	0x12			# STB_GLOBAL, STT_FUNC
		.word 	0
.equ getchar_sym, 	3
		.long 	getchar_name
		.long 	0
		.long 	0
		.word 	0x22			# STB_WEAK, STT_FUNC
		.word 	0
.equ write_sym, 	4
		.long 	write_name
		.long 	0
		.long 	0
		.word 	0x22			# STB_WEAK, STT_FUNC
		.word 	0

/* # The relocation table. The addresses of the three functions imported */
/* # from libc are stored in the program's data area. */

reltext:
		.long 	dataorg + write_rel
		.byte 	1			# R_386_32
		.byte 	write_sym
		.word 	0
		.long 	dataorg + getchar_rel
		.byte 	1			# R_386_32
		.byte 	getchar_sym
		.word 	0
		.long 	dataorg + exit_rel
		.byte 	1			# R_386_32
		.byte 	exit_sym
		.word 	0
.equ reltextsz, 	$ - reltext

/* # The interpreter pathname. The final NUL byte appears in the next */
/* # section. */

interp:

.byte 	
.ascii "/lib/ld-linux.so.2"

.equ interpsz, 	$ - interp + 1

/* # The string table for the dynamic symbol table. */

dynstr:
		.byte 	0
.equ libc_name, 	$ - dynstr

.byte 	
.ascii "libc.so.6"
.byte 0
.equ dynamic_name, 	$ - dynstr

.byte 	
.ascii "_DYNAMIC"
.byte 0
.equ exit_name, 	$ - dynstr

.byte 	
.ascii "_exit"
.byte 0
.equ getchar_name, 	$ - dynstr

.byte 	
.ascii "getchar"
.byte 0
.equ write_name, 	$ - dynstr

.byte 	
.ascii "write"
.byte 0
.equ dynstrsz, 	$ - dynstr


/* ###;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; */
/* ; */
/* # The program proper */
/* # */



_start:

/* # End of file image. */

.equ filesz, 	$ - $$

.equ dataorg, 	$$ + ((filesz + 16) & ~15)

.equ memsz, 	dataorg + data_size - $$
