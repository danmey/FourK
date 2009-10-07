include(macros.m4)
include(dict.m4)

#define PREFIX_WORDS_INDEX 5

# Following imports are used and needs to be dereferenced
# I am not sure if it is needed
## _sscanf:	jmp sscanf
## _ungetc:	jmp ungetc
## _getchar:	jmp getchar
## _printf:	jmp printf
## _exit:		jmp exit
## _fopen:		jmp fopen
## _fwrite:	jmp fwrite
## _mprotect:	jmp mprotect
## _fread:		jmp fread
## _fclose:	jmp fclose

#define _sscanf 	sscanf
#define _ungetc		ungetc
#define _getchar	getchar
#define _printf		printf
#define _exit		exit
#define _fopen		fopen
#define _fwrite		fwrite
#define _mprotect	mprotect
#define _fread		fread
#define _fclose		fclose

# If we use debug version we need to place everything in code section, because GDB resolves symbols
# only there
	
#ifdef DEBUG
	.TEXT
#else
	.DATA
#endif

#ifdef REFERENCE
       .FILL 0x11234
#endif



################################################################################
# Get token, separated by whites, and put it in token
# TODO: Make it case insesitive (lowercase everything)
# In:
# Out:
# eax - integer value
# token - a token
#libc:	.ASCIZ "/lib/libc-2.8.90.so"
#stdins:	.ASCIZ "stdin"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!CAUTION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# this bit cannot be saved into image, therefore cannot be in the
# interpret pseudo section due to `stdin' symbol relocation problem
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!CAUTION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
#	K4_SAFE_CALL(_ungetc,%eax, stdin) # unget char
	xor 	%eax,%eax		# clear status (not needed?)
	rep 	stosb			# Fill rest of token
	ret


# Our iterpreting section, we can easily get rid of that and relocate rest
SECTION("interpret")

#ifdef DEBUG
	.DATA
#else
#endif

	
	# Our data, it will be stripped off so store it in intepret section
long_tmp: 		.LONG 0
token:			.FILL	64
fmt_float: 		.ASCIZ  "%f"
fmt_hex:		.ASCIZ 	"%x\n"
fmt_dec:		.ASCIZ 	"%d"
fmt_char:		.ASCIZ 	"%c"
str_wb:			.ASCIZ 	"wb"
str_rb:			.ASCIZ 	"rb"
msg:			.ASCIZ "%s\n"
msg_not_defined:	.ASCIZ "Word '%s' not defined.\n"
msg_test1:		.ASCIZ "Test1\n"
msg_test2:		.ASCIZ "Test2\n"
msg_test3:		.ASCIZ "Test3\n"
whites:                 .BYTE  4,9,10,12,13,0
bytecode:		.BYTE  0,INTERPRET_TOKEN
_vm_context_reg:	.FILL 32
_vm_context_ESP:	.FILL  4
fh_stack:		.FILL 32*4
fh_stack_index:		.LONG	0
#ifdef DEBUG
	.TEXT
#else
#endif


	.macro ld_fh reg
		mov	fh_stack_index,%edx
		mov	fh_stack(%edx),\reg
	.endm
################################################################################
# Load 
# 
#
	
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
	xor 	%ecx,%ecx
	not	%ecx
	xor 	%eax,%eax
	cld
	repnz 	scasb
	not 	%ecx
	dec 	%ecx

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
	je 	_exit2          # exit the forth
	cmpb	$10,%al         # if a newline 
	jne 1f
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
	mov 	$ntab,%edx		# set up a pointer past the end
	mov	var_current,%eax
	inc	%eax
	shl	$5,%eax	
	add	%eax,%edx
	sub	$NTAB_ENTRY_SIZE,%edx	# pointing last one
1:	

# If it's end of list then go and report fail
	cmp	$(ntab-NTAB_ENTRY_SIZE) ,%edx
	jz 	3f			# yes? Not found then.

# Prepare for string comparition
	mov 	%edx,%esi		
	mov 	$(NTAB_ENTRY_SIZE),%ecx # Last byte is reserved for flags
					  	
# Compare it
	push	%edi			# save edi, because it contains
	repe 	cmpsb			# the pointer to our value
	pop	%edi			# restore
	jz 	2f			# Found word!
