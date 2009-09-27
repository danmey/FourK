;; factor.asm: Copyright (C) 1999-2001 by Brian Raiter, under the GNU
;; General Public License (version 2 or later). No warranty.
;;
;; To build:
;;	nasm -f bin -o factor factor.asm && chmod +x factor
;;
;; Usage: factor [N]...
;; Prints the prime factors of each N. With no arguments, reads N
;; from standard input. The valid range is 0 <= N < 2^64.

BITS 32

%define	stdin		0
%define	stdout		1
%define	stderr		2

;; The program's data

%define	iobuf_size	96


;STRUC data
;factor:		resd	2		; number being tested for factorhood
;getchar_rel:	resd	1		; pointer to getchar() function
;write_rel:	resd	1		; pointer to write() function
;buf:		resd	3		; general-purpose numerical buffer
;exit_rel:	resd	1		; pointer to _exit() function
;iobuf:		resb	iobuf_size	; buffer for I/O
;ENDSTRUC


		org	0x08048000

;; The ELF header and the program header table. The last eight bytes
;; of the former coexist with the first eight bytes of the former.
;; The program header table contains three entries. The first is the
;; interpreter pathname, the third is the _DYNAMIC section, and the
;; middle one contains everything in the file.

		db	0x7F, 'ELF'
		db	1			; ELFCLASS32
		db	1			; ELFDATA2LSB
		db	1			; EV_CURRENT
	times 9	db	0
		dw	2			; ET_EXEC
		dw	3			; EM_386
		dd	1			; EV_CURRENT
		dd	_start
		dd	phdrs - $$
		dd	0
		dd	0
		dw	0x34			; sizeof(Elf32_Ehdr)
		dw	0x20			; sizeof(Elf32_Phdr)
phdrs:		dd	3			; PT_INTERP
		dd	interp - $$
		dd	interp
		dd	interp
		dd	interpsz
		dd	interpsz
		dd	4			; PF_R
		dd	1
		dd	1			; PT_LOAD
		dd	0
		dd	$$
		dd	$$
		dd	filesz
		dd	memsz
		dd	7			; PF_R | PF_W | PF_X
		dd	0x1000
		dd	2			; PT_DYNAMIC
		dd	dynamic - $$
		dd	dynamic
		dd	dynamic
		dd	dynamicsz
		dd	dynamicsz
		dd	6			; PF_R | PF_W
		dd	4

;; The hash table. Essentially a formality. The last entry in the hash
;; table, a 1, overlaps with the next structure.

hash:
		dd	1
		dd	5
		dd	4
		dd	0, 2, 3, 0

;; The _DYNAMIC section. Indicates the presence and location of the
;; dynamic symbol section (and associated string table and hash table)
;; and the relocation section. The final DT_NULL entry in the dynamic
;; section overlaps with the next structure.

dynamic:
		dd	1,  libc_name		; DT_NEEDED
		dd	4,  hash		; DT_HASH
		dd	5,  dynstr		; DT_STRTAB
		dd	6,  dynsym		; DT_SYMTAB
		dd	10, dynstrsz		; DT_STRSZ
		dd	11, 0x10		; DT_SYMENT
		dd	17, reltext		; DT_REL
		dd	18, reltextsz		; DT_RELSZ
		dd	19, 0x08		; DT_RELENT
dynamicsz	equ	$ - dynamic + 8

;; The dynamic symbol table. Entries are included for the _DYNAMIC
;; section and the three functions imported from libc: getchar(),
;; write(), and _exit().

dynsym:
		dd	0
		dd	0
		dd	0
		dw	0
		dw	0
dynamic_sym	equ	1
		dd	dynamic_name
		dd	dynamic
		dd	0
		dw	0x11			; STB_GLOBAL, STT_OBJECT
		dw	0xFFF1			; SHN_ABS
exit_sym	equ	2
		dd	exit_name
		dd	0
		dd	0
		dw	0x12			; STB_GLOBAL, STT_FUNC
		dw	0
getchar_sym	equ	3
		dd	getchar_name
		dd	0
		dd	0
		dw	0x22			; STB_WEAK, STT_FUNC
		dw	0
write_sym	equ	4
		dd	write_name
		dd	0
		dd	0
		dw	0x22			; STB_WEAK, STT_FUNC
		dw	0

;; The relocation table. The addresses of the three functions imported
;; from libc are stored in the program's data area.

reltext:
		dd	dataorg + write_rel
		db	1			; R_386_32
		db	write_sym
		dw	0
		dd	dataorg + getchar_rel
		db	1			; R_386_32
		db	getchar_sym
		dw	0
		dd	dataorg + exit_rel
		db	1			; R_386_32
		db	exit_sym
		dw	0
reltextsz	equ	$ - reltext

;; The interpreter pathname. The final NUL byte appears in the next
;; section.

interp:
		db	'/lib/ld-linux.so.2'
interpsz	equ	$ - interp + 1

;; The string table for the dynamic symbol table.

dynstr:
		db	0
libc_name	equ	$ - dynstr
		db	'libc.so.6', 0
dynamic_name	equ	$ - dynstr
		db	'_DYNAMIC', 0
exit_name	equ	$ - dynstr
		db	'_exit', 0
getchar_name	equ	$ - dynstr
		db	'getchar', 0
write_name	equ	$ - dynstr
		db	'write', 0
dynstrsz	equ	$ - dynstr


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; The program proper
;;



_start:

;; End of file image.

filesz		equ	$ - $$

dataorg		equ	$$ + ((filesz + 16) & ~15)

memsz		equ	dataorg + data_size - $$
