include(macros.m4)
include(dict.m4)
include(elf.m4)
define([PREFIX_WORDS_INDEX], 5)

# If we use debug version we need to place everything in code section, because GDB resolves symbols
# only there

ifdef([PARTY],,
[	.TEXT
	.align 4096
])

ifdef([PARTY],
[
	ELF_HEADER()
])

_image_start:
	ELF_SECTION_TAB_OFFSET()
	SECTION(dict)
				# for relocations
ifdef([DEBUG],
[
main:
],
[
_start:
]
)

define([PROT_READ],	0x1)		/* Page can be read.  */
define([PROT_WRITE],	0x2)		/* Page can be written.  */
define([PROT_EXEC],	0x4)		/* Page can be executed.  */
	
# The call is nopped in the final image
	jmp 	entry_point
	mov	$0,	%ebx
	push	%ebx
	call	init_imports
	K4_SAFE_CALL(mprotect, $_image_start, $(_image_end-_image_start),  $(PROT_READ | PROT_WRITE | PROT_EXEC))

# I don't why following paragraph is needed but certainly is needed
	push	$dlopen_s
	push	$ -1
	call	dlsym
	add	$8,%esp
	mov	%eax,dlopen_
	
#		movl $1,%eax
#	xor %ebx,%ebx 
#	int $128 

################################################################################
# This will be supplied with the last word by linker
	call 	build_dispatch
	pop	%eax
	dec	%eax

	 ## mov	dsptch(,%eax,4),%eax # load the pointer to word from the dispatch
	 ## xor	%ecx,%ecx
	 ## movb	13(%eax),%cl
	 ## K4_SAFE_CALL(printf, $fmt_dec,	%ecx)
	 ## movl $1,%eax
	 ## xor %ebx,%ebx
	 ## int $128

	mov	%esp,%ebx
	sub	$4096,%ebx
	mov	$next_word,%ebp
	mov	%al,ex_bytecode
	movb	$-1,(ex_bytecode+1)
	mov	$(ex_bytecode-1),%eax
	
	jmp	runbyte
dlopen_s:	.asciz "dlopen"
msg3:			.ASCIZ "%s\n"

ccall_tab:
	.LONG dlopen,8
	.LONG dlsym,8
	.FILL 256-16

################################################################################
# Build the dispatch table
# In:
# Out:

build_dispatch:
	mov	$dsptch, %edi	#load destination table of dwords
	mov	$_words_start, %esi	#begining of the dictionary
.loop:
	xor	%eax,%eax	#clear out eax
	lodsb
	mov	%eax,%ecx
	cmp	$-1,%al		#end of core dictionary?
	je	.user_dictionary
	cmp	$ EOD_TOKEN,%al		#end of core dictionary?
	je	.done
	mov	%esi,%eax	#load pointer to word
	dec	%eax
	stosl			#store the pointer to word in %edi
	add	%ecx,%esi	#advance to next word
	jmp	.loop
.loop2:
	xor	%eax,%eax
	lodsb
.user_dictionary:
	cmp	$-1,%al
	je	.found_word
	cmp	$ EOD_TOKEN,%al		#end of core dictionary?
	je	.done
	cmp	$4,%al
	jbe	.cont
	cmp	$ PREFIX_TOKEN,%al
	je	.cont
	jmp	.loop2
.found_word:
	cmpb	$-1,(%esi)
	jz	.done
	mov	%esi,%eax
	dec	%eax
	stosl
	jmp	.loop2
.cont:
	cmp	$1,%al
	jz	.lit4
	lodsb
	jmp	.loop2
.lit4:
	lodsl
	jmp	.loop2

.done:
#	K4_SAFE_CALL(printf, $fmt_hex, var_here)
#	K4_SAFE_CALL(printf, $fmt_hex, %esi)
	ret

ex_bytecode:		.BYTE  0,0,0 # to fit the prefix word

