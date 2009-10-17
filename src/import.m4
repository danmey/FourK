define([K4_IMPORT],
[
	divert(1)
	pushl	$ $1_name
	pushl	libc_handle
	call	dlsym
	add	$ 8,%esp
	mov	%eax,$1_ptr

	divert(2)
$1:
	.BYTE 0xff,0x25
	.LONG $1_ptr
$1_ptr:	      .LONG 0
$1_name:      .ASCIZ	"$1"
	STD_DIVERT
])

define([K4_INIT_IMPORTS],
[
$1:
	undivert(1)
	ret
	undivert(2)
])
