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

