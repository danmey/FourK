#line 1 "fourk2.S"

#line 2 "fourk2.S"

#line 1 "dict.m4"

#line 5
   
#line 19

#line 26

 
#line 3 "fourk2.S"



msg:	.ASCIZ "%s\n"
	.GLOBL main
	.GLOBL _start
#ifndef DEBUG
_start:
#else
main:
#endif
1:	
	pushal 	
#line 15
	call	_gettoken
#line 15
	movl	%eax,28(%esp)
#line 15
	popal	
	cmpb	$'!',token
	jz _exit
	pushal 	
#line 18
	push	$token
#line 18
	push	$msg
#line 18
	call	printf
#line 18
	addl 	$8,%esp
#line 18
	movl	%eax,28(%esp)
#line 18
	popal
	jmp	1b
_exit:
	pushal 	
#line 21
	push	$ 0
#line 21
	call	exit
#line 21
	addl 	$4,%esp
#line 21
	movl	%eax,28(%esp)
#line 21
	popal	
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

	pushal 	
#line 49
	push	$long_tmp
#line 49
	push	$fmt_float
#line 49
	push	$token
#line 49
	call	sscanf
#line 49
	addl 	$12,%esp
#line 49
	movl	%eax,28(%esp)
#line 49
	popal
	cmp	$0,%eax
	mov 	long_tmp,%eax
	pop	%edi
	ret
1:
	cmpb	$10,var_base
	jz	2f
	pushal 	
#line 57
	push	$long_tmp
#line 57
	push	$fmt_hex
#line 57
	push	$token
#line 57
	call	sscanf
#line 57
	addl 	$12,%esp
#line 57
	movl	%eax,28(%esp)
#line 57
	popal
	cmp	$0,%eax
	mov 	long_tmp,%eax
	pop	%edi
	ret
2:	
# Use cheap sscanf
	pushal 	
#line 64
	push	$long_tmp
#line 64
	push	$fmt_dec
#line 64
	push	$token
#line 64
	call	sscanf
#line 64
	addl 	$12,%esp
#line 64
	movl	%eax,28(%esp)
#line 64
	popal
3:	
	cmp	$0,%eax
	mov 	long_tmp,%eax
	pop	%edi
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
	mov 	$32,%ecx
1:	
	dec %ecx			# keep the counter becasue we need to clear out token
	stosb				# in al we had out character
	call _get_key			# get next key
	call _is_white			# is white?
	jnz 1b				# NO?
	pushal 	
#line 92
	push	stdin
#line 92
	push	%eax
#line 92
	call	ungetc
#line 92
	addl 	$8,%esp
#line 92
	movl	%eax,28(%esp)
#line 92
	popal	# unget char
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
	pushal 	
#line 143
	call	getchar
#line 143
	movl	%eax,28(%esp)
#line 143
	popal
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
	mov 	var_ntab,%edx		# set up a pointer past the end
	sub	$32,%edx	# pointing last one
1:	

# If it's end of list then go and report fail
	cmpb 	$0,(%edx)		# end of dictionary?
	jz 	3f			# yes? Not found then.
	testb	$2,(32-1)(%edx)	# Test for immediate
	jnz	4f			# idden? yes then skip it

# Prepare for string comparition
	mov 	%edx,%esi		
	mov 	$(32-2),%ecx # Last byte is reserved for flags
					  	
# Compare it
	push	%edi			# save edi, because it contains
	repe 	cmpsb			# the pointer to our value
	pop	%edi			# restore
	jz 	2f			# Found word!
4:	
	sub 	$32,%edx 	# Nope.. go back one entry
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





var_ntab: .LONG ntab_end
#line 204
ntab: 
#line 204
.STRING "dup"
#line 204
.FILL 29
#line 204
.STRING "drop"
#line 204
.FILL 28
#line 204
.STRING "+"
#line 204
.FILL 31
#line 204

#line 204
ntab_end:
#line 204


.data		
long_tmp: 	.LONG 0
token:		.FILL	64
fmt_float: 	.ASCIZ  "%f"
fmt_hex:	.ASCIZ 	"%x"
fmt_dec:	.ASCIZ 	"%d"
var_base:	.LONG 	10
