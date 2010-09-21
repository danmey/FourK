// FourK - Concatenative, stack based, Forth like language optimised for 
//        non-interactive 4KB size demoscene presentations.

// Copyright (C) 2009, 2010 Wojciech Meyer, Josef P. Bernhart

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.













	














extern stack_t vm_stack;

			
void VMdef_dup(byte** byte_code) {
	int val = (int)stack_top(&vm_stack);
	stack_push(&vm_stack, (void*)val);
}
			
void VMdef_rot(byte** byte_code) { 
// 3 2 1 -> 2 1 3
	int val1 = (int)stack_pop(&vm_stack);
	int val2 = (int)stack_pop(&vm_stack);
	int val3 = (int)stack_pop(&vm_stack);
	stack_push(&vm_stack, (void*)val2);
	stack_push(&vm_stack, (void*)val1);
	stack_push(&vm_stack, (void*)val3);
}
			
void VMdef_swap(byte** byte_code) { 
// 2 1 -> 1 2
	int val1 = (int)stack_pop(&vm_stack);
	int val2 = (int)stack_pop(&vm_stack);
	stack_push(&vm_stack, (void*)val1);
	stack_push(&vm_stack, (void*)val2);
}
			
void VMdef_dups(byte** byte_code) { 
// 2 1 -> 1 2
	int val1 = (int)stack_pop(&vm_stack);
	int val2 = (int)stack_pop(&vm_stack);
	stack_push(&vm_stack, (void*)val2);
	stack_push(&vm_stack, (void*)val1);
	stack_push(&vm_stack, (void*)val2);
	stack_push(&vm_stack, (void*)val1);
}

			
void VMdef_scale_y(byte** byte_code) {
	current_primitive()->atts.scale_y = vm_pop_stack();
}
			
void VMdef_top_radius(byte** byte_code) {
	current_primitive()->atts.top_radius = vm_pop_stack();
}

			
void VMdef_bottom_radius(byte** byte_code) {
     current_primitive()->atts.bottom_radius = vm_pop_stack();
}

			
void VMdef_height(byte** byte_code) {
     current_primitive()->atts.height = vm_pop_stack();
}

			
void VMdef_tess(byte** byte_code) {
     current_primitive()->atts.tess = vm_pop_stack();
}

			
void VMdef_shift_x(byte** byte_code) {
     current_primitive()->atts.shift_x += vm_pop_stack();
}

			
void VMdef_shift_y(byte** byte_code) {
     current_primitive()->atts.shift_y += vm_pop_stack();
}

			
void VMdef_shift_z(byte** byte_code) {
     current_primitive()->atts.shift_z += vm_pop_stack();
}

			
void VMdef_rot_x(byte** byte_code) {
     current_primitive()->atts.rot_x += vm_pop_stack();
}

			
void VMdef_rot_y(byte** byte_code) {
     current_primitive()->atts.rot_y += vm_pop_stack();
}

			
void VMdef_rot_z(byte** byte_code) {
     current_primitive()->atts.rot_z += vm_pop_stack();
}

			
void VMdef_col_r(byte** byte_code) {
     current_primitive()->atts.col_r = ((float)vm_pop_stack())/127.0;
}

			
void VMdef_col_g(byte** byte_code) {
     current_primitive()->atts.col_g = ((float)vm_pop_stack())/127.0;
}

			
void VMdef_col_b(byte** byte_code) {
     current_primitive()->atts.col_b = ((float)vm_pop_stack())/127.0;
}


			
void VMdef_hidden(byte** byte_code) {
	current_primitive()->atts.hidden = 1;
}

			
void VMdef_end(byte** byte_code) {
	stack_pop(&primitive_stack);
}

			
void VMdef_prim(byte** byte_code) {
	new_primitive();
}

			
void VMdef_join(byte** byte_code) {
  int val = vm_pop_stack();
  joint.pp2 = val%10;
  joint.pp1 = val/10;	
  do_transformation();
}

