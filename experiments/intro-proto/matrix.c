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
