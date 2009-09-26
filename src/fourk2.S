include(macros.m4)
include(dict.m4)

# If we use debug version we need to place everything in code section, because GDB resolves symbols
# only there
	
#ifdef DEBUG
	.TEXT
#else
	.DATA
#endif
#ifndef REFERENCE
	.ALIGN 4096
#endif
_image_start:
	.LONG  _image_start

# Our iterpreting section, we can easily get rid of that and relocate rest
SECTION("interpret")

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
	K4_SAFE_CALL(_ungetc,%eax, stdin)	# unget char
	xor 	%eax,%eax		# clear status (not needed?)
	rep 	stosb			# Fill rest of token
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

	K4_SAFE_CALL(_sscanf,$token,$fmt_float,$long_tmp)
	cmp	$0,%eax
	jz	1f
	mov 	long_tmp,%eax
	pop	%edi
	clc
	ret
1:
	cmpb	$10,var_base
	jz	2f
	K4_SAFE_CALL(_sscanf,$token,$fmt_hex,$long_tmp)
	cmp	$0,%eax
	jz	2f
	mov 	long_tmp,%eax
	pop	%edi
	clc
	ret
2:	
# Use cheap sscanf
	K4_SAFE_CALL(_sscanf,$token,$fmt_dec,$long_tmp)
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
	K4_SAFE_CALL(_getchar)
	cmpl 	$-1,%eax        # if EOF?
	je 	_exit2          # exit the forth
	cmpb	$10,%al         # if a newline 
	jne 1f
1:	ret
	.STRING "ENDX"

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
	shl	$5,%eax
	add	%eax,%edx
	sub	$NTAB_ENTRY_SIZE,%edx	# pointing last one
1:	

# If it's end of list then go and report fail
	cmpb 	$0,(%edx)		# end of dictionary?
	jz 	3f			# yes? Not found then.
	testb	$2,(NTAB_ENTRY_SIZE-1)(%edx)	# Test for immediate
	jnz	4f			# idden? yes then skip it

# Prepare for string comparition
	mov 	%edx,%esi		
	mov 	$(NTAB_ENTRY_SIZE-2),%ecx # Last byte is reserved for flags
					  	
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
	mov	%esp,%ebx
	sub	$4096,%ebx
interpret_loop:

	K4_SAFE_CALL(_gettoken)	#get next token

	movl	$token,	%edi
	call	_find_word	#find word
	jc	2f		#if the word is not found, jump to get literal

# Here we will compile/interpret found word
	xchg	%esp,%ebx	#need to the token on the parameter stack (%ebp)
	pushl	%eax
	xchg	%esp,%ebx
	mov 	var_state, %ecx			#if state = 1 then we compile so get the compile semantics
	shl	$2, %ecx			# * 4 to ecx
	mov	semantic(%ecx,%eax,8), %ecx 	# load the semantics
	call	*%ecx				# call the semantics
	jmp	interpret_loop			# loop unti death!

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

# If it is reference image then relocate it, I stripped it off
# need to align to change the memory attributes via mprotect
	
BEGIN_DICT


#ifndef DEBUG
	 _start:
#main:				
#else
	main:
#endif
# The call is nopped in the final image
	jmp 	entry_point
	mov	%esp,%ebx
	sub	$4096,%ebx
	mov	var_current,%eax
	dec	%eax
	mov	dsptch(,%eax,4),%eax
	jmp	*(%eax)
	
docol:
	push	%esi
	lea	4(%eax),%esi
2:	
	xor	%eax,%eax
	lodsb
	cmpb	$-1,%al
	jne	1f
	pop	%esi
	ret
1:	
	mov	dsptch(,%eax,4),%eax
	mov	(%eax), %ecx
 	call	*%ecx
	jmp 	2b


DEF_CODE(lit, "lit")
	xor	%eax,%eax
	lodsb
	movsbl	%al,%eax
	sub	$4,%ebx
	mov	%eax,(%ebx)
END_CODE
DEF_CODE(dup,"dup")
	xchg	%ebx,%esp
	pushl	(%esp)
	xchg	%ebx,%esp
END_CODE
DEF_CODE(swap,"swap")
	xchg %eax,4(%ebx)
	xchg %eax,(%ebx)
	mov  %eax,4(%ebx)
