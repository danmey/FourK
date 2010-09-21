# FourK - Concatenative, stack based, Forth like language optimised for 
#        non-interactive 4KB size demoscene presentations.

# Copyright (C) 2009, 2010 Wojciech Meyer, Josef P. Bernhart

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
define(`array', `defn(format(``array[%s]'', `$1'))')
define(`array_set', `define(format(``array[%s]'', `$1'), `$2')')
define(`array2', `defn(format(``array2[%s]'', `$1'))')
define(`array_set2', `define(format(``array2[%s]'', `$1'), `$2')')
define(`array3', `defn(format(``array3[%d]'', `$1'))')
define(`array_set3', `define(format(``array3[%d]'', `$1'), `$2')')

define(`forloop', `pushdef(`$1', `$2')_forloop($@)popdef(`$1')')
define(`_forloop',
       `$4`'ifelse($1, `$3', `', `define(`$1', incr($1))$0($@)')')


define(`dquote', ``$@'')
define(`dquote_elt', `ifelse(`$#', `0', `', `$#', `1', ```$1''',
		                                  ```$1'',$0(shift($@))')')
	
define(`foreachq', `pushdef(`$1')_foreachq($@)popdef(`$1')')
define(`_arg1q', ``$1'')
define(`_rest', `ifelse(`$#', `1', `', `dquote(shift($@))')')
define(`_foreachq', `ifelse(`$2', `', `',
		    `define(`$1', _arg1q($2))$3`'$0(`$1', _rest($2), `$3')')')

define(`current_word',`0')
define(`begin_dict', `define(`vm_def_table', `vm_func $1[] = {')concat(`vm_def_table',`VMdef_lit')')
define(`concat', `define(`$1', defn(`$1')$2`,')')dnl
array_set(`VMdef_lit', current_word)dnl
define(`defcode',`define(`vm_cur_id',`VMdef_`$1'')dnl
	define(`current_word',incr(current_word))dnl
	array_set(vm_cur_id, current_word)dnl
	concat(`vm_def_table',`
	vm_cur_id')
void vm_cur_id`'(byte** byte_code)' {)dnl
define(`endcode',`}')dnl
define(`end_dict', `vm_def_table
};')dnl


define(`bcode_begin')
define(`make_list', `patsubst($1,`\w+',`\&,')')dnl
define(`_byte_code', `foreachq(`iter', `$@',`ifelse(iter,,,
		     		        `ifelse(regexp(iter,`[ ]*[+-]?[0-9]+'),-1,
					
	array(VMdef_`'iter)`,',`ifelse(array2(iter),,array(`VMdef_lit')`,' `'iter`,',-array2(iter)`, ') ')')')')dnl
define(`cur_word',2)
define(`word_begin',`
	array_set2($1,cur_word)dnl
	array_set3(cur_word,$1)dnl
	define(`cur_word',incr(cur_word))dnl
byte $1[] = {_byte_code(make_list(')dnl
define(`word_end',`))-1};')dnl
define(`bcode_end',`byte_code_t _vm_word_tab_[] = {
forloop(`i', 2, decr(cur_word), `{&array3(i)[0]}, ')
};
`#'define VM_ENTRY_WORD eval(cur_word-3)
')dnl

