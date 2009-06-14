handler_continuation:
	subl	$20, %esp
	pushl	$0
	pushl	$mainloop
	call	longjmp
.LC0:
	.string	"wb"
.LC1:
	.string	"image.fi"
dump_image:
	pushl	%ebx
	subl	$16, %esp
	pushl	$.LC0
	pushl	$.LC1
	call	fopen
	pushl	%eax
	movl	%eax, %ebx
	movl	$Vm_image_end, %eax
	pushl	$1
	subl	$Vm_image_start, %eax
	pushl	%eax
	pushl	$Vm_image_start
	call	fwrite
	addl	$20, %esp
	pushl	%ebx
	call	fclose
	addl	$24, %esp
	popl	%ebx
	ret
.LC2:
	.string	"***Exception: Word to long. Truncating.."
.LC3:
	.string	"***Exception: Word '%s' not found..\n"
kernel_exception_handler:
	subl	$12, %esp
	movl	16(%esp), %edx
	movl	48(%edx), %eax
	cmpl	$2, %eax
	je	.L7
	cmpl	$3, %eax
	jne	.L10
	movl	$.LC2, 16(%esp)
	addl	$12, %esp
	jmp	puts
.L7:
	pushl	%eax
	pushl	52(%edx)
	pushl	$.LC3
	pushl	$1
	call	__printf_chk
	addl	$16, %esp
.L10:
	addl	$12, %esp
	ret
.LC4:
	.string	"Warning: "
.LC5:
	.string	"Line exceeded %d characters. Truncated."
just_one_line:
	pushl	%ebp
	xorl	%edx, %edx
	pushl	%edi
	pushl	%esi
	pushl	%ebx
	xorl	%ebx, %ebx
	subl	$12, %esp
	movl	36(%esp), %edi
	movl	32(%esp), %ebp
	movl	40(%esp), %esi
	subl	$2, %edi
	jmp	.L12
.L15:
	movb	%dl, (%esi,%ebx)
	movl	%eax, %ebx
.L12:
	cmpl	%edi, %ebx
	jge	.L13
	subl	$12, %esp
	pushl	%ebp
	call	fgetc
	addl	$16, %esp
	cmpl	$-1, %eax
	movl	%eax, %edx
	je	.L14
	cmpl	$10, %eax
	leal	1(%ebx), %eax
	jne	.L15
	jmp	.L21
.L13:
	jne	.L14
	cmpl	$-1, %edx
	je	.L14
	pushl	%edx
	pushl	%edx
	pushl	stderr
	pushl	$.LC4
	call	fputs
	pushl	%ebx
	pushl	$.LC5
	pushl	$1
	pushl	stderr
	call	__fprintf_chk
	movl	$-2, %eax
	addl	$32, %esp
	jmp	.L17
.L14:
	orl	$-1, %eax
	incl	%edx
	movb	$0, (%esi,%ebx)
	je	.L17
	leal	1(%ebx), %eax
.L17:
	addl	$12, %esp
	popl	%ebx
	popl	%esi
	popl	%edi
	popl	%ebp
	ret
.L21:
	movb	$10, (%esi,%ebx)
	movl	%eax, %ebx
	jmp	.L14
run_repl:
	subl	$24, %esp
	pushl	$mainloop
	call	_setjmp
	addl	$16, %esp
	testl	%eax, %eax
	js	.L23
	cmpl	$1, %eax
	jle	.L24
	cmpl	$2, %eax
	jne	.L23
	jmp	.L28
.L24:
	call	Vm_reset
	jmp	.L31
.L27:
	subl	$12, %esp
	pushl	$line.2467
	call	Vm_eval
	addl	$16, %esp
	cmpl	$0, Vm_Save_image
	je	.L31
	movl	$0, Vm_Save_image
	call	dump_image
.L31:
	pushl	%ecx
	pushl	$line.2467
	pushl	$256
	pushl	stdin
	call	just_one_line
	addl	$16, %esp
	incl	%eax
	jne	.L27
	jmp	.L28
.L23:
	call	abort
.L28:
	addl	$12, %esp
	ret
_start:
	subl	$12, %esp
	call	run_repl
	xorl	%eax, %eax
	addl	$12, %esp
	ret
	.local	line.2467
	.comm	line.2467,257,4
	.comm	opts,8,4
	.comm	mainloop,156,4
