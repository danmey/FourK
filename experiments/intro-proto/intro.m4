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
include(bytecode.m4)

extern stack_t vm_stack;
begin_dict(main_dict)
defcode(dup)
	int val = (int)stack_top(&vm_stack);
	stack_push(&vm_stack, (void*)val);
endcode
defcode(rot) 
// 3 2 1 -> 2 1 3
	int val1 = (int)stack_pop(&vm_stack);
	int val2 = (int)stack_pop(&vm_stack);
	int val3 = (int)stack_pop(&vm_stack);
	stack_push(&vm_stack, (void*)val2);
	stack_push(&vm_stack, (void*)val1);
	stack_push(&vm_stack, (void*)val3);
endcode
defcode(swap) 
// 2 1 -> 1 2
	int val1 = (int)stack_pop(&vm_stack);
	int val2 = (int)stack_pop(&vm_stack);
	stack_push(&vm_stack, (void*)val1);
	stack_push(&vm_stack, (void*)val2);
endcode
defcode(dups) 
// 2 1 -> 1 2
	int val1 = (int)stack_pop(&vm_stack);
	int val2 = (int)stack_pop(&vm_stack);
	stack_push(&vm_stack, (void*)val2);
	stack_push(&vm_stack, (void*)val1);
	stack_push(&vm_stack, (void*)val2);
	stack_push(&vm_stack, (void*)val1);
endcode

defcode(scale_y)
	current_primitive()->atts.scale_y = vm_pop_stack();
endcode
defcode(top_radius)
	current_primitive()->atts.top_radius = vm_pop_stack();
endcode

defcode(bottom_radius)
     current_primitive()->atts.bottom_radius = vm_pop_stack();
endcode

defcode(height)
     current_primitive()->atts.height = vm_pop_stack();
endcode

defcode(tess)
     current_primitive()->atts.tess = vm_pop_stack();
endcode

defcode(shift_x)
     current_primitive()->atts.shift_x += vm_pop_stack();
endcode

defcode(shift_y)
     current_primitive()->atts.shift_y += vm_pop_stack();
endcode

defcode(shift_z)
     current_primitive()->atts.shift_z += vm_pop_stack();
endcode

defcode(rot_x)
     current_primitive()->atts.rot_x += vm_pop_stack();
endcode

defcode(rot_y)
     current_primitive()->atts.rot_y += vm_pop_stack();
endcode

defcode(rot_z)
     current_primitive()->atts.rot_z += vm_pop_stack();
endcode

defcode(col_r)
     current_primitive()->atts.col_r = ((float)vm_pop_stack())/127.0;
endcode

defcode(col_g)
     current_primitive()->atts.col_g = ((float)vm_pop_stack())/127.0;
endcode

defcode(col_b)
     current_primitive()->atts.col_b = ((float)vm_pop_stack())/127.0;
endcode

dnl defcode(swap_xy)
dnl 	matrix_swap(stack_top(&matrix_stack), 0, 1);
dnl endcode
dnl 
dnl defcode(swap_xz)
dnl 	matrix_swap(stack_top(&matrix_stack), 0, 2);
dnl endcode
dnl 
dnl defcode(swap_yz)
dnl 	matrix_swap(stack_top(&matrix_stack), 1, 2);
dnl endcode

defcode(hidden)
	current_primitive()->atts.hidden = 1;
endcode

defcode(end)
	stack_pop(&primitive_stack);
endcode

defcode(prim)
	new_primitive();
endcode

defcode(join)
  int val = vm_pop_stack();
  joint.pp2 = val%10;
  joint.pp1 = val/10;	
  do_transformation();
endcode

end_dict

bcode_begin

