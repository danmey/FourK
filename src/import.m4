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
define([K4_IMPORT],
[
ifdef([DEBUG],
[ $1_ptr:	.LONG K4_MANGLE($1)],
[
	divert(1)
	pushl	$ $1_name
	pushl	libc_handle
	K4_PURE_CALL(dlsym)
	add	$ 8,%esp
	mov	%eax,$1_ptr

	divert(2)
$1:
	.BYTE 0xff,0x25
	.LONG $1_ptr
$1_ptr:	      .LONG 0
$1_name:      .ASCIZ	"$1"
	STD_DIVERT
]
)])

define([K4_INIT_IMPORTS],
[
$1:
	ifdef([CYGWIN],[
	call	___getreent
	lea	4(%eax),%ecx
	pushl	%ecx
	popl	stdin_ptr
	lea	8(%eax),%ecx
	pushl	%ecx
	popl	stdout_ptr
	])
	undivert(1)
	ret
	undivert(2)
	ifdef([CYGWIN],[
	stdin_ptr:	.LONG 0
	stdout_ptr: 	.LONG 0
	])
])
