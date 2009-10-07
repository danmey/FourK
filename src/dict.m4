define([SECTION], 
[.ASCII "@@-"
 .ASCII $1
 .ASCII "@@-"
])
define([EXECUTE_TOKEN],[6])
define([COMPILE_TOKEN],[5])
define([INTERPRET_TOKEN],[7])
define([END_TOKEN],[-1])
define([LIT_TOKEN],[0])
define([NTAB_ENTRY_SIZE], 32)
define([MAX_WORDS],256)
define([DICT_SIZE], 4*1024)
dnl
define([DEF_TAB],[define($1_COUNT, 0)])dnl
define([PUSH_EL],[define($1_AT[]$1_COUNT,$2)][define([$1_COUNT],incr($1_COUNT))])dnl
define([EL_COUNT], [$1_COUNT]) dnl
define([EL_AT], [indir($1_AT[]$2)])  dnl
define([K4_FORLOOP],
 	[ifelse(eval([($3) >= ($2)]),[1],
 		[pushdef([$1],eval([$2]))_K4_FORLOOP([$1],
 		eval([$3]),[$4])popdef([$1])])])dnl
dnl
define([_K4_FORLOOP],
 	[$3[]ifelse(indir([$1]),[$2],[],
   		[define([$1],incr(indir([$1])))$0($@)])])dnl
dnl
define([FOR_EACH], [K4_FORLOOP($2_i, 0, decr(EL_COUNT($1)),[pushdef([$2], EL_AT($1,$2_i))$3[]popdef([$2])])])dnl
dnl
define([BEGIN_DICT],[
DEF_TAB(NAME_TAB)[]
DEF_TAB(DISPATCH_TAB)[]
DEF_TAB(FORTH_NAME_TAB)[]
DEF_TAB(SEMANTIC_TAB)])
define([END_DICT], 
here: .FILL DICT_SIZE)
define([NORMAL_SEMANTICS],
[PUSH_EL(SEMANTIC_TAB, [[[COMPILE_TOKEN, EXECUTE_TOKEN]]])])

define([IMMEDIATE_SEMANTICS],
[PUSH_EL(SEMANTIC_TAB, [[[EXECUTE_TOKEN, EXECUTE_TOKEN]]])])
define([NEXT_WORD], [jmp *%ebp])
define([CORE_COUNT],[0])
define([_DEF_CODE],
[
define([LAST_WORD],$1)
divert(1)
define([CORE_COUNT],incr(CORE_COUNT))
.ASCII $2
.FILL eval(NTAB_ENTRY_SIZE-len($2)+2)
divert
word_$1: 
.BYTE codeend_$1-code_$1
code_$1:])
define([DEF_CODE],[
_DEF_CODE($1,$2)
NORMAL_SEMANTICS])
define([END_CODE],
[
NEXT_WORD
codeend_[]LAST_WORD:
]
 )
define([DEF_VAR],[
DEF_CODE($1,"$1")
sub	$ 4,%ebx
movl	$var_$1,(%ebx)
NEXT_WORD
var_$1:	.long $2
END_CODE
])
define([DEF_IMM],[
_DEF_CODE($1,$2)
IMMEDIATE_SEMANTICS])

define([BUILD_NAME_TABLE],[
SECTION("name")
.equ NCORE_WORDS,CORE_COUNT
ntab: 
undivert(1)
ntab_end:
.FILL NTAB_ENTRY_SIZE*MAX_WORDS
SECTION("dsptch")
dsptch:
.FILL NCORE_WORDS*4
dsptch_end:
.FILL 4*MAX_WORDS
SECTION("semantic")
semantic:
FOR_EACH(SEMANTIC_TAB, arg, [.BYTE arg
])
semantic_end:
.FILL 8*MAX_WORDS
])
