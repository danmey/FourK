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
#ifndef STACK_H
#define STACK_H

#define MAX_STACK (512*1024)



typedef struct {
  void* ptr[MAX_STACK];
  int index;
} stack_t;




void stack_init(stack_t* stack);
void stack_push(stack_t* stack, void* object);
void* stack_pop(stack_t* stack);
void* stack_top(stack_t* stack);
void* stack_second(stack_t* stack);

#endif
