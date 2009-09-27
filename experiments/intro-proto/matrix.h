#ifndef MATRIX_H
#define MATRIX_H

typedef float matrix[4][4];
typedef float* matrix_t;

void matrix_begin();
void matrix_end(matrix_t mat);
void matrix_rotation(float x, float y, float z, matrix_t mat);
void matrix_translate(float x, float y, float z, matrix_t mat);
void matrix_multiply(matrix_t dst, matrix_t mat1, matrix_t mat2);
void matrix_identity(matrix_t mat);
void matrix_print(matrix_t mat);

#endif