word_begin(c1) 1 word_end
word_begin(cneg1) -1 word_end
word_begin(c2) 1 word_end
word_begin(c3) 3 word_end
word_begin(cs2) 2 word_end
word_begin(csneg2) -2 word_end
word_begin(c4) 4 word_end
word_begin(c5) 5 word_end
word_begin(c7) 7 word_end
word_begin(c13) 13 word_end
word_begin(c01) 0 1 word_end
word_begin(join00) 0 join word_end
word_begin(radius1) dup top_radius bottom_radius word_end
word_begin(cyli1) dnl radius height
	prim  radius1 height
word_end
word_begin(cyli_sredni1) dnl (height)
        c4 cyli1 
word_end
word_begin(cyli_wiekszy1)  dnl (height)
	c7 cyli1 
word_end
word_begin(poprzek1)
	90 rot_y
word_end
word_begin(poprzek_end1)
	-90 rot_y
word_end
word_begin(tuleja_glowna1) dnl angle join len
	cyli_sredni1 poprzek1 rot_z join
	c3 cyli_wiekszy1 c1 shift_z 11 join end
	c3 cyli_wiekszy1 cneg1 shift_z 22 join end
	prim hidden poprzek_end1 join00 
word_end

word_begin(warstwa_listwy1)
	c1 cyli1 4 tess dnl length
word_end
word_begin(listwa1) dnl join join shift  bangle height
	2 cyli1 rot_z 32 scale_y shift_x 4 tess join end
word_end
word_begin(listwa2) dnl join join shift  bangle height
	4 cyli1 rot_z 16 scale_y shift_x 4 tess join 
word_end
word_begin(przegub1) dnl angle  join
	swap c13 tuleja_glowna1
	1 cs2 0 30 listwa1 
	1 csneg2 0 30 listwa1 
	30 warstwa_listwy1 hidden 21 join
word_end
word_begin(przegub_caly1) dnl angle1 angle2
	swap 0 przegub1 20 przegub1	
word_end
word_begin(lacznik1) dnl join
	prim 4 tess 7 bottom_radius 13 top_radius 24 scale_y 16 height join
	dnl 30 20 17 tuleja_glowna1 
word_end

word_begin(palec1) dnl shift angle shift join 
	swap 0 20 listwa2 
	20 swap 10 tuleja_glowna1
	1 0 0 20 listwa2 end end end end
word_end
word_begin(ramie1) dnl
	swap 0 swap przegub_caly1 20 swap c13 tuleja_glowna1 21 lacznik1   
word_end
word_begin(dlon1) dnl palec1_angle palec2_angle palce_angle przegub2_angle przegub1_angle 
	swap
 	ramie1 20 swap 20 tuleja_glowna1
	-8 21 palec1 
	8 21 palec1 
	end end end end end end end end end end end
word_end
word_begin(korpus1)
	prim 4 tess 7 bottom_radius 13 top_radius 24 scale_y 16 height join
word_end
word_begin(oko1)
	10 10 cyli1 90 rot_x
word_end
word_begin(scenka1)
	prim hidden
	dnl 10 cyli_wiekszy1 4 tess 32 scale_y 0 0 join 
	20 korpus1
	prim hidden 0 join
	45 -45 30 20 -40 dlon1 120 rot_x 30 rot_x 10 shift_x 21 join end
	prim hidden 0 join
	-15 35 30 20 -40 dlon1 120 rot_x 30 rot_x -10 shift_x 21 join end
	prim hidden 0 join
	0 20 przegub_caly1
	oko1 10 shift_x 20 join 12 6 cyli1 0 join end end
	oko1 -10 shift_x 20 join 12 6 cyli1 0 join end end
	20 6 cyli1 90 rot_y 20 join
	prim 4 -5 shift_x tess 13 bottom_radius 13 top_radius 24 scale_y 16 height 0 join end end
	10 5 cyli1 90 rot_x 10 shift_x 7 shift_y 20 join 12 3 cyli1 0 join end end 
	10 5 cyli1 90 rot_x -10 shift_x 7 shift_y 20 join 12 3 cyli1 0 join end end 
	

dnl	60 11 palec1 
word_end
bcode_end
