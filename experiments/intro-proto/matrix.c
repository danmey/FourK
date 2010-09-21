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
#include <stdio.h>
#include "GL/gl.h"
#include "matrix.h"


void matrix_begin()
{
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix();
  glLoadIdentity();
}

void matrix_end(matrix_t mat)
{
  glGetFloatv(GL_MODELVIEW_MATRIX, mat);
  glPopMatrix();
}

void matrix_rotation(float x, float y, float z, matrix_t mat)
{
  matrix_begin();
  glRotatef(x, 1,0,0);
  glRotatef(y, 0,1,0);
  glRotatef(z, 0,0,1);
  matrix_end(mat);
}

void matrix_translate(float x, float y, float z, matrix_t mat)
{
  matrix_begin();
  glTranslatef(x, y, z);
  matrix_end(mat);
}

void matrix_multiply(matrix_t dst, matrix_t mat1, matrix_t mat2)
{
  matrix_begin();
  glLoadMatrixf(mat2);
  glMultMatrixf(mat1);
  matrix_end(dst);
}

void matrix_identity(matrix_t mat)
{
  matrix_begin();
  matrix_end(mat);
}


void matrix_print(matrix_t mat)
{
  for(int r=0; r<4; r++)
    {
      printf("[");
      for(int c=0; c<4; c++)
	{
	  printf("%.2f ", mat[r*4+c]);
	}
      printf("]\n");
    }
}