ifdef([PARTY],[
dlsym:
.byte 0xff,0x25
.LONG dlsym_
dlsym_:
.LONG 0
])

ifdef([PARTY],[
dlopen:
.byte 0xff,0x25
.LONG dlopen_
])
dlopen_:
.LONG 0


################################################################################
# Main bytecode interpreter loop,
# Function escapes to main text interpreter loop throuh `interpret' token
# In: %eax - contains a word pointer
runbyte:
ifdef([DEBUG],[
	push	%eax
	cmpl	$ 0, interrtupted
	je	1f
	movl	$ 0, interrtupted
	K4_SAFE_CALL(longjmp,$mainloop)
1:	
	pop	%eax
])
	push	%esi		# push the current word address on the return stack
	lea	1(%eax),%esi	# load the byte code pointer
.fetchbyte:
	xor	%eax,%eax	# fetch the byte, first clear up the %eax
	lodsb			# byte code in %eax
	cmpb	$ END_TOKEN,%al		# if it is end of word, escape by returning
	je	.fold		# the previous byte code pointer
	cmpb	$ PREFIX_TOKEN,%al		# prefix word
	jne	.regular	# not, then regular
	lodsb
#	add	$256,%eax	
	add	$PREFIX_TOKEN,	%eax
.regular:
	mov	dsptch(,%eax,4),%eax # load the pointer to word from the dispatch
	cmpb	$-1, (%eax)	     # table. Check if it is bytecode or asm code?
	je	runbyte		     # if it is byte code then thread again
	mov	%eax,%ecx	     # if it is asm code skip the size byte and jump there
	inc	%ecx		     # asm defined words escape to next_word at the end
	jmp	*%ecx		     # jump there
.fold:
	pop	%esi		# we are threading out
next_word:
	jmp 	.fetchbyte	# this is called by every asm word at the end

fmt_dec:		.ASCIZ 	"%d\n"


include(import.m4)
K4_IMPORT(stdout)
K4_IMPORT(stdin)
K4_IMPORT(printf)
K4_IMPORT(fflush)
K4_IMPORT(fopen)
K4_IMPORT(fmemopen)
K4_IMPORT(sscanf)
K4_IMPORT(fgetc)
K4_IMPORT(_exit)
K4_IMPORT(fwrite)
K4_IMPORT(fclose)
K4_IMPORT(fread)
ifdef([PARTY], [K4_IMPORT(mprotect)])
K4_INIT_IMPORTS(init_imports)


# Our iterpreting section, we can easily get rid of that and relocate rest
SECTION(interpret)

################################################################################
# Get token, separated by whites, and put it in token
# TODO: Make it case insesitive (lowercase everything)
# In:
# Out:
# eax - integer value
# token - a token
#libc:	.ASCIZ "/lib/libc-2.8.90.so"
#stdins:	.ASCIZ "stdin"

_gettoken:
# Skip whites
	call	_get_key_white_skip
	mov 	$token,%edi
	mov 	$NTAB_ENTRY_SIZE,%ecx
1:
	dec %ecx			# keep the counter becasue we need to clear out token
	stosb				# in al we had out character
	call _get_key			# get next key
	call _is_white			# is white?
	jnz 1b				# NO?
#	K4_SAFE_CALL(ungetc,%eax, stdin) # unget char
	xor 	%eax,%eax		# clear status (not needed?)
	push	%ecx
	rep 	stosb			# Fill rest of token
	pop	%ecx
	neg	%ecx
	add 	$NTAB_ENTRY_SIZE,%ecx
	ret

