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
])dnl
define([IMMEDIATE_SEMANTICS],
[
	divert(2)
	.BYTE EXECUTE_TOKEN, EXECUTE_TOKEN
	divert
])dnl
define([_DEF_CODE],
[
	define([LAST_WORD], $1)dnl
	divert(1)dnl
		define([CORE_COUNT], incr(CORE_COUNT))dnl
		.ASCII $2
		.FILL eval(NTAB_ENTRY_SIZE - len($2) + 2)
	divert dnl
	word_$1: .BYTE codeend_$1 - code_$1
	code_$1:
])
define([DEF_CODE],
[
	_DEF_CODE($1,$2) dnl
	NORMAL_SEMANTICS dnl
])
define([END_CODE],
[
	NEXT_WORD
	codeend_[]LAST_WORD:
])
define([DEF_VAR],[
	DEF_CODE($1,"$1")dnl
	sub	$ 4,%ebx
	movl	$var_$1,(%ebx)
	divert(3)
	var_$1:	.long $2
	divert
	END_CODE dnl
])
define([DEF_IMM],
[
	_DEF_CODE($1,$2) dnl
	IMMEDIATE_SEMANTICS dnl
])

define([END_DICT],
[
	here:
	.BYTE -1
	.BYTE -1
	.FILL DICT_SIZE
	.equ NCORE_WORDS, CORE_COUNT
	
	SECTION("name")
		ntab: 
		undivert(1) dnl
		ntab_end:
		.FILL NTAB_ENTRY_SIZE*MAX_WORDS

	SECTION("dsptch")
		dsptch:		.FILL NCORE_WORDS*4
		dsptch_end: 	.FILL 4*MAX_WORDS
	SECTION("semantic")
	semantic:
		undivert(2)
	semantic_end:
	.FILL 8*MAX_WORDS*4

	undivert(3)
	there:
	.FILL 16*1024

])
