define([NTAB_ENTRY_SIZE], 32)
define([MAX_WORDS],256)
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
define([BEGIN_DICT],[DEF_TAB(NAME_TAB)[]DEF_TAB(DISPATCH_TAB)[]DEF_TAB(FORTH_NAME_TAB)])
define([DEF_CODE],[PUSH_EL(NAME_TAB, $1)[]PUSH_EL(FORTH_NAME_TAB, $2)
word_$1: 
.LONG code_$1
code_$1:])
define([END_CODE],[ret])
define([BUILD_NAME_TABLE],[var_ntab: .LONG ntab_end
.equ NCORE_WORDS,EL_COUNT(NAME_TAB)
ntab: 
FOR_EACH(FORTH_NAME_TAB, arg,[.ASCII arg
.FILL eval(NTAB_ENTRY_SIZE-len(arg)+2)
])
ntab_end:
.FILL NTAB_ENTRY_SIZE*MAX_WORDS
dsptch:
FOR_EACH(NAME_TAB, arg, [.LONG word_[]arg
])
dsptch_end:
.FILL 4*MAX_WORDS

])
 