4:	
	sub 	$NTAB_ENTRY_SIZE,%edx 	# Nope.. go back one entry
	jmp 	1b
2:
	
# We have found a word go and calculate index
	sub 	$ntab,%edx
	shr 	$5,%edx			# divide it by 32
	mov	%edx,%eax
	clc				# clear fail flag
	ret
# Not found
3:
	xor 	%eax,%eax
	stc
	ret

#Out entry point here the fun begins, this is only valid during compiling/interpreting
#there will be no code here in final image
entry_point:
	pushl	stdin
	popl	fh_stack
#	call build_dispatch
	mov	var_current,	%ebx
	call 	build_dispatch

	mov	%esp,%ebx
	sub	$4096,%ebx
	
interpret_loop:

	K4_SAFE_CALL(_gettoken)	#get next token
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
	K4_SAFE_CALL(_printf,$msg_not_defined)
	jmp 	interpret_loop
	
# Literal could be parsed here
3:
	cmp	$0, var_state	#code dependent on the state
	jnz	4f		#if we are compiling (0) then compile the literal
# Here we compile literal TODO: the state variable has inverted meaning; do something with that
	mov	var_here,%ecx
	movb	$0,(%ecx)	# token for literal
	incl	%ecx		# increment here
	movb	%al,(%ecx)	# store the actual literal (only byte literals allowed)
				# TODO: allow different sizes of literals
	incl	%ecx
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
.ALIGN 4096
	
_image_start:
SECTION("dict")
	################################################################################
# Our image starts here and will be saved by a save-image word, and load by
# load-image word
#
	.LONG  _image_start	# at the begining we need the actual memory address
				# for relocations
#ifndef DEBUG
#ifdef PARTY
	_start:
#else
	main:
#endif
#else
	main:				
#endif
# The call is nopped in the final image
	jmp 	entry_point
	pushl	stdin
	popl	fh_stack
# This will be supplied with the last word by linker
	mov	$0,	%ebx
	push	%ebx
	call 	build_dispatch	
	mov	%esp,%ebx
	sub	$4096,%ebx
	mov	$next_word,%ebp
	pop	%eax
	dec	%eax
	mov	%al,ex_bytecode
	movb	$-1,(ex_bytecode+1)
	mov	$(ex_bytecode-1),%eax
	jmp	runbyte

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
	call	.check_end
	cmp	$-1,%al		#end of core dictionary?
	je	.user_dictionary
	cmp	$0,%al		#end of core dictionary?
	je	.done
	mov	%esi,%eax	#load pointer to word
	dec	%eax
	stosl			#store the pointer to word in %edi
	add	%ecx,%esi	#advance to next word
	jmp	.loop
.user_dictionary:
	cmp	$-1,%al
	je	.found_word
	cmp	$5,%al
	jae	.cont
	lodsb
	jmp	.cont
.found_word:
	mov	%esi,%eax
	dec	%eax
	stosl
	call	.check_end
	or	%eax,%eax
	jz	.done
.cont:
	lodsb
	jmp	.user_dictionary
.check_end:
	mov	%edi,%edx
	sub	$dsptch,%edx
	shr	$2,%edx
	sub	%ebx,%edx
	jnz	1f
	xor	%eax,%eax
1:	
	ret
.done:
#	K4_SAFE_CALL(printf, $fmt_hex, var_here)
#	K4_SAFE_CALL(printf, $fmt_hex, %esi)
	ret

ex_bytecode:		.BYTE  0,END_TOKEN

################################################################################
# Main bytecode interpreter loop,
# Function escapes to main text interpreter loop throuh `interpret' token
# In: %eax - contains a word pointer
runbyte:	
	push	%esi		# push the current word address on the return stack
	lea	1(%eax),%esi	# load the byte code pointer
.fetchbyte:			
	xor	%eax,%eax	# fetch the byte, first clear up the %eax
	lodsb			# byte code in %eax
	cmpb	$-1,%al		# if it is end of word, escape by returning
	je	.fold		# the previous byte code pointer
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

include(prim.S)

# TODO: For real usage maybe we need malloced heap
ccall_tab:
	.LONG dlopen,8
	.LONG dlsym,8
	.FILL 256-8
there:
.FILL 16*1024
.ALIGN 4096
_image_end:
