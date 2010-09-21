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
#include "alloc.h"




void alloc_init(alloc_t* alloc, int size)
{
  alloc->size = size;
  alloc->index = 0;
}

void* alloc_new(alloc_t* alloc)
{
  void* obj = &alloc->ptr[alloc->index];
  alloc->index+=alloc->size;
  return obj;
}

void* alloc_end(alloc_t* alloc)
{
  return &alloc->ptr[alloc->index];
}

void* alloc_begin(alloc_t* alloc)
{
  return &alloc->ptr[0];
}

/*
void* alloc_at(alloc_t* alloc, int index)
{
  return &alloc->ptr[index*alloc->size];
}

int alloc_count(alloc_t* alloc)
{
  return alloc->index / alloc->size;
}

*/
