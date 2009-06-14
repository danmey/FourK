.LC0:
	.string	"i:"
.LC1:
	.string	"Non-option argument %s\n"
process_opts:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$40, %esp
	movl	$0, -4(%ebp)
	movl	$0, -8(%ebp)
	movl	$0, -12(%ebp)
	jmp	.L2
.L5:
	movl	-12(%ebp), %eax
	cmpl	$105, %eax
	jne	.L9
.L4:
	movl	optarg, %eax
	movl	%eax, opts+4
	jmp	.L2
.L9:
	call	abort
.L2:
	movl	$.LC0, 8(%esp)
	movl	12(%ebp), %eax
	movl	%eax, 4(%esp)
	movl	8(%ebp), %eax
	movl	%eax, (%esp)
	call	getopt
	movl	%eax, -12(%ebp)
	cmpl	$-1, -12(%ebp)
	jne	.L5
	movl	optind, %eax
	movl	%eax, -16(%ebp)
	jmp	.L6
.L7:
	movl	-16(%ebp), %eax
	sall	$2, %eax
	addl	12(%ebp), %eax
	movl	(%eax), %eax
	movl	%eax, 4(%esp)
	movl	$.LC1, (%esp)
	call	printf
	addl	$1, -16(%ebp)
.L6:
	movl	-16(%ebp), %eax
	cmpl	8(%ebp), %eax
	jl	.L7
	movl	$0, %eax
	leave
	ret
.LC2:
	.string	"Error: mprotect"
enable_memory_block:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$24, %esp
	movl	12(%ebp), %edx
	movl	8(%ebp), %eax
	movl	%edx, %ecx
	subl	%eax, %ecx
	movl	%ecx, %eax
	movl	$7, 8(%esp)
	movl	%eax, 4(%esp)
	movl	8(%ebp), %eax
	movl	%eax, (%esp)
	call	mprotect
	cmpl	$-1, %eax
	jne	.L12
	movl	$.LC2, (%esp)
	call	puts
	movl	$1, (%esp)
	call	exit
.L12:
	leave
	ret
install_exception_handler:
	pushl	%ebp
	movl	%esp, %ebp
	movl	8(%ebp), %eax
	movl	%eax, Vm_Exception_handler
	popl	%ebp
	ret
.LC3:
	.string	"rb"
load_image:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$40, %esp
	movl	$.LC3, 4(%esp)
	movl	8(%ebp), %eax
	movl	%eax, (%esp)
	call	fopen
	movl	%eax, -4(%ebp)
	cmpl	$0, -4(%ebp)
	jne	.L16
	call	abort
.L16:
	movl	$Vm_image_end, %edx
	movl	$Vm_image_start, %eax
	movl	%edx, %ecx
	subl	%eax, %ecx
	movl	%ecx, %eax
	movl	%eax, %edx
	movl	-4(%ebp), %eax
	movl	%eax, 12(%esp)
	movl	%edx, 8(%esp)
	movl	$1, 4(%esp)
	movl	$Vm_image_start, (%esp)
	call	fread
	movl	-4(%ebp), %eax
	movl	%eax, (%esp)
	call	fclose
	leave
	ret
__PRETTY_FUNCTION__.2586:
	.string	"just_one_line"
.LC4:
	.string	"fourk.c"
.LC5:
	.string	"o_buffer != ((void *)0)"
.LC6:
	.string	"f != ((void *)0)"
.LC7:
	.string	"max_buffer > 2"
.LC8:
	.string	"Warning: "
	.align 4
.LC9:
	.string	"Line exceeded %d characters. Truncated."
just_one_line:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$184, %esp
	movl	8(%ebp), %eax
	movl	%eax, -148(%ebp)
	movl	16(%ebp), %eax
	movl	%eax, -152(%ebp)
	movl	%gs:20, %eax
	movl	%eax, -4(%ebp)
	xorl	%eax, %eax
	cmpl	$0, -152(%ebp)
	jne	.L19
	movl	$__PRETTY_FUNCTION__.2586, 12(%esp)
	movl	$82, 8(%esp)
	movl	$.LC4, 4(%esp)
	movl	$.LC5, (%esp)
	call	__assert_fail