END_CODE

DEF_CODE(drop,"drop")
	add	$4,%ebx
END_CODE
DEF_CODE(plus,"+")
	mov	(%ebx),%eax
	add	$4,%ebx
	add	%eax,(%ebx)
END_CODE
DEF_CODE(minus,"-")
	mov	(%ebx),%eax
	add	$4,%ebx
	sub	%eax,(%ebx)
END_CODE
DEF_CODE(dot, ".")
	xchg	%esp,%ebx
	pushl 	$fmt_dec	
	call 	printf
	add	$8,%esp
	xchg	%esp,%ebx
	ret
END_CODE
DEF_CODE(comma, ["ccomma"])
	xchg	%esp,%ebx
	pop	%eax
	mov	var_here,%ecx
	movb	%al,	(%ecx)
	incl	var_here
	xchg	%esp,%ebx
END_CODE

DEF_CODE(create,"create")
	push	%esi
	xchg	%esp,%ebx	
	K4_SAFE_CALL(_gettoken)		#fetch next word from the stream
	mov	$token,	%esi		#load token into esi
	movl	var_current,%eax 	#current words index
	shl	$2, %eax	 	#multiply by 4
	movl	$ntab,%edi		#load ntab beg
	lea	(%edi,%eax,8),%edi 	#ntab + index * 4*8
	mov	$NTAB_ENTRY_SIZE, %ecx #length of the word
	rep	movsb		       	#copy the token
	movl	var_current,%eax       	#load index (unneeded?)
	shl	$2, %eax	       	#multiply by 4
	lea	semantic(,%eax,2),%edi 	#store semantic actions (two dwords)
	movl	$code_compile, (%edi)
	movl	$code_execute, 4(%edi)
	lea	dsptch(%eax),%edi      	#load address to edi
	mov	var_here, %eax		#load here address
	movl	%eax,(%edi)
	movl	$docol,	(%eax)
	addl	$4,var_here	
	incl	var_current		#increment current word
	xchg	%esp,%ebx
	pop	%esi
	ret
END_CODE
DEF_CODE(lb, "lb")		#alias for [
	movl	$1, var_state
END_CODE
DEF_CODE(rb, "rb")
	movl	$0, var_state	#alias for ]
END_CODE
DEF_IMM(immediate,"immediate")
	movl	var_current,%eax
	dec	%eax
	lea	semantic(,%eax,8),%edi 	#store semantic actions (two dwords)
	movl	$code_execute, (%edi)
	movl	$code_execute, 4(%edi)
	ret
END_CODE	
DEF_IMM(postpone,"postpone")
	xchg	%esp,%ebx	
	K4_SAFE_CALL(_gettoken)		#fetch next word from the stream
	movl	$token,	%edi
	K4_SAFE_CALL(_find_word)
	cmp	$1, var_state
	jne	1f
	push	%eax
	xchg	%esp,%ebx
	call	code_compile		# compile
	jmp	9f
1:	
	mov	var_here,%edi
	movb	$ 0, (%edi)
	movb	%al, 1(%edi)
	incl 	var_here
	incl 	var_here
	
	mov	semantic(,%eax,8), %edi	#load the semantics
	sub	$4, %edi		#convert it to the word token
	mov	var_current,%ecx	#current word
	dec	%ecx			
1:					# find the word of semantics
	cmp	dsptch(,%ecx,4),%edi 	
	je	1f			# found
	loop	1b
1:
	push	%ecx
	xchg	%esp,%ebx
	call	code_compile		# compile
9:	
END_CODE

DEF_CODE(fetch, "@")
	movl	(%ebx),%eax
	movl	(%eax),%eax
	movl	%eax,(%ebx)
END_CODE
DEF_CODE(store, "!")
	movl	(%ebx),%eax
	mov	4(%ebx),%ecx
	mov	%ecx,(%eax)
	add	$8, %ebx
END_CODE
DEF_CODE(execute, "execute")
	xchg	%esp,%ebx
	popl	%eax
	mov	dsptch(,%eax,4),%eax 		#now load the word
	xchg	%esp,%ebx
	call	*(%eax)