ifdef([DEBUG],
[
msg_segf:	
	.string	"***Exception: Memory referenced at %p\n"

msg_int:	
	.string	"***Interrupt: The interpreter is interrupted\n"
interrtupted:
	.long	0
	
segf_handler:
	push	%ebp
	mov	%esp,%ebp
	mov	8(%ebp),%eax
	K4_SAFE_CALL(printf,$msg_segf,%eax)
	K4_SAFE_CALL(sigprocmask,$ 2,$mainsigset, $ 0)
#	K4_SAFE_CALL(sigsegv_leave_handler)
	K4_SAFE_CALL(longjmp,$mainloop)
	pop	%ebp
	ret

int_handler:
	K4_SAFE_CALL(printf,$msg_int)
	movl	$ 1, interrtupted
	ret
	
install_handlers:
	K4_SAFE_CALL(sigsegv_install_handler,$segf_handler)
	K4_SAFE_CALL(sigemptyset,$emptyset)
	K4_SAFE_CALL(sigprocmask,$ 0,$emptyset,$mainsigset)
	K4_SAFE_CALL(signal,$ 2, $int_handler)
	ret
	.comm	mainsigset,128,32
	.comm	ss_dispatcher,4,4
	.comm	mainloop,156,32
	.comm	emptyset,128,32

])









# Our data, it will be stripped off so store it in intepret section
long_tmp: 		.LONG 0
token:			.FILL	64
token2:			.FILL 	64
fmt_float: 		.ASCIZ  "%f"
fmt_hex:		.ASCIZ 	"%x\n"
fmt_char:		.ASCIZ 	"%c"
str_wb:			.ASCIZ 	"wb"
str_rb:			.ASCIZ 	"rb"
msg:			.ASCIZ "%s\n"
msg2:			.ASCIZ "------\n"

msg_not_defined:	.ASCIZ "Word '%s' not defined.\n"
msg_file_not_found:	.ASCIZ "File '%s' not found.\n"
msg_test1:		.ASCIZ "Test1\n"
msg_test2:		.ASCIZ "Test2\n"
msg_test3:		.ASCIZ "Test3\n"
whites:                 .BYTE  4,9,10,12,13,0
bytecode:		.BYTE  0,INTERPRET_TOKEN
			.LONG 0
_vm_context_reg:	.FILL 42
_vm_context_ESP:	.FILL  4
_vm_context_EBP:	.fill  4
_org_ESP:		.LONG	0
fh_stack:		.FILL 32*4
fh_stack_index:		.LONG	0
bootstrap_s:		.asciz "bootstrap.4k"

libc_handle:	 .LONG 0



	.macro ld_fh reg
		mov	fh_stack_index,%edx
		mov	fh_stack(,%edx,4),\reg
	.endm


################################################################################
# Nest into next file stream
# In:
# edi - file name
# Out:

f_rt:	.ASCIZ "rt"

memo_nest:
	K4_SAFE_CALL(fmemopen, %edi, %ecx, $f_rt)
	jmp 	file_nest_ch
file_nest:
	K4_SAFE_CALL(fopen, %edi, $f_rt)
file_nest_ch:
	or	%eax,%eax
	jnz	1f
	stc
	ret
1:
	incl	fh_stack_index
	mov	fh_stack_index,%ecx
	mov	%eax,fh_stack(,%ecx,4)
	clc
	ret

file_unnest:
	mov	fh_stack_index,%ecx
	cmp	$0,%ecx
	jz	_exit2
	decl	fh_stack_index
	mov	fh_stack(,%ecx,4),%eax
	ret

################################################################################
# Parse literal, string is in token
# In:
# Out:
# eax - integer value
_parse_literal:
# Check for dot if dot is present then we have floating point number
	push 	%edi
	mov	$token,%edi
# string length
#	xor 	%ecx,%ecx
#	not	%ecx
#	xor 	%eax,%eax
#	cld
#	repnz 	scasb
#	not 	%ecx
#	dec 	%ecx
#	K4_SAFE_CALL(printf,$msg, $token)
#	K4_SAFE_CALL(printf,$fmt_dec, %ecx)
#	K4_SAFE_CALL(printf,$msg2)

	mov	$'.',%al
	mov	$token,%edi
	repnz 	scasb
	jnz	1f	# real

	K4_SAFE_CALL(sscanf,$token,$fmt_float,$long_tmp)
	cmp	$0,%eax
	jz	1f
	mov 	long_tmp,%eax
	pop	%edi
	clc
	ret