vm_func main_dict[] = {VMdef_lit,
	VMdef_dup,
	VMdef_rot,
	VMdef_swap,
	VMdef_dups,
	VMdef_scale_y,
	VMdef_top_radius,
	VMdef_bottom_radius,
	VMdef_height,
	VMdef_tess,
	VMdef_shift_x,
	VMdef_shift_y,
	VMdef_shift_z,
	VMdef_rot_x,
	VMdef_rot_y,
	VMdef_rot_z,
	VMdef_col_r,
	VMdef_col_g,
	VMdef_col_b,
	VMdef_hidden,
	VMdef_end,
	VMdef_prim,
	VMdef_join,
};




			byte c1[] = {0, 1, -1};

			byte cneg1[] = {0, -1, -1};

			byte c2[] = {0, 1, -1};

			byte c3[] = {0, 3, -1};

			byte cs2[] = {0, 2, -1};

			byte csneg2[] = {0, -2, -1};

			byte c4[] = {0, 4, -1};

			byte c5[] = {0, 5, -1};

			byte c7[] = {0, 7, -1};

			byte c13[] = {0, 13, -1};

			byte c01[] = {0, 0, 0, 1, -1};

			byte join00[] = {0, 0, 22,-1};

			byte radius1[] = {1,6,7,-1};

			byte cyli1[] = {21,-14,  8,-1};

			byte cyli_sredni1[] = {-8,  -15,  -1};

			byte cyli_wiekszy1[] = {-10,  -15,  -1};

			byte poprzek1[] = {0, 90, 14,-1};

			byte poprzek_end1[] = {0, -90, 14,-1};

			byte tuleja_glowna1[] = {-16,  -18,  15,22,-5,  -17,  -2,  12,0, 11, 22,20,-5,  -17,  -3,  12,0, 22, 22,20,21,19,-19,  -13,  -1};


			byte warstwa_listwy1[] = {-2,  -15,  0, 4, 9,-1};

			byte listwa1[] = {0, 2, -15,  15,0, 32, 5,10,0, 4, 9,22,20,-1};

			byte listwa2[] = {0, 4, -15,  15,0, 16, 5,10,0, 4, 9,22,-1};

			byte przegub1[] = {3,-11,  -20,  0, 1, -6,  0, 0, 0, 30, -22,  0, 1, -7,  0, 0, 0, 30, -22,  0, 30, -21,  19,0, 21, 22,-1};

			byte przegub_caly1[] = {3,0, 0, -24,  0, 20, -24,  -1};

			byte lacznik1[] = {21,0, 4, 9,0, 7, 7,0, 13, 6,0, 24, 5,0, 16, 8,22,-1};


			byte palec1[] = {3,0, 0, 0, 20, -23,  0, 20, 3,0, 10, -20,  0, 1, 0, 0, 0, 0, 0, 20, -23,  20,20,20,20,-1};

			byte ramie1[] = {3,0, 0, 3,-25,  0, 20, 3,-11,  -20,  0, 21, -26,  -1};

			byte dlon1[] = {3,-28,  0, 20, 3,0, 20, -20,  0, -8, 0, 21, -27,  0, 8, 0, 21, -27,  20,20,20,20,20,20,20,20,20,20,20,-1};

			byte korpus1[] = {21,0, 4, 9,0, 7, 7,0, 13, 6,0, 24, 5,0, 16, 8,22,-1};

			byte oko1[] = {0, 10, 0, 10, -15,  0, 90, 13,-1};

			byte scenka1[] = {21,19,0, 20, -30,  21,19,0, 0, 22,0, 45, 0, -45, 0, 30, 0, 20, 0, -40, -29,  0, 120, 13,0, 30, 13,0, 10, 10,0, 21, 22,20,21,19,0, 0, 22,0, -15, 0, 35, 0, 30, 0, 20, 0, -40, -29,  0, 120, 13,0, 30, 13,0, -10, 10,0, 21, 22,20,21,19,0, 0, 22,0, 0, 0, 20, -25,  -31,  0, 10, 10,0, 20, 22,0, 12, 0, 6, -15,  0, 0, 22,20,20,-31,  0, -10, 10,0, 20, 22,0, 12, 0, 6, -15,  0, 0, 22,20,20,0, 20, 0, 6, -15,  0, 90, 14,0, 20, 22,21,0, 4, 0, -5, 10,9,0, 13, 7,0, 13, 6,0, 24, 5,0, 16, 8,0, 0, 22,20,20,0, 10, 0, 5, -15,  0, 90, 13,0, 10, 10,0, 7, 11,0, 20, 22,0, 12, 0, 3, -15,  0, 0, 22,20,20,0, 10, 0, 5, -15,  0, 90, 13,0, -10, 10,0, 7, 11,0, 20, 22,0, 12, 0, 3, -15,  0, 0, 22,20,20,-1};
byte_code_t _vm_word_tab_[] = {
{&c1[0]}, {&cneg1[0]}, {&c2[0]}, {&c3[0]}, {&cs2[0]}, {&csneg2[0]}, {&c4[0]}, {&c5[0]}, {&c7[0]}, {&c13[0]}, {&c01[0]}, {&join00[0]}, {&radius1[0]}, {&cyli1[0]}, {&cyli_sredni1[0]}, {&cyli_wiekszy1[0]}, {&poprzek1[0]}, {&poprzek_end1[0]}, {&tuleja_glowna1[0]}, {&warstwa_listwy1[0]}, {&listwa1[0]}, {&listwa2[0]}, {&przegub1[0]}, {&przegub_caly1[0]}, {&lacznik1[0]}, {&palec1[0]}, {&ramie1[0]}, {&dlon1[0]}, {&korpus1[0]}, {&oko1[0]}, {&scenka1[0]}, 
};
#define VM_ENTRY_WORD 30