.L19:
	cmpl	$0, -148(%ebp)
	jne	.L20
	movl	$__PRETTY_FUNCTION__.2586, 12(%esp)
	movl	$83, 8(%esp)
	movl	$.LC4, 4(%esp)
	movl	$.LC6, (%esp)
	call	__assert_fail
.L20:
	cmpl	$2, 12(%ebp)
	jg	.L21
	movl	$__PRETTY_FUNCTION__.2586, 12(%esp)
	movl	$85, 8(%esp)
	movl	$.LC4, 4(%esp)
	movl	$.LC7, (%esp)
	call	__assert_fail
.L21:
	movl	$0, -136(%ebp)
	movl	12(%ebp), %eax
	subl	$2, %eax
	movl	%eax, -140(%ebp)
	movl	$0, -144(%ebp)
	jmp	.L22
.L24:
	movl	-136(%ebp), %eax
	movl	%eax, %edx
	addl	-152(%ebp), %edx
	movl	-144(%ebp), %eax
	movb	%al, (%edx)
	addl	$1, -136(%ebp)
.L22:
	movl	-136(%ebp), %eax
	cmpl	-140(%ebp), %eax
	jge	.L23
	movl	-148(%ebp), %eax
	movl	%eax, (%esp)
	call	fgetc
	movl	%eax, -144(%ebp)
	cmpl	$-1, -144(%ebp)
	je	.L23
	cmpl	$10, -144(%ebp)
	jne	.L24
.L23:
	movl	-136(%ebp), %eax
	cmpl	-140(%ebp), %eax
	jne	.L25
	cmpl	$-1, -144(%ebp)
	je	.L25
	movl	stderr, %eax
	movl	%eax, 12(%esp)
	movl	$9, 8(%esp)
	movl	$1, 4(%esp)
	movl	$.LC8, (%esp)
	call	fwrite
	movl	stderr, %edx
	movl	-136(%ebp), %eax
	movl	%eax, 8(%esp)
	movl	$.LC9, 4(%esp)
	movl	%edx, (%esp)
	call	fprintf
	movl	$-2, -156(%ebp)
	jmp	.L26
.L25:
	cmpl	$10, -144(%ebp)
	jne	.L27
	movl	-136(%ebp), %eax
	addl	-152(%ebp), %eax
	movb	$10, (%eax)
	addl	$1, -136(%ebp)
.L27:
	movl	-136(%ebp), %eax
	addl	-152(%ebp), %eax
	movb	$0, (%eax)
	addl	$1, -136(%ebp)
	cmpl	$-1, -144(%ebp)
	jne	.L28
	movl	$-1, -156(%ebp)
	jmp	.L26
.L28:
	movl	-136(%ebp), %edx
	movl	%edx, -156(%ebp)
.L26:
	movl	-156(%ebp), %eax
	movl	-4(%ebp), %edx
	xorl	%gs:20, %edx
	je	.L30
	call	__stack_chk_fail
.L30:
	leave
	ret
	.align 4
.LC10:
	.string	"***Exception: Word to long. Truncating.."
	.align 4
.LC11:
	.string	"***Exception: Word '%s' not found..\n"
kernel_exception_handler:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$24, %esp
	movl	8(%ebp), %eax
	movl	48(%eax), %eax
	movl	%eax, -4(%ebp)
	cmpl	$2, -4(%ebp)
	je	.L33
	cmpl	$3, -4(%ebp)
	jne	.L36
.L34:
	movl	$.LC10, (%esp)
	call	puts
	jmp	.L36
.L33:
	movl	8(%ebp), %eax
	movl	52(%eax), %eax
	movl	%eax, 4(%esp)
	movl	$.LC11, (%esp)
	call	printf
.L36:
	leave
	ret
.LC12:
	.string	"wb"
.LC13:
	.string	"image.fi"