1:
	mov	$token,%edi
	cmpb	$'$',(%edi)
	jz	.base16

	cmpb	$10,var_base
	jz	2f
	mov	$token,%edi
	dec	%edi
.base16:
	inc	%edi
	K4_SAFE_CALL(sscanf,%edi,$fmt_hex,$long_tmp)
	cmp	$0,%eax
	jz	2f
	mov 	long_tmp,%eax
	pop	%edi
	clc
	ret
2:
# Use cheap sscanf
	K4_SAFE_CALL(sscanf,$token,$fmt_dec,$long_tmp)
3:
	cmp	$0,%eax
	jz 	4f
	mov 	long_tmp,%eax
	pop	%edi
	clc
	ret

4:
	pop	%edi
	stc
	ret

################################################################################
# Get key, skipping whites
# In:
# Out:
# al - an ASCII code of character
# token - a token
_get_key_white_skip:
	call _get_key
	call _is_white
	jz _get_key_white_skip	# loop until we will find something
	ret

################################################################################
# Is white?
# In:
# al - an ASCII code of character
# Out:
# Z - if its white
# token - a token
_is_white:
	cmpb	$10,%al		# CR ?
	je	1f
	cmpb	$13,%al       	# LF ?
	je	1f
	cmpb	$9,%al		# TAB ?
	je	1f
	cmpb	$' ',%al	# SPACE ?
	je	1f
1:	ret

################################################################################
# Get char from STDIN, jumps out in case of EOF
# In:
# Out:
# al - an ASCII code of character
# token - a token
_get_key:
	ld_fh	%edx
	K4_SAFE_CALL(fgetc,%edx)
	cmp 	$-1,%eax        # if EOF?
	jne 	2f     # exit the forth
	call	file_unnest
	ld_fh	%edx
	K4_SAFE_CALL(fgetc,%edx)
	ret
2:
1:	ret

################################################################################
# Find the word in dictionary by comparing strings.
# The dictionary is searched in reverse order, and idden words are skipped.
#
# TODO: Where to put case sensitivity skip?
# TODO: Make it more optimal without and edx
#
# In:
# edi - word to find
# Out:
# eax - rets word index, C - set if no word found
_find_word:
	push	%esi
	mov 	$ntab,%edx		# set up a pointer past the end
	mov	var_last,%eax
	shl	$5,%eax
	add	%eax,%edx
	sub	$NTAB_ENTRY_SIZE,%edx	# pointing last one
#	K4_SAFE_CALL(printf,$fmt_dec,%ecx) 
1:

# If it's end of list then go and report fail
	cmp	$(ntab-NTAB_ENTRY_SIZE) ,%edx
	jz 	3f			# yes? Not found then.

# Prepare for string comparition
	mov 	%edx,%esi

2:
	cmpb	$ 0, (%esi,%ecx)
	jnz	4f

# Compare it
	push	%ecx
	push	%edi			# save edi, because it contains
	repe 	cmpsb			# the pointer to our value
	mov	%edi,%eax
	pop	%edi			# restore
	pop	%ecx
	jz 	2f			# Found word!
4:
	sub 	$NTAB_ENTRY_SIZE,%edx 	# Nope.. go back one entry
	jmp 	1b
2:	
# We have found a word go and calculate index
	sub 	$ntab,%edx
	shr 	$5,%edx			# divide it by 32
	mov	%edx,%eax
	pop	%esi
	clc				# clear fail flag
	ret
# Not found
3:

	xor 	%eax,%eax
	pop	%esi
	stc
	ret

