dnl Section defintion
define([SECTION], [.ASCII "@@-", $1, "@@-"])dnl
define([EXECUTE_TOKEN],[6])dnl
define([COMPILE_TOKEN],[5])dnl
define([INTERPRET_TOKEN],[7])dnl
define([END_TOKEN],[-1])dnl
define([LIT_TOKEN],[0])dnl
define([NTAB_ENTRY_SIZE], 32)dnl
define([MAX_WORDS],256)dnl
define([DICT_SIZE], 4*1024)dnl
define([NEXT_WORD], [jmp *%ebp])dnl
define([CORE_COUNT],[0])dnl
dnl
define([BEGIN_DICT])dnl
dnl
define([NORMAL_SEMANTICS],
[
	divert(2)
	.BYTE COMPILE_TOKEN, EXECUTE_TOKEN
	divert
])

define([IMMEDIATE_SEMANTICS],
[
	divert(2)
	.BYTE EXECUTE_TOKEN, EXECUTE_TOKEN
	divert
])

define([_DEF_CODE],
[
	define([LAST_WORD], $1)
	divert(1)
		define([CORE_COUNT], incr(CORE_COUNT))
		.ASCII $2
		.FILL eval(NTAB_ENTRY_SIZE - len($2) + 2)
	divert
	word_$1: .BYTE codeend_$1 - code_$1
	code_$1:
])
define([DEF_CODE],
[
	_DEF_CODE($1,$2)
	NORMAL_SEMANTICS
])
define([END_CODE],
[
	NEXT_WORD
	codeend_[]LAST_WORD:
])
define([DEF_VAR],[
	DEF_CODE($1,"$1")
	sub	$ 4,%ebx
	movl	$var_$1,(%ebx)
	NEXT_WORD
	var_$1:	.long $2
	END_CODE
])
define([DEF_IMM],
[
	_DEF_CODE($1,$2)
	IMMEDIATE_SEMANTICS
])

define([END_DICT],
[
	here: .FILL DICT_SIZE
	.equ NCORE_WORDS,CORE_COUNT
	
	SECTION("name")
		ntab: 
		undivert(1)
		ntab_end:
		.FILL NTAB_ENTRY_SIZE*MAX_WORDS

	SECTION("dsptch")
		dsptch:		.FILL NCORE_WORDS*4
		dsptch_end: 	.FILL 4*MAX_WORDS
	SECTION("semantic")
	semantic:
		undivert(2)
	semantic_end:
	.FILL 8*MAX_WORDS

])