END_CODE
DEF_CODE(compile, "compile")
	xchg	%esp,%ebx
	popl	%eax
	movl	var_here,%ecx
	movb	%al,(%ecx)
	incl	var_here
	xchg	%esp,%ebx
END_CODE

log_op:
	mov	(%ebx),%eax
	add	$4,%ebx
	cmp	%eax,(%ebx)
	xor	%edx,%edx
	mov	%edx,%ecx
	dec 	%ecx
	cmp	%eax,(%ebx)
	ret
	
DEF_CODE(equals, "=")
	call 	log_op
	cmove 	%ecx,%edx
	mov	%edx,(%ebx)
END_CODE

DEF_CODE(lower, "<")
	call 	log_op
	cmovl 	%ecx,%edx
	mov	%edx,(%ebx)
END_CODE

DEF_CODE(greater, ">")
	call 	log_op
	cmovg 	%ecx,%edx
	mov	%edx,(%ebx)
END_CODE

DEF_CODE(invert, "invert")
	notl	(%ebx)
END_CODE

DEF_CODE(emit, "emit")
	xchg	%esp,%ebx
	pushl 	$fmt_char	
	call 	printf
	add	$8,%esp
	xchg	%esp,%ebx
END_CODE
DEF_CODE(branch, "branch")
	lodsb
	movsbl 	%al,%eax
	add	%eax,%esi
END_CODE
DEF_CODE(branch0, "branch0")
	mov	(%ebx),%eax
	add	$4,%ebx
	or	%eax,%eax
	jz	1f
	lodsb
	movsbl 	%al,%eax
	add	%eax,%esi
1:	
END_CODE
DEF_CODE(tick, "'")
	xchg	%esp,%ebx	
	K4_SAFE_CALL(_gettoken)		#fetch next word from the stream
	movl	$token,	%edi
	K4_SAFE_CALL(_find_word)
        push    %eax            # push TOS
	xchg	%esp,%ebx
END_CODE
DEF_CODE(save_image, "save-image")
	K4_SAFE_CALL(_gettoken)		#fetch next word from the stream
	K4_SAFE_CALL(_fopen, $token,$str_wb)
	push	%eax
	K4_SAFE_CALL(_fwrite, $_image_start, $ 1, $(_image_end-_image_start), %eax)
	pop	%eax
	K4_SAFE_CALL(_fclose, %eax)
END_CODE
DEF_CODE(load_image, "load-image")
#define PROT_READ	0x1		/* Page can be read.  */
#define PROT_WRITE	0x2		/* Page can be written.  */
#define PROT_EXEC	0x4		/* Page can be executed.  */
	K4_SAFE_CALL(_gettoken)		#fetch next word from the stream
	K4_SAFE_CALL(_mprotect, $_image_start, $(_image_end-_image_start),  $(PROT_READ | PROT_WRITE | PROT_EXEC))
	K4_SAFE_CALL(_fopen, $token,$str_rb)
	push	%eax
	K4_SAFE_CALL(_fread, $_image_start, $ 1, $(_image_end-_image_start), %eax)
	pop	%eax
	K4_SAFE_CALL(_fclose, %eax)
	jmp interpret_loop
END_CODE
#ifdef DEBUG
	.data
#endif

DEF_VAR(state, 1)
DEF_VAR(here, here)
DEF_VAR(current, [EL_COUNT(NAME_TAB)+1])
DEF_CODE(test,"test")
	
	
END_DICT
BUILD_NAME_TABLE

.ALIGN 4096
_image_end:

# Our data, it will be stripped off so store it in intepret section
long_tmp: 		.LONG 0
token:			.FILL	64
fmt_float: 		.ASCIZ  "%f"
fmt_hex:		.ASCIZ 	"%x"
fmt_dec:		.ASCIZ 	"%d"
fmt_char:		.ASCIZ 	"%c"
str_wb:			.ASCIZ 	"wb"
str_rb:			.ASCIZ 	"rb"
var_base:		.LONG 	10
msg:			.ASCIZ "%s\n"
msg_not_defined:	.ASCIZ "Word '%s' not defined.\n"
msg_test1:		.ASCIZ "Test1\n"
msg_test2:		.ASCIZ "Test2\n"
msg_test3:		.ASCIZ "Test3\n"
whites:                 .BYTE  10
