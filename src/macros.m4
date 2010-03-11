changequote(`[',`]')dnl
dnl
define([K4_FIRST_L],[$1])dnl
dnl
define([K4_REST_L],[shift($@)])dnl
dnl
define([K4_FOREACH],[ifelse($2,,,
	pushdef([$1])_K4_FOREACH($@)popdef([$1]))])dnl
dnl
define([_K4_FOREACH],
	[ifelse([$2],(),[],
		[define([$1],[K4_FIRST_L$2])$3[]$0([$1],(K4_REST_L$2),[$3])])])dnl
dnl
define([K4_REVERSE_L],
	[ifelse([$1],[],[],[$0(shift($@))[]ifelse($2,[],[],[,])$1])])dnl
dnl
define([K4_RESET_ARGS],
	[define([K4_NARG],0)])dnl
dnl
define([K4_INCR_ARGS],
	[define([K4_NARG],incr(K4_NARG))])dnl
dnl
define([K4_PUSH_ARG],[
	push	$1[]K4_INCR_ARGS[]])dnl
dnl
define([K4_PUSH_ALL_ARGS],
	[K4_RESET_ARGS[]K4_FOREACH(arg,(K4_REVERSE_L($@)),
		[K4_PUSH_ARG(arg)])])dnl
dnl
define([K4_MANGLE],[ifdef([CYGWIN],[_$1],[$1])])
define([K4_PURE_CALL], [call K4_MANGLE($1)])

define([K4_CALL],
	[K4_PUSH_ALL_ARGS(shift($@))
	K4_PURE_CALL([$1])[]ifelse(K4_NARG,0,,[
	addl 	$[]eval(K4_NARG*4),%esp[]])])dnl
dnl
define([K4_SAFE_CALL],[pushal dnl
	K4_CALL($@)
	movl	%eax,28(%esp)
	popal])dnl
dnl
define([K4_SAVE_CONTEXT],[
	mov	%esp,_vm_context_ESP
	mov	$(_vm_context_reg+32),%esp
	pushal
	mov	_vm_context_ESP,%esp])dnl
dnl
define([K4_RESTORE_CONTEXT],[
	mov	%eax,(_vm_context_reg+28)
	mov	$(_vm_context_reg),%esp
	popal
	mov	_vm_context_ESP,%esp])dnl
dnl
