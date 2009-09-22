
include(macros.m4)
include(dict.m4)

	.data		


	.GLOBL main
	.GLOBL _start
#ifndef DEBUG
_start:
#else
main:
#endif
	mov	%esp,%ebp
	sub	$4096,%ebp
1:
	K4_SAFE_CALL(_gettoken)
	cmpb	$'!',token
	jz _exit

	movl	$token,	%edi
	call	_find_word
	jc	2f

#	cmpl	$ NCORE_WORDS,%eax
#	ja	2f
	cmpl	$0, var_state
	jnz	.interpret
	
	
	jmp	1b
	
.interpret:	
	mov	dsptch(,%eax,4),%eax
	mov	(%eax), %ebx
	call	*%ebx
	jmp	1b

2:
	call	_parse_literal
	jnc 	3f
	K4_SAFE_CALL(printf,$msg_not_defined)
	jmp 	1b
3:	
	xchg 	%esp,%ebp
	push	%eax
	xchg 	%esp,%ebp
	jmp	1b
_exit:
	K4_SAFE_CALL(exit,$ 0)	
	ret

docol:
	addl	$4, %eax
	lodsb
	mov	dsptch(,%eax,4),%eax
	mov	(%eax), %ebx
	call	*%ebx
	ret

	.ALIGN	4
	.STRING	"BEGX"
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
	cmpb	$10,var_base
	jz	2f
	K4_SAFE_CALL(sscanf,$token,$fmt_hex,$long_tmp)
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
# Get token, separated by whites, and put it in token
# TODO: Make it case insesitive (lowercase everything)
# In:
# Out:	
# eax - integer value
# token - a token
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
	K4_SAFE_CALL(ungetc,%eax,stdin)	# unget char
	xor 	%eax,%eax		# clear status (not needed?)
	rep 	stosb			# Fill rest of token
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
	jz	1f
	cmpb	$13,%al       	# LF ?
	jz	1f
	cmpb	$9,%al		# TAB ?
	jz	1f
	cmpb	$' ',%al	# SPACE ?
	jz	1f
1:	ret
	
	
	
	
################################################################################	
# Get char from STDIN, jumps out in case of EOF
# In:
# Out:
# al - an ASCII code of character
# token - a token
_get_key:
	K4_SAFE_CALL(getchar)
	cmpl 	$-1,%eax
	jz 	_exit
	cmpb	$10,%al
	jnz 1f
1:	ret
	.ALIGN 4
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


BEGIN_DICT
DEF_CODE(dup,"dup")
	xchg	%esp,%ebp
	pushl	(%esp)
	xchg	%esp,%ebp
	ret
END_CODE
DEF_CODE(drop,"drop")
	xchg	%esp,%ebp
	pop	%eax
	xchg	%esp,%ebp
	ret
END_CODE
DEF_CODE(plus,"+")
	xchg	%esp,%ebp
	pop	%eax
	add	%eax,(%esp)
	xchg	%esp,%ebp
	ret
END_CODE
DEF_CODE(dot, ".")
	xchg	%esp,%ebp
	pushl 	$fmt_dec	
	call 	printf
	add	$8,%esp
	xchg	%esp,%ebp
	ret
END_CODE
DEF_CODE(comma, ["ccomma"])
	xchg	%esp,%ebp
	pop	%eax
	mov	var_here,%ebx
	movb	%al,	(%ebx)
	incl	var_here
	xchg	%esp,%ebp
	ret
END_CODE
DEF_CODE(create,"create")
	xchg	%esp,%ebp
	K4_SAFE_CALL(_gettoken)
	mov	$token,	%esi
	movl	var_current,%eax
	shl	$2, %eax
	movl	$ntab,%edi
	lea	(%edi,%eax,8),%edi
	mov	$32, %ecx
	rep	movsb
	lea	dsptch(%eax),%edi
	mov	word_dot, %eax
	mov	%eax,(%edi)
	incl	var_current
	xchg	%esp,%ebp
	ret
	
END_CODE
DEF_CODE(at, "@")
	xchg	%esp,%ebp
	popl	%eax
	pushl	(%eax)
	xchg	%esp,%ebp
	ret
END_CODE
DEF_VAR(state, 1)
DEF_VAR(here, here)
DEF_VAR(current, [EL_COUNT(NAME_TAB)])
END_DICT
END_CODE
BUILD_NAME_TABLE

long_tmp: 	.LONG 0
token:		.FILL	64
fmt_float: 	.ASCIZ  "%f"
fmt_hex:	.ASCIZ 	"%x"
fmt_dec:	.ASCIZ 	"%d"
var_base:	.LONG 	10
msg:	.ASCIZ "%s\n"
msg_not_defined:	.ASCIZ "Word '%s' not defined.\n"
msg_test1:	.ASCIZ "Test1\n"
msg_test2:	.ASCIZ "Test2\n"
msg_test3:	.ASCIZ "Test3\n"