#Out entry point here the fun begins, this is only valid during compiling/interpreting
#there will be no code here in final image
entry_point:
ifdef([PARTY],,[
	K4_SAFE_CALL(mprotect, $_image_start, $(_image_end-_image_start),  $(PROT_READ | PROT_WRITE | PROT_EXEC))
])
	call	init_imports
	
# I don't why following paragraph is needed but certainly is needed
	push	$dlopen_s
	push	$ -1
	call	dlsym
	add	$8,%esp
	mov	%eax,dlopen_
################################################################################
	movl	stdin_ptr,%eax
	pushl	(%eax)

	popl	fh_stack

	mov	var_last,	%ebx
	call 	build_dispatch
	mov	%esp,_org_ESP
 	mov	%esp,%ebx
	sub	$ 4096,%ebx
	mov	$bootstrap_s,%edi
	K4_SAFE_CALL(file_nest)
ifdef([DEBUG],[
	K4_SAFE_CALL(_setjmp, $mainloop)
 	movl	_org_ESP,%esp
 	mov	%esp,%ebx
	sub	$ 4096,%ebx
	call 	install_handlers
	])
interpret_loop:
	call	_gettoken	#get next token

	mov	$next_word,%ebp
	movl	$token,	%edi
	call	_find_word	#find word
	jc	2f		#if the word is not found, jump to get literal

# Here we will compile/interpret found word
	xchg	%esp,%ebx	#need to the token on the parameter stack (%ebp)
	pushl	%eax
	xchg	%esp,%ebx
	mov 	var_state, %ecx			#if state = 1 then we compile so get the compile semantics
	## Important: now the word will be interptretr or exeucet throuh word_compile or word_execute
	## the tokens here are hardcoded! 1  for compiling 2 for executing
	movzbl	semantic(%ecx,%eax,2),%eax
	mov	%al,bytecode
	mov	$(bytecode-1),%eax
	movb	$INTERPRET_TOKEN,(bytecode+1)
	jmp	runbyte

# Here we will parse the literal if word is not found
2:
	call	_parse_literal
	jnc 	3f		#if literal cannot be parsed give a proper message and loop
	K4_SAFE_CALL(printf,$msg_not_defined)
	jmp 	interpret_loop

# Literal could be parsed here
3:
	cmp	$0, var_state	#code dependent on the state
	jnz	4f		#if we are compiling (0) then compile the literal
# Here we compile literal TODO: the state variable has inverted meaning; do something with that
	cmp	$127,%eax	# if the literal fits in one byte
	jg	.dword_lit
	cmp	$-128,%eax	# if the literal fits in one byte
	jl	.dword_lit

	mov	var_here,%ecx
	movb	$ LIT_TOKEN,(%ecx)	# token for literal
	incl	%ecx		# increment here
	movb	%al,(%ecx)	# store the actual literal (only byte literals allowed)
				# TODO: allow different sizes of literals
	incl	%ecx
	mov	%ecx,var_here	#store the pointer and loop
	jmp 	interpret_loop

.dword_lit:
	mov	var_here,%ecx
	movb	$1,(%ecx)	# token for literal
	incl	%ecx		# increment here
	movl	%eax,(%ecx)	# store the actual literal (only byte literals allowed)
				# TODO: allow different sizes of literals
	add	$4,%ecx
	mov	%ecx,var_here	#store the pointer and loop
	jmp 	interpret_loop


# Here we are pushing the literal on the stack as we are in interpreting mode
4:
	xchg 	%esp,%ebx
	push	%eax
	xchg 	%esp,%ebx
	jmp	interpret_loop

_exit2:
	K4_SAFE_CALL(_exit,$ 0)
	ret


	.GLOBL main
	.GLOBL _start


################################################################################
# Our image starts here and will be saved by a save-image word, and load by
# load-image word
#


# Our core words
include(prim.s)

# TODO: For real usage maybe we need malloced heap
ELF_CODE_END()
	.ALIGN 4096
_image_end:
ifdef([PARTY],[
ELF_DATA_END()
])