dump_image:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$40, %esp
	movl	$.LC12, 4(%esp)
	movl	$.LC13, (%esp)
	call	fopen
	movl	%eax, -4(%ebp)
	movl	$Vm_image_end, %edx
	movl	$Vm_image_start, %eax
	movl	%edx, %ecx
	subl	%eax, %ecx
	movl	%ecx, %eax
	movl	%eax, %edx
	movl	-4(%ebp), %eax
	movl	%eax, 12(%esp)
	movl	$1, 8(%esp)
	movl	%edx, 4(%esp)
	movl	$Vm_image_start, (%esp)
	call	fwrite
	movl	-4(%ebp), %eax
	movl	%eax, (%esp)
	call	fclose
	leave
	ret
	.local	line.2650
	.comm	line.2650,257,32
run_repl:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$24, %esp
	movl	$mainloop, (%esp)
	call	_setjmp
	movl	%eax, -4(%ebp)
	cmpl	$0, -4(%ebp)
	js	.L40
	cmpl	$1, -4(%ebp)
	jle	.L41
	cmpl	$2, -4(%ebp)
	je	.L45
	jmp	.L40
.L41:
	call	Vm_reset
	jmp	.L43
.L44:
	movl	$line.2650, (%esp)
	call	Vm_eval
	movl	Vm_Save_image, %eax
	testl	%eax, %eax
	je	.L43
	movl	$0, Vm_Save_image
	call	dump_image
.L43:
	movl	stdin, %eax
	movl	$line.2650, 8(%esp)
	movl	$256, 4(%esp)
	movl	%eax, (%esp)
	call	just_one_line
	cmpl	$-1, %eax
	jne	.L44
	jmp	.L45
.L40:
	call	abort
.L45:
	leave
	ret
handler_continuation:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$8, %esp
	movl	$0, 4(%esp)
	movl	$mainloop, (%esp)
	call	longjmp
	.align 4
.LC14:
	.string	"***Exception: Memory referenced at %p\n"
ss_handler:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$24, %esp
	movl	8(%ebp), %eax
	movl	%eax, 4(%esp)
	movl	$.LC14, (%esp)
	call	printf
	movl	$0, 8(%esp)
	movl	$mainsigset, 4(%esp)
	movl	$2, (%esp)
	call	sigprocmask
	movl	$0, 12(%esp)
	movl	$0, 8(%esp)
	movl	$0, 4(%esp)
	movl	$handler_continuation, (%esp)
	call	sigsegv_leave_handler
	leave
	ret
main:
	leal	4(%esp), %ecx
	andl	$-16, %esp
	pushl	-4(%ecx)
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%ebx
	pushl	%ecx
	subl	$144, %esp
	movl	%ecx, %ebx
	movl	$ss_handler, (%esp)
	call	sigsegv_install_handler
	leal	-136(%ebp), %eax
	movl	%eax, (%esp)
	call	sigemptyset
	movl	$mainsigset, 8(%esp)
	leal	-136(%ebp), %eax
	movl	%eax, 4(%esp)
	movl	$0, (%esp)
	call	sigprocmask
	movl	$Vm_image_end, 4(%esp)
	movl	$Vm_image_start, (%esp)
	call	enable_memory_block
	movl	4(%ebx), %eax
	movl	%eax, 4(%esp)
	movl	(%ebx), %eax
	movl	%eax, (%esp)
	call	process_opts
	movl	$kernel_exception_handler, (%esp)
	call	install_exception_handler
	movl	opts+4, %eax
	testl	%eax, %eax
	je	.L51
	movl	opts+4, %eax
	movl	%eax, (%esp)
	call	load_image
.L51:
	call	run_repl
	movl	$0, %eax
	addl	$144, %esp
	popl	%ecx
	popl	%ebx
	popl	%ebp
	leal	-4(%ecx), %esp
	ret
	.comm	mainsigset,128,32
	.comm	ss_dispatcher,4,4
	.comm	opts,8,4
	.comm	mainloop,156,32
