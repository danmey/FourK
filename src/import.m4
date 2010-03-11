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
